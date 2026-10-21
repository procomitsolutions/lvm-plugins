# Seguridad

Asterisk mal configurado = fraude telefónico (llamadas a destinos premium/internacionales pagadas por ti) en horas. Aplica todas las capas.

## 1. Dialplan (autorización)

- El `context` de cada endpoint/troncal es su permiso. Cualquiera que entre a un contexto puede marcar **todo** lo que ese contexto incluye.
- Contexto de troncales/proveedores: solo DIDs propios hacia destinos internos; nada de patrones de salida.
- Nunca salidas en `default` ni en el contexto del endpoint `anonymous`. Si no necesitas llamadas anónimas, no crees `[anonymous]`.
- Permisos por niveles con `include` (interno → nacional → internacional), internacional/premium solo para quien lo necesite, idealmente con PIN (`Authenticate()` o `VMAuthenticate`) y horario.
- Lista negra de prefijos de alto costo y de destinos frecuentes de fraude; límite de llamadas simultáneas por endpoint y global (`GROUP_COUNT`, `maxcalls`), límite de duración (`Dial(...,L(...))` o `TIMEOUT(absolute)`).
- Sanea entradas: `FILTER(0-9*#+,${EXTEN})` antes de `System()`, SQL, `CURL` o cabeceras.
- Elimina contextos demo (`demo`, ejemplos de `make samples`) antes de producción.

## 2. Autenticación SIP

- Contraseñas aleatorias largas (≥20 caracteres); el `username` del auth no tiene por qué ser el número de extensión (dificulta los escáneres).
- Prefiere SHA-256 donde los teléfonos lo soporten (`supported_algorithms_uas = SHA-256, MD5`).
- Teléfonos en LAN: restringe origen con ACL. PJSIP: `acl=`/`contact_acl=` en endpoint (named ACLs de `acl.conf`) o objeto `type=acl` global:
```ini
; pjsip.conf
[acl-global]
type = acl
deny = 0.0.0.0/0.0.0.0
permit = 192.168.1.0/255.255.255.0
permit = 203.0.113.0/255.255.255.0   ; proveedor
```
  (Si hay teléfonos remotos con IP dinámica, no apliques deny global: usa firewall + fail2ban + VPN.)
- `[global] user_agent=` neutro; `allow_unauthenticated_options=no` (por defecto).

## 3. Red

- Firewall: abre solo 5060/5061 (preferiblemente solo a IPs del proveedor y de usuarios conocidos), el rango RTP (UDP), 8089 si hay WebRTC. AMI (5038), ARI/HTTP (8088) y SSH nunca abiertos a internet.
- Cambiar el puerto 5060 reduce ruido de escáneres pero no es seguridad. Considera geobloqueo, VPN para remotos, o un SBC/Kamailio con pike/ratelimit delante.
- TLS (5061) + SRTP para teléfonos remotos; WSS + DTLS para WebRTC.
- Mantén Asterisk actualizado: sigue `github.com/asterisk/asterisk/security/advisories`.

## 4. fail2ban

Habilita el log `security` en logger.conf (`security => security`) y una jail:
```ini
; /etc/fail2ban/jail.d/asterisk.conf
[asterisk]
enabled  = true
filter   = asterisk
logpath  = /var/log/asterisk/security
           /var/log/asterisk/messages
port     = 5060,5061
protocol = all
action   = %(action_)s[name=asterisk, port="5060,5061", protocol=udp]
           %(action_)s[name=asterisk-tcp, port="5060,5061", protocol=tcp]
maxretry = 5
findtime = 600
bantime  = 86400
```
El filtro `asterisk` incluido en fail2ban reconoce los eventos de seguridad (InvalidAccountID, ChallengeResponseFailed, InvalidPassword…). Verifica con `fail2ban-regex /var/log/asterisk/security /etc/fail2ban/filter.d/asterisk.conf`. Pon tu red de gestión en `ignoreip`.

## 5. Sistema

- Usuario no root (`runuser/rungroup`), permisos 640 en `/etc/asterisk` (contienen secretos).
- `live_dangerously=no`; desde 22.5 `disable_remote_console_shell=yes`.
- `noload` para módulos no usados (chan_iax2, chan_dahdi, pbx_dundi, res_phoneprov, http estático…).
- AMI: usuarios con `deny`/`permit` y clases mínimas; nunca `write=system,command,config` para integraciones externas. ARI: usuarios `read_only=yes` para monitorización; `password_format=crypt`.
- HTTP: `bindaddr` interno; TLS si cruza redes; desactiva `enablestatic` si no lo usas.
- Monitoriza gasto: alertas sobre CDR (llamadas internacionales, picos nocturnos) y límites de crédito en el proveedor.

## 6. STIR/SHAKEN (EE. UU./Canadá principalmente)

`res_stir_shaken` (refactorizado en 20.7/21.2) con `stir_shaken.conf`: objetos de verificación y atestación (certificado y clave del proveedor STI), `type=profile` asignado al endpoint con `stir_shaken_profile=`. Solo relevante si operas como proveedor o tu carrier lo exige. Doc: `/Deployment/STIR-SHAKEN/`.

## Checklist rápida ante sospecha de fraude

1. `core show channels` / `channel request hangup all` si hay llamadas activas sospechosas.
2. Desactiva la troncal (`module unload res_pjsip_outbound_registration.so` o quita el contexto de salida y `dialplan reload`).
3. Revisa CDR/`security` log: qué endpoint, desde qué IP.
4. Cambia todas las contraseñas SIP/AMI/ARI, revisa contextos, aplica fail2ban y firewall, avisa al proveedor.
