# Extender Keycloak: temas, localización y SPI/providers

## Contenido
1. Temas: tipos, estructura y herencia
2. Personalización rápida (Quick Theme) y consolas propias
3. Localización
4. Providers: empaquetado y despliegue
5. SPIs más usados (con esqueletos)
6. Recursos REST propios
7. Testing de extensiones
8. Buenas prácticas y compatibilidad

## 1. Temas

Tipos: `login` (FreeMarker `.ftl`), `account` (React/PatternFly 5, `keycloak.v3`), `admin` (React), `email` (FreeMarker html/text), `welcome`. Temas base: `base` (sin estilos), `keycloak` (legacy PF4), **`keycloak.v2`** (login por defecto desde 26.0, PatternFly 5, con dark mode y footer personalizable).

Estructura (en `themes/` o dentro de un JAR en `theme/`):
```
themes/mitema/
  login/
    theme.properties          # parent=keycloak.v2 ; import=common/keycloak ; styles=css/login.css ...
    login.ftl                 # solo si sobrescribes la plantilla
    resources/css/login.css
    resources/img/logo.svg
    messages/messages_es.properties
  email/
    theme.properties          # parent=base
    html/email-verification.ftl
    text/email-verification.ftl
    messages/messages_es.properties
```
`theme.properties`: `parent`, `import`, `styles`, `scripts`, `locales=es,en`, `kcLogoClass`… y propiedades CSS de clases (`kcFormClass=...`). Soporta `${env.VAR}` y propiedades de sistema.

Aplicar: Realm settings → Themes (por realm) o Clients → Advanced → Login theme (por cliente). Por defecto global: `--spi-theme--default=mitema`.

Desarrollo: `start-dev` desactiva la caché de temas; en otros modos `--spi-theme--cache-themes=false --spi-theme--cache-templates=false --spi-theme--static-max-age=-1`.

Recomendaciones: hereda de `keycloak.v2` y cambia solo CSS/mensajes/imágenes; sobrescribir `.ftl` hace frágiles los upgrades (revisar en cada versión: p. ej. en 26.8 cambiaron los botones de IdP del login). Desplegar como JAR en `providers/` (+ `build`) para imágenes inmutables. Herramienta comunitaria popular para temas en React: **Keycloakify**.

## 2. Quick Theme, avatares y consolas propias

- **Quick Theme** (feature `quick-theme`): genera un tema con colores/logo desde la Admin Console (Realm settings → Themes) sin código.
- Avatares en Admin/Account Console (atributo `picture`).
- Welcome theme personalizable.
- Consolas propias: paquetes npm `@keycloak/keycloak-ui-shared`, `@keycloak/keycloak-account-ui`, `@keycloak/keycloak-admin-ui` para construir una Account Console a medida (`/ui-customization/creating-your-own-console`, `/ui-customization/themes-react`).

## 3. Localización

- Realm settings → Localization: Internationalization ON, idiomas soportados y por defecto; *Realm overrides* para cambiar textos sin tema.
- En temas: `messages/messages_<locale>.properties` (UTF-8 desde 23). Selección por `ui_locales`/`kc_locale`, cookie, atributo `locale` del usuario o `Accept-Language`.
- RTL soportado en login, admin, email y account.

## 4. Providers

- Proyecto Maven/Gradle con dependencias `provided`: `org.keycloak:keycloak-server-spi`, `keycloak-server-spi-private`, `keycloak-services`, `keycloak-core` (misma versión que el servidor).
- Cada provider = `ProviderFactory` + `Provider`, registrado en `META-INF/services/<FQCN de la interfaz Factory>`.
- Desplegar: JAR en `providers/` → `bin/kc.sh build` (o `start` sin `--optimized`). Dependencias de terceros: incluir JARs adicionales en `providers/` o shade. Listar cargados: Admin Console master → Provider info.
- Configuración: `--spi-<spi>--<provider-id>--<prop>=valor` (leída en `Factory.init(Config.Scope)`); elegir provider por defecto: `--spi-<spi>--provider=<id>`; habilitar/deshabilitar `--spi-<spi>--<id>--enabled=false`.
- `EnvironmentDependentProviderFactory` para activar según config; `dependsOn()` para orden entre factories (26.1).

## 5. SPIs más usados

