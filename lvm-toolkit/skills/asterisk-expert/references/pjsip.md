# PJSIP (chan_pjsip / res_pjsip)

## Índice
1. Modelo de objetos
2. Transports
3. Teléfonos
4. Troncales (registro / IP)
5. Identificación de endpoints
6. Autenticación (MD5, SHA-256)
7. NAT
8. Codecs, DTMF, Caller ID y cabeceras
9. Wizard
10. TLS/SRTP y WebRTC
11. Presencia, BLF y MWI
12. Realtime (base de datos)
13. Marcar canales PJSIP

## 1. Modelo de objetos

`pjsip.conf` define objetos con `type=`: `transport`, `endpoint`, `aor`, `auth`, `identify`, `registration`, `acl`, `domain_alias`, `contact` (estático), `global`, `system`, `outbound-publish`, `inbound-publish`, `resource_list`, `phoneprov`.

```
endpoint ──aors=──▶ aor ──(contact / registros)──▶ contactos
   │ auth=          (entrante: Asterisk desafía)
   │ outbound_auth= (saliente: Asterisk responde desafíos)
   │ transport=     (opcional; si no, se elige por la URI)
identify ──endpoint=──▶ endpoint     (match por IP/host/cabecera)
registration ──outbound_auth=──▶ auth ; endpoint=/line=yes opcional
```
Mismo nombre para endpoint/aor/auth es válido. Plantillas `[tpl](!)` reducen repetición. Ayuda en vivo: `config show help res_pjsip endpoint`.

Opciones de endpoint más usadas: `context`, `disallow`, `allow`, `aors`, `auth`, `outbound_auth`, `transport`, `callerid`, `from_user`, `from_domain`, `direct_media`, `rtp_symmetric`, `force_rport`, `rewrite_contact`, `dtmf_mode`, `language`, `mailboxes`, `named_call_group`/`named_pickup_group`, `device_state_busy_at`, `send_pai`, `send_rpid`, `trust_id_inbound`, `trust_id_outbound`, `identify_by`, `media_encryption`, `webrtc`, `ice_support`, `timers`, `100rel`, `rtp_timeout`, `rtp_timeout_hold`, `allow_subscribe`, `set_var`, `tos_audio`, `max_audio_streams`, `stir_shaken_profile`.

AOR: `max_contacts`, `remove_existing`, `remove_unavailable`, `qualify_frequency` (s; 0=off), `qualify_timeout`, `contact` (URI completa `sip:host:puerto`), `default_expiration`, `minimum_expiration`, `maximum_expiration`, `mailboxes`, `support_path`.

## 2. Transports

```ini
[global]
type = global
user_agent = PBX           ; no reveles versión
endpoint_identifier_order = ip,username,anonymous

[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5060

[transport-tcp]
type = transport
protocol = tcp
bind = 0.0.0.0:5060

[transport-tls]
type = transport
protocol = tls
bind = 0.0.0.0:5061
cert_file = /etc/asterisk/keys/pbx.crt
priv_key_file = /etc/asterisk/keys/pbx.key
method = tlsv1_2          ; mínimo
verify_client = no
```
- Cada transport debe tener IP:puerto único por protocolo; dos UDP en 0.0.0.0:5060 chocan. Para varias IPs, un transport por IP y `transport=` en el endpoint.
- Cambios en transports generalmente requieren reinicio (o `allow_reload=yes`, con cuidado).
- IPv6: transport aparte con `bind=[::]:5060` (pjproject con IPv6).

## 3. Teléfonos

```ini
[phone-tpl](!)
type = endpoint
context = internos
disallow = all
allow = g722,ulaw,alaw
direct_media = no
rtp_symmetric = yes
force_rport = yes
rewrite_contact = yes
language = es
device_state_busy_at = 1

[aor-tpl](!)
type = aor
max_contacts = 1
remove_existing = yes
qualify_frequency = 60

[1001](phone-tpl)
auth = 1001
aors = 1001
callerid = "Ana Pérez" <1001>
mailboxes = 1001@default
[1001](aor-tpl)
[1001]
type = auth
auth_type = digest
username = 1001            ; mejor: un usuario no adivinable
password = CAMBIAR-por-24+caracteres-aleatorios
```
Con `max_contacts>1` (varios dispositivos) Dial a `PJSIP/1001` llama a todos los contactos; `${PJSIP_DIAL_CONTACTS(1001)}` también.

## 4. Troncales

**Proveedor con registro**
```ini
[prov-auth]
type = auth
auth_type = digest
username = 1112223333
password = SECRETO
; realm vacío = responde a cualquier realm

[prov-reg]
type = registration
transport = transport-udp
outbound_auth = prov-auth
server_uri = sip:sip.proveedor.example
client_uri = sip:1112223333@sip.proveedor.example
contact_user = 1112223333
retry_interval = 60
forbidden_retry_interval = 300
expiration = 3600
; line = yes            ; si el proveedor envía INVITEs al Contact registrado
; endpoint = prov       ; (se identifican por el parámetro line)

[prov]
type = endpoint
transport = transport-udp
context = desde-proveedor
disallow = all
allow = alaw,ulaw
outbound_auth = prov-auth
aors = prov
from_user = 1112223333
from_domain = sip.proveedor.example
direct_media = no
send_pai = yes

[prov]
type = aor
contact = sip:sip.proveedor.example
qualify_frequency = 30

[prov]
type = identify
endpoint = prov
match = sip.proveedor.example     ; hostnames se resuelven al cargar; también IPs y CIDR
```

