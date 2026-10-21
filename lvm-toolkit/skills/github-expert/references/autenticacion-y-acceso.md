# Autenticación y acceso

## 1. ¿Qué credencial usar?

| Escenario | Recomendado | Evitar |
|---|---|---|
| Git por HTTPS en tu máquina | GitHub CLI (`gh auth login` + `gh auth setup-git`) o Git Credential Manager | Contraseña (no funciona desde 2021) |
| Git por SSH | Clave Ed25519 con passphrase + ssh-agent | Claves RSA < 2048 / DSA (no admitidas) |
| Dentro de Actions, mismo repo | `GITHUB_TOKEN` con `permissions` mínimos | PAT personal |
| Actions que tocan otros repos / disparan workflows | Token de **GitHub App** (`actions/create-github-app-token`) | PAT classic de un humano |
| Automatización de org de larga vida | GitHub App | PAT (se muere si la persona se va) |
| Script personal contra la API | Fine-grained PAT con expiración | Classic con `repo` completo |
| Servidor que hace pull de un repo | Deploy key (solo lectura) | Clave SSH personal |
| Nube desde Actions | OIDC | Access keys guardadas como secreto |
| Paquetes (GHCR, npm…) fuera de Actions | PAT **classic** con `read:packages`/`write:packages` (fine-grained aún no soporta Packages) | — |

## 2. Personal access tokens

**Fine-grained** (recomendado): un único propietario de recursos (usuario u org), repos seleccionados, permisos granulares (repo / org / cuenta), expiración (las orgs pueden imponer duración máxima y **aprobación**: el token queda `pending` y solo lee público hasta aprobarse). Límite de 50 fine-grained por usuario. Se pueden pre-rellenar por URL:
```
https://github.com/settings/personal-access-tokens/new?name=CI+reader&expires_in=30&target_name=mi-org&contents=read&pull_requests=write
```
Parámetros: `name` (≤40), `description`, `target_name`, `expires_in` (1–366 o `none`), y cada permiso (`contents=read|write`, `workflows=write`, `actions`, `administration`, `issues`, `pull_requests`, `secrets`, `environments`, `pages`, `members`, `organization_administration`, `copilot_requests`…). `write` implica `read`; `admin` implica `write`.

Limitaciones de fine-grained (por ahora): contribuir a repos públicos de otros donde no eres miembro, uso como colaborador externo, varias orgs a la vez, **Packages**, Checks API, Projects de cuenta de usuario.

**Classic**: scopes amplios (`repo`, `workflow`, `read:org`, `admin:org`, `write:packages`, `delete_repo`, `gist`…). Acceden a todo lo que el usuario accede. Las orgs pueden bloquearlos (→ 403). GitHub elimina automáticamente PATs sin uso durante 1 año. Para orgs con SAML SSO hay que "Configure SSO → Authorize".

Notas:
- Modificar `.github/workflows/*` por push requiere scope `workflow` (classic) o permiso `workflows: write` (fine-grained); si no: "refusing to allow a Personal Access Token to create or update workflow".
- Usuario/contraseña en git HTTPS: el usuario se ignora, el token va como contraseña.
- Token filtrado de otra persona: API de revocación de credenciales (`/credentials/revoke`). Secret scanning revoca automáticamente tokens de GitHub expuestos en repos públicos.

## 3. SSH

```bash
ssh-keygen -t ed25519 -C "tu@email"
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519      # macOS: ssh-add --apple-use-keychain
gh ssh-key add ~/.ssh/id_ed25519.pub --title "laptop"    # o Settings → SSH and GPG keys
ssh -T git@github.com                                     # "Hi usuario! You've successfully authenticated"
```
- Puerto 22 bloqueado: `ssh.github.com` puerto 443:
  ```
  Host github.com
    Hostname ssh.github.com
    Port 443
    User git
  ```
- Verifica huellas oficiales (página "Huellas digitales de las claves SSH") antes de aceptar el host key.
- Varias cuentas: alias de host en `~/.ssh/config` con `IdentityFile` distinto e `IdentitiesOnly yes`.
- Llaves de seguridad: `ed25519-sk` / `ecdsa-sk`.
- **Deploy keys**: por repo, solo lectura por defecto; una clave no puede reutilizarse en dos repos ("Key is already in use"). Para muchos repos, GitHub App o machine user.
- Certificados SSH: CA de la org (Enterprise Cloud).

## 4. Firma de commits

- GPG, **SSH** (más simple) o S/MIME (X.509, gitsign/smimesign).
- SSH:
  ```bash
  git config --global gpg.format ssh
  git config --global user.signingkey ~/.ssh/id_ed25519.pub
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true
  ```
  Sube la clave como **Signing key** (distinta de Authentication key aunque sea el mismo archivo).
- El email del commit debe ser un email verificado de la cuenta (o el noreply).
- **Vigilant mode**: marca como "Unverified" tus commits sin firma.
- Estados: Verified, Partially verified, Unverified.

## 5. 2FA, passkeys y cuenta

- 2FA obligatorio para todos los que contribuyen código en GitHub.com (despliegue gradual desde 2023); métodos: TOTP, llaves de seguridad/WebAuthn, passkeys, GitHub Mobile, SMS (países limitados, menos recomendado). Guarda los **códigos de recuperación**.
- Passkeys: inicio de sesión sin contraseña y satisfacen 2FA.
- Sudo mode: reautenticación para acciones sensibles.
- Orgs pueden exigir 2FA (los miembros sin 2FA se eliminan) y, en Enterprise, SAML SSO / OIDC (Entra ID) o **Enterprise Managed Users** (cuentas gestionadas por el IdP, con SCIM).
- Security log personal: Settings → Security log.

## 6. GitHub Apps vs OAuth Apps

| | GitHub App (recomendada) | OAuth App |
|---|---|---|
| Permisos | Granulares, por repo seleccionado | Scopes amplios |
| Actúa como | Sí misma (bot `app[bot]`) o en nombre de usuario | Solo usuario |
| Tokens | JWT (RS256, exp ≤ 10 min) → **token de instalación 1 h**; tokens de usuario expiran (8 h, refresh 6 meses) | No expiran por defecto |
| Webhooks | Integrados | No (por repo aparte) |
| Rate limit | Instalación: 5000/h, escala +50 por repo/usuario >20 hasta 12.500; 15.000 en Enterprise Cloud | 5000/h por usuario |
| Licencia | No consume asiento | — |

En Actions:
```yaml
- uses: actions/create-github-app-token@v2   # verifica versión
  id: app
  with:
    app-id: ${{ vars.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
    owner: ${{ github.repository_owner }}
- run: gh api repos/org/otro-repo/dispatches -f event_type=deploy
  env:
    GH_TOKEN: ${{ steps.app.outputs.token }}
```
Flujo device (CLI): `POST https://github.com/login/device/code` → el usuario introduce el código → polling a `/login/oauth/access_token`.

## 7. Roles y permisos (resumen)

- Repo (org): **Read**, **Triage**, **Write**, **Maintain**, **Admin** + roles personalizados (Enterprise Cloud).
- Org: Owner, Member, Moderator, Billing manager, Security manager (rol), Outside collaborator; roles de org personalizados (p. ej. "CI/CD admin", "App manager").
- Repo personal: owner + colaboradores (write); no hay granularidad.
- Equipos anidados heredan acceso del padre; visibilidad secret/visible.
- Base permissions de la org (default para miembros): elegir `Read` o `No permission`.