| Necesidad | SPI / interfaces |
|---|---|
| Paso de login propio (p. ej. código por SMS, validación externa) | `AuthenticatorFactory` + `Authenticator` (`authenticate`, `action`, `requiresUser`, `configuredFor`) + `.ftl` del formulario |
| Acción obligatoria propia (aceptar política, completar dato) | `RequiredActionFactory` + `RequiredActionProvider` |
| Enviar eventos a Kafka/SIEM/webhook | `EventListenerProviderFactory` + `EventListenerProvider` (`onEvent(Event)`, `onEvent(AdminEvent, boolean)`) — habilitar en Realm settings → Events → Event listeners |
| Usuarios en BD/API legada | User Storage SPI: `UserStorageProviderFactory` + `UserStorageProvider` con `UserLookupProvider`, `CredentialInputValidator`, `UserQueryProvider`, `UserRegistrationProvider`; opcional import con `ImportedUserValidation`; datasource adicional para JPA |
| Claims calculados | `ProtocolMapper` (`AbstractOIDCProtocolMapper` + `OIDCAccessTokenMapper`, `OIDCIDTokenMapper`, `UserInfoTokenMapper`) |
| Endpoints REST propios | `RealmResourceProviderFactory` + `RealmResourceProvider` (`/realms/{realm}/<id>/...`) |
| Nuevo grant OAuth | OAuth Grant Type SPI (24+) |
| Hash de contraseñas | `PasswordHashProvider` |
| Política de contraseña | `PasswordPolicyProvider` |
| IdP propio | `IdentityProviderFactory` / `AbstractOAuth2IdentityProvider` |
| Secretos externos | Vault SPI |
| Política de cliente | `ClientPolicyExecutorProvider` / `ClientPolicyConditionProvider` |
| Pasos de workflow | Workflow step provider |
| Temas desde código | `ThemeProvider`, `ThemeSelectorProvider` |
| Email | `EmailSenderProvider`, `EmailTemplateProvider` |

Esqueleto de authenticator:
```java
public class SmsAuthenticator implements Authenticator {
  @Override public void authenticate(AuthenticationFlowContext ctx) {
    // generar código, guardarlo en ctx.getAuthenticationSession().setAuthNote("code", ...), enviar
    ctx.challenge(ctx.form().createForm("sms-code.ftl"));
  }
  @Override public void action(AuthenticationFlowContext ctx) {
    String input = ctx.getHttpRequest().getDecodedFormParameters().getFirst("code");
    String expected = ctx.getAuthenticationSession().getAuthNote("code");
    if (expected != null && expected.equals(input)) ctx.success();
    else ctx.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
        ctx.form().setError("invalidCode").createForm("sms-code.ftl"));
  }
  @Override public boolean requiresUser() { return true; }
  @Override public boolean configuredFor(KeycloakSession s, RealmModel r, UserModel u) { return u.getFirstAttribute("phone") != null; }
  @Override public void setRequiredActions(KeycloakSession s, RealmModel r, UserModel u) {}
  @Override public void close() {}
}
```
La factory define `getId()`, `getDisplayType()`, `getRequirementChoices()`, `isConfigurable()`, `getConfigProperties()` y se registra en `META-INF/services/org.keycloak.authentication.AuthenticatorFactory`. Luego se añade al flow duplicado en la Admin Console. Usa comparación en tiempo constante para códigos y limita reintentos.

Event listener mínimo:
```java
public class AuditListener implements EventListenerProvider {
  @Override public void onEvent(Event e) { if (e.getType() == EventType.LOGIN_ERROR) { /* enviar */ } }
  @Override public void onEvent(AdminEvent e, boolean includeRepresentation) { }
  @Override public void close() { }
}
```
No hagas llamadas lentas síncronas en `onEvent` (bloquean el login): encola o usa `session.getTransactionManager().enlistAfterCompletion(...)`.

## 6. Recursos REST propios

`RealmResourceProvider#getResource()` devuelve un objeto JAX-RS. Protegerlo validando el bearer token: `new AppAuthManager.BearerTokenAuthenticator(session).authenticate()` y comprobar roles. Ruta: `/realms/{realm}/{provider-id}/...`.

## 7. Testing

- **Keycloak Test Framework** (JUnit 6, supported 26.6) reemplaza Arquillian: inyecta servidor, BD, realms, clientes; tests declarativos. Repo: `keycloak/keycloak` → `test-framework`.
- Alternativas: Testcontainers con `quay.io/keycloak/keycloak` + import de realm, o `dasniko/testcontainers-keycloak` (comunitario).

## 8. Buenas prácticas

- Las APIs de `keycloak-server-spi-private` y `keycloak-services` no son estables: compila contra la versión exacta y re-prueba en cada upgrade.
- Mantén la lógica en el provider pequeña; usa `KeycloakSession` por request; no guardes estado en campos estáticos.
- Scripts JS (`scripts` feature, preview) solo desplegados como JAR (`META-INF/keycloak-scripts.json`); no hay upload desde la consola.
- Documenta la configuración SPI en la imagen (build) para imágenes inmutables.