**Proveedor autenticado por IP** (sin registro): igual pero sin `registration` ni `outbound_auth`; `identify` con `match = 203.0.113.0/24` por cada red de origen. Si el proveedor tiene varios POPs, añade un `match` por cada uno.

Verifica: `pjsip show registrations` (Registered), `pjsip show contacts` (Avail + RTT), `pjsip show endpoint prov` (Identify:).

## 5. Identificación de endpoints

Toda petición entrante debe asociarse a un endpoint; si no, se rechaza (con 401 "falso" para no filtrar usuarios).
- `username` (por defecto): parte usuario del `From` = nombre del endpoint (o `auth_username` si `identify_by=auth_username`).
- `ip`: objetos `identify` (módulo `res_pjsip_endpoint_identifier_ip`). Admite `match_header = X-Foo: valor` y `match_request_uri`.
- `transport` (`identify_by=transport`): por el transport de llegada.
- `anonymous`: endpoint literal `[anonymous]`. Solo créalo con un contexto inocuo (p. ej. solo DIDs entrantes); nunca con salida a PSTN.
- Orden: `endpoint_identifier_order` en `[global]`. Evita solapamientos (un /8 y un /32 en dos identify).

## 6. Autenticación

- `auth_type=digest` (RFC 7616). `userpass`/`md5` se convierten automáticamente (deprecados).
- Contraseña pre-hasheada: `password_digest = MD5:<hash>` / `SHA-256:<hash>` / `SHA-512-256:<hash>`, con hash de `usuario:realm:contraseña` (`echo -n "u:realm:p" | openssl dgst -sha256`). Exige que `realm` coincida exactamente; como UAC solo sirve si conoces el realm del servidor.
- `supported_algorithms_uas = SHA-256, MD5` (orden de preferencia en los 401); `supported_algorithms_uac = SHA-256, MD5` (qué aceptas responder). Por defecto MD5. Soporte real: `pjproject show buildopts`.
- `realm` entrante: el del auth o `default_realm` de `[global]` (por defecto `asterisk`). Saliente: vacío/`*`.
- Usuario y contraseña distinguen mayúsculas. Asterisk no deduce `username` del nombre de la sección.

## 7. NAT

Asterisk detrás de NAT (IP privada, router con port-forward de 5060 y 10000–20000/UDP):
```ini
[transport-udp-nat]
type = transport
protocol = udp
bind = 0.0.0.0:5060
local_net = 192.168.1.0/24
local_net = 127.0.0.1/32
external_media_address = 198.51.100.5
external_signaling_address = 198.51.100.5
; external_signaling_port = 5060   ; si el router mapea otro puerto
```
Teléfonos remotos detrás de NAT: `rtp_symmetric=yes`, `force_rport=yes`, `rewrite_contact=yes`, `direct_media=no`; `qualify_frequency` 25–30 s mantiene vivo el binding. Desactiva SIP ALG. Para clientes con ICE: `ice_support=yes` y `stunaddr`/`turnaddr` en rtp.conf. Si la IP pública es dinámica, hostnames en `external_*` se resuelven (revisa `external_*_address` y recarga si cambia).

## 8. Codecs, DTMF, Caller ID, cabeceras

- `disallow=all` + `allow=` en orden. Negociación avanzada: `codec_prefs_incoming_offer`, `codec_prefs_outgoing_offer`, etc. (Advanced Codec Negotiation, 18+).
- DTMF: `dtmf_mode = rfc4733|inband|info|auto|auto_info`. Si el DTMF no llega, revisa que ambos lados negocien telephone-event.
- Caller ID saliente: `Set(CALLERID(num)=...)` en dialplan o `callerid` en endpoint; `send_pai`/`send_rpid` + `trust_id_outbound=yes` para que salgan P-Asserted-Identity. Entrante: `trust_id_inbound=yes` solo para fuentes confiables.
- Cabeceras: leer `${PJSIP_HEADER(read,X-Id)}`; añadir a la llamada saliente desde un pre-dial handler: `Dial(PJSIP/x,,b(hdrs^s^1))` y en `[hdrs]` `same => n,Set(PJSIP_HEADER(add,X-Id)=123)`. Datos del canal: `${CHANNEL(pjsip,remote_addr)}`, `${CHANNEL(rtp,dest)}`, `${PJSIP_ENDPOINT(1001,context)}`.
- Sesión/timers: `timers=yes`, `timers_sess_expires`. Cortes a ~32 s = ACK no recibido (NAT/Contact) → ver diagnóstico.

## 9. Wizard (`pjsip_wizard.conf`)

Genera endpoint+aor+auth+identify+registration desde un objeto `type=wizard`. Parámetros: `sends_auth`, `accepts_auth`, `sends_registrations`, `accepts_registrations`, `remote_hosts`, `transport`, `server_uri_pattern`, `client_uri_pattern`, `contact_pattern`, `has_hint`, `hint_exten`, `hint_context`, `hint_application`, `has_phoneprov`; prefijos `endpoint/`, `aor/`, `inbound_auth/`, `outbound_auth/`, `registration/`, `identify/`.
- Nombres generados: `<wizard>-oauth`, `<wizard>-iauth`, `<wizard>-reg-0..n`, `<wizard>-identify`.
- Transports, `[global]` y `[system]` siguen en pjsip.conf; el wizard no crea transports. `media_encryption` va con prefijo `endpoint/`.
- Con `accepts_registrations=yes` no pongas `remote_hosts`. Sin registros, `remote_hosts` crea los `identify` (necesario para troncal por IP). Para troncal por IP con salida autenticada distinta, usa dos wizards (uno entrante, otro saliente) desde una plantilla común.

## 10. TLS/SRTP y WebRTC

Teléfonos seguros: transport `tls` + endpoint `media_encryption=sdes` (SRTP) y `media_encryption_optimistic=no`; en el dialplan `${CHANNEL(secure_bridge_signaling)}`/`secure_bridge_media` para exigir seguridad.

WebRTC (requiere `res_crypto`, `res_http_websocket`, `res_pjsip_transport_websocket`; opus recomendado):
```ini
; http.conf
[general]
enabled = yes
bindaddr = 127.0.0.1
bindport = 8088
tlsenable = yes
tlsbindaddr = 0.0.0.0:8089
tlscertfile = /etc/asterisk/keys/fullchain.pem
tlsprivatekey = /etc/asterisk/keys/privkey.pem

; pjsip.conf
[transport-wss]
type = transport
protocol = wss
bind = 0.0.0.0          ; el puerto real es el de http.conf

[webrtc1]
type = endpoint
aors = webrtc1
auth = webrtc1
webrtc = yes            ; = use_avpf, media_encryption=dtls, dtls_verify=fingerprint,
                        ;   dtls_setup=actpass, ice_support, media_use_received_transport, rtcp_mux
dtls_auto_generate_cert = yes
context = internos
disallow = all
allow = opus,ulaw
[webrtc1]
type = aor
max_contacts = 5
remove_existing = yes
[webrtc1]
type = auth
auth_type = digest
username = webrtc1
password = SECRETO-LARGO
```
URL del cliente: `wss://pbx.ejemplo.com:8089/ws`. Navegadores exigen certificado válido (Let's Encrypt). Abre 8089/TCP y el rango RTP. Clientes: SIP.js, JsSIP, CyberMegaPhone. Detrás de NAT configura STUN/TURN (`rtp.conf`: `icesupport=yes`, `stunaddr=`, `turnaddr=`, `turnusername=`, `turnpassword=`).

## 11. Presencia, BLF, MWI

- Hints en dialplan: `exten => 1001,hint,PJSIP/1001`. Endpoint con `allow_subscribe=yes` (por defecto) y `context` donde viven los hints. Módulo `res_pjsip_exten_state`.
- MWI: `mailboxes=1001@default` en el **AOR** para suscripción, o en el endpoint para MWI no solicitado (no ambos). Formato buzón@contexto.
- Listas (RLS): `type=resource_list`.

## 12. Realtime

`sorcery.conf` dirige objetos a la BD; `extconfig.conf` mapea familias a conexiones; `res_odbc.conf` define la conexión. Esquema oficial con Alembic en `contrib/ast-db-manage` (`config.ini.sample` → `alembic -c config.ini upgrade head`). Tablas `ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts`, `ps_endpoint_id_ips`, `ps_registrations`, `ps_domain_aliases`, `ps_globals`, `ps_transports` (transports realtime no recomendados).
```ini
; sorcery.conf
[res_pjsip]
endpoint = realtime,ps_endpoints
auth = realtime,ps_auths
aor = realtime,ps_aors
domain_alias = realtime,ps_domain_aliases
contact = realtime,ps_contacts
[res_pjsip_endpoint_identifier_ip]
identify = realtime,ps_endpoint_id_ips
[res_pjsip_outbound_registration]
registration = realtime,ps_registrations
; extconfig.conf  [settings]  ps_endpoints => odbc,asterisk   (etc.)
```
Activa `res_odbc` antes (`preload`). Cache opcional con `memory_cache` en sorcery para rendimiento.

## 13. Marcar canales PJSIP

- `PJSIP/1001` (contactos del AOR del endpoint).
- `PJSIP/5551234@prov` (número a través del endpoint troncal).
- `PJSIP/prov/sip:5551234@203.0.113.10:5060` (URI explícita usando config del endpoint).
- `${PJSIP_DIAL_CONTACTS(1001)}` para todos los contactos.
