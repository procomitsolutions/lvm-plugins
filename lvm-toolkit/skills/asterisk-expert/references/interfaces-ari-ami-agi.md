# Integración: ARI, chan_websocket, AudioSocket, AMI, AGI y reporting

## Índice
1. Qué interfaz elegir
2. ARI: configuración y conceptos
3. ARI: operaciones comunes
4. ARI Outbound WebSockets y REST sobre WebSocket
5. Media externa: chan_websocket, AudioSocket, RTP
6. Patrón: agente de voz con IA
7. AMI
8. AGI / FastAGI
9. Call files
10. CDR, CEL, queue_log, métricas

## 1. Qué interfaz elegir

| Necesidad | Interfaz |
|---|---|
| Construir la lógica de llamada entera (IVR propio, routing, bots) | **ARI** (asíncrono, REST + eventos JSON) |
| Mover audio a/desde un servicio externo (STT, LLM, TTS, grabación en tiempo real) | **chan_websocket** (vía ARI externalMedia o Dial) / AudioSocket / externalMedia RTP |
| Monitorizar, originar, colgar, gestionar colas/agentes, paneles | **AMI** (TCP 5038, eventos clave:valor) |
| Ejecutar un script síncrono dentro del dialplan (consultar CRM, decidir destino) | **AGI/FastAGI** |
| Originar llamadas programadas sin conexión persistente | Call files |
| Speech-to-text externo con apps Speech* | AEAP |

ARI y AMI: el orden de eventos no está garantizado; diseña de forma idempotente.

## 2. ARI: configuración

```ini
; http.conf
[general]
enabled = yes
bindaddr = 127.0.0.1      ; o IP de gestión; nunca público sin TLS + firewall
bindport = 8088

; ari.conf
[general]
enabled = yes
pretty = no
allowed_origins =          ; vacío salvo que un navegador deba conectarse (no recomendado)
websocket_write_timeout = 100
; channelvars = CHANNEL(endpoint),MI_VAR   ; variables incluidas en eventos

[miapp]
type = user
read_only = no
password = SECRETO-LARGO
password_format = plain    ; o crypt (hash generado con "ari mkpasswd")
```
Tres piezas: REST (`http://host:8088/ari/...`), WebSocket de eventos (`ws://host:8088/ari/events?app=miapp&api_key=miapp:SECRETO&subscribeAll=false`), y la app de dialplan `Stasis(miapp,arg1,...)` que entrega el canal a tu aplicación. Un canal solo es controlable por ARI mientras está en Stasis. Cuando tu app conecta al WS, la app Stasis queda registrada; si nadie está conectado, `Stasis()` falla (`STASISSTATUS=FAILED`).

Recursos: `channels`, `bridges` (tipos `mixing`, `holding`, `dtmf_events`, `proxy_media`, `video_sfu`), `playbacks`, `recordings`, `endpoints` (incluye `sendMessage`), `deviceStates`, `mailboxes`, `sounds`, `applications`, `asterisk` (info, variables globales, logging, módulos, config dinámica), `events`.

Eventos clave: `StasisStart`, `StasisEnd`, `ChannelStateChange`, `ChannelDtmfReceived`, `ChannelHangupRequest`, `ChannelDestroyed`, `ChannelTalkingStarted/Finished` (con `TALK_DETECT`), `ChannelToneDetected` (con `TONE_DETECT`, 22+), `PlaybackStarted/Finished`, `RecordingFinished`, `BridgeCreated`, `ChannelEnteredBridge`, `Dial`, `ChannelTransfer` (con `PJSIP_TRANSFER_HANDLING(ari-only)`, 22.3+), `ApplicationRegistered/Replaced`.

Librerías: ver `/Configuration/Interfaces/Asterisk-REST-Interface-ARI/ARI-Libraries/` (Node `ari-client`, Python `ari-py`/forks asyncio, Go, Java `ari4java`, .NET `AsterNET.ARI`, Rust…). Muchas están desmantenidas: un wrapper propio sobre HTTP+WS es razonable. Prácticas oficiales: no llamar a ARI desde el navegador; centralizar las llamadas en una capa de abstracción.

## 3. ARI: operaciones comunes

```
POST /ari/channels/{id}/answer
POST /ari/channels/{id}/play?media=sound:hello-world   (también recording:, digits:, number:, tone:, URL https://... con media cache)
POST /ari/channels/{id}/record?name=msg1&format=wav&maxDurationSeconds=60&terminateOn=#
POST /ari/channels?endpoint=PJSIP/1001&app=miapp&callerId=...      (originar hacia la app)
POST /ari/channels/create?endpoint=...&app=miapp   +  POST /channels/{id}/dial   (control fino)
POST /ari/bridges?type=mixing         → POST /ari/bridges/{b}/addChannel?channel=a,b
POST /ari/channels/{id}/snoop?spy=in|out|both&whisper=...&app=miapp      (supervisión, transcripción)
POST /ari/channels/{id}/continue?context=x&extension=y&priority=1        (devolver al dialplan)
POST /ari/channels/{id}/variable?variable=X&value=Y
POST /ari/channels/{id}/progress   (23+)   /ring   /hold   /moh   /mute
DELETE /ari/channels/{id}?reason_code=16
```
Versión de la API: `GET /ari/asterisk/info` y `/ari/api-docs/resources.json` (Swagger).

## 4. ARI Outbound WebSockets y REST sobre WebSocket (22.5+)

Asterisk abre la conexión hacia tu app (útil si la app está en la nube o detrás de NAT, y para balanceo).
```ini
; ari.conf
[ari_user]
type = user
read_only = no
password = SECRETO          ; debe ser plain para local_ari_user
[conn1]
type = outbound_websocket
websocket_client_id = appserver
apps = voicebot
subscribe_all = no
local_ari_user = ari_user

; websocket_client.conf
[appserver]
type = websocket_client
uri = wss://bot.ejemplo.com/ari
protocols = ari
connection_type = persistent        ; o per_call_config (conecta al entrar en Stasis)
username = asterisk
password = SECRETO-APP
connection_timeout = 500
reconnect_interval = 1000
reconnect_attempts = 5
tls_enabled = yes
verify_server_cert = yes
; write_timeout = 100               ; 24+
```
- Se crea automáticamente el contexto `stasis-<app>` con `Stasis(<app>)`.
- `per_call_config`: app efímera `<app>:<canal>`; usa ese nombre completo en `app=` si creas más canales sobre esa conexión. Si no conecta tras `reconnect_attempts`, `STASISSTATUS=FAILED`.
- Una app Stasis solo puede pertenecer a una conexión. Nunca compartas una conexión de websocket_client entre ARI y media.
- CLI: `ari show outbound-websockets`, `ari show outbound-websocket conn1`, `ari show sessions`, `ari shutdown websocket session conn1`, `ari start outbound-websocket conn1`.
- Recarga: `module reload res_ari.so` (recarga también websocket_client.conf).

REST sobre el WS (sin HTTP aparte):
```json
{"type":"RESTRequest","request_id":"r1","method":"POST","uri":"channels/<id>/answer"}
```
Respuesta `{"type":"RESTResponse","request_id":"r1","status_code":204,...,"message_body":"..."}`. Parámetros: query string, `query_strings[]`, o `content_type` + `message_body` (elige UNA forma). No sirve para binarios (recordings: 406) ni para `GET events`.

## 5. Media externa

### chan_websocket (23.0 / 22.6 / 21.11 / 20.16 en adelante)
Media cruda (sin cabeceras RTP) en frames **BINARY**; control y eventos en frames **TEXT**. Asterisk retemporiza y reencuadra lo que envías (salvo passthrough).

Crear el canal:
- Dialplan saliente: `Dial(WebSocket/<cliente_ws>/c(slin16)f(json))` (cliente definido en websocket_client.conf, `connection_type=per_call_config`).
- Dialplan entrante (tu app conecta a Asterisk): `Dial(WebSocket/INCOMING/c(slin16)f(json))`; tu app conecta a `ws(s)://asterisk:8088/media/${MEDIA_WEBSOCKET_CONNECTION_ID}`.
- ARI: `POST /channels/externalMedia?app=bot&transport=websocket&encapsulation=none&external_host=<cliente_ws|INCOMING>&format=slin16&transport_data=f(json)` (+ `connection_type=server` para entrante).
- Opciones del dialstring: `c(codec)`, `n` (no autocontestar), `f(json|plain-text)`, `p` (passthrough; auto en opus/speex/g729), `u` (unbuffered, 24+), `v(p1=v1,...)` (parámetros URI, codificar con URIENCODE), `d(in|out|both)` (dirección).

Reglas de media: enviar exactamente `optimal_frame_size` (p. ej. 160 B ulaw/20 ms, 640 B slin16/20 ms) o múltiplos; si no, usa `START_MEDIA_BUFFERING` … `STOP_MEDIA_BUFFERING <id>` (evento `MEDIA_BUFFERING_COMPLETED`). Máximo 65 500 bytes por mensaje (más = se cuelga la llamada). Cola ~1000 frames (~20 s): `MEDIA_XOFF` ~900 → deja de enviar; `MEDIA_XON` <~800.

Comandos (TEXT, sensibles a mayúsculas, JSON `{"command":"..."}`): `ANSWER`, `HANGUP`, `START_MEDIA_BUFFERING`, `STOP_MEDIA_BUFFERING`, `FLUSH_MEDIA` (barge-in), `PAUSE_MEDIA`, `CONTINUE_MEDIA`, `MARK_MEDIA` (+`correlation_id`), `GET_STATUS`, `REPORT_QUEUE_DRAINED`, `SET_MEDIA_DIRECTION`.
Eventos: `MEDIA_START` (connection_id, channel_id, format, optimal_frame_size, ptime, channel_variables en JSON), `DTMF_END`, `MEDIA_XOFF`, `MEDIA_XON`, `STATUS`, `MEDIA_BUFFERING_COMPLETED`, `MEDIA_MARK_PROCESSED`, `QUEUE_DRAINED`.
Ejemplos oficiales: `github.com/asterisk/asterisk-websocket-examples`.

### AudioSocket
TCP simple: `AudioSocket(<uuid>,host:puerto)` en dialplan o `Dial(AudioSocket/host:puerto/<uuid>)`, o externalMedia `encapsulation=audiosocket&transport=tcp`. Paquetes TLV: 1 byte tipo + 2 bytes longitud (big-endian) + payload. Tipos: `0x00` hangup, `0x01` UUID (16 bytes), `0x03` DTMF, `0x10` audio slin 8 kHz 16 bit mono LE, `0xff` error. Versiones recientes admiten otras tasas slin (verifica en la doc del canal AudioSocket de tu versión). Tú controlas la temporización (20 ms = 320 bytes a 8 kHz).

### externalMedia RTP
`transport=udp&encapsulation=rtp&external_host=10.0.0.5:4000&format=slin16`: Asterisk envía RTP a ese host y acepta RTP de vuelta. Variables `UNICASTRTP_LOCAL_ADDRESS/PORT` en el canal indican a dónde enviar. Debes generar RTP bien temporizado.

## 6. Patrón: agente de voz con IA

```
Llamante ──PJSIP──▶ Stasis(bot) ──▶ App (ARI)
                                     ├─ answer
                                     ├─ crea bridge mixing
                                     ├─ externalMedia transport=websocket, format=slin16, f(json)
                                     ├─ addChannel [llamante, externalMedia]
                                     └─ WS de media ⇄ STT/LLM/TTS (o API speech-to-speech)
```
- Formato: `slin16` (16 kHz PCM) para STT; si el proveedor de IA usa 24 kHz, `slin24`/`slin48` y deja a Asterisk transcodificar, o resamplea en tu app.
- Barge-in: cuando el STT/VAD detecta voz del usuario, envía `FLUSH_MEDIA`. Con `MARK_MEDIA` sabrás hasta dónde escuchó el usuario (para truncar el contexto del LLM).
- TTS por trozos: envuelve cada respuesta en START/STOP_MEDIA_BUFFERING con un correlation_id; respeta XOFF/XON.
- Transferir a humano: `POST /channels/{id}/continue` a un contexto con `Queue()`, o crea un canal hacia el agente y muévelo al bridge; termina el externalMedia.
- Alternativa sin código ARI: `Dial(WebSocket/bot/c(slin16)f(json)v(caller=${URIENCODE(${CALLERID(num)})}))` directamente en el dialplan.
- Latencia: coloca el servicio IA cerca de Asterisk, usa `u` (unbuffered, 24+) si tu app ya envía frames de 20 ms bien temporizados.
- Grabación y transcripción paralela: `snoop` + externalMedia, o MixMonitor.

## 7. AMI (manager.conf)

```ini
[general]
enabled = yes
port = 5038
bindaddr = 127.0.0.1
displayconnects = no
; tlsenable = yes / tlsbindaddr = 0.0.0.0:5039 / tlscertfile / tlsprivatekey

[crm]
secret = SECRETO-LARGO
deny = 0.0.0.0/0.0.0.0
permit = 10.0.0.20/255.255.255.255
read = call,agent,user,dtmf,reporting,cdr
write = originate,call,agent
; eventfilter = !Event: Newexten   ; reduce ruido
writetimeout = 1000
```
Protocolo: líneas `Clave: valor`, mensajes terminados en línea vacía. `Action: Login` → `Action: Originate` (`Channel`, `Context`, `Exten`, `Priority`, `CallerID`, `Variable`, `Async: true`, `ActionID`) → eventos `OriginateResponse`. Acciones frecuentes: `CoreShowChannels`, `Hangup`, `Redirect`, `Getvar/Setvar`, `QueueStatus/QueueSummary`, `QueueAdd/QueueRemove/QueuePause`, `PJSIPShowEndpoints`, `PJSIPShowRegistrationsOutbound`, `DBGet/DBPut`, `Command` (requiere `write=system`/`command`: evitar), `MixMonitor`, `UserEvent`. Clases peligrosas: `system`, `command`, `config`, `originate` (puede hacer llamadas de pago) — concédelas solo si hace falta. Librerías: `panoramisk` (Python asyncio), `asterisk-manager` (Node), `asterisk-ami-client`, PAMI (PHP).

## 8. AGI / FastAGI

- `AGI(script.py,args)` (en `/var/lib/asterisk/agi-bin`), `AGI(agi://10.0.0.5:4573/ruta)` (FastAGI por red; preferible), `EAGI` (audio por fd 3), AsyncAGI vía AMI (`AGI(agi:async)`).
- Protocolo: Asterisk envía variables `agi_*` y línea vacía; el script escribe comandos (`ANSWER`, `STREAM FILE hello-world ""`, `GET DATA prompt 5000 4`, `SET VARIABLE X "1"`, `EXEC Dial PJSIP/1001`, `GET VARIABLE`, `VERBOSE "msg" 1`, `HANGUP`) y lee `200 result=...`.
- Síncrono: un hilo por llamada; tiempo de respuesta crítico. `agi set debug on` para depurar. Librerías: `pyst2`, `asterisk-agi`, PHPAGI, `node-agi`.
- Si el llamante cuelga, AGI recibe `HANGUP`/SIGHUP; usa `AGISIGHUP=no` si no quieres la señal. (`DeadAGI` eliminado en 23: usa `AGI`).

## 9. Call files

```
Channel: PJSIP/1001
CallerID: "Recordatorio" <1000>
MaxRetries: 2
RetryTime: 60
WaitTime: 30
Context: recordatorios
Extension: s
Priority: 1
Setvar: CITA=martes 10hs
```
Crear en `/var/spool/asterisk/tmp`, `chown asterisk`, opcional `touch -d` futuro, y `mv` a `/var/spool/asterisk/outgoing/`. `Archive: yes` guarda el resultado en `outgoing_done`.

## 10. CDR, CEL, queue_log, métricas

- `cdr.conf` (`enable=yes`, `unanswered`, `batch`), backends: `cdr_csv` (`/var/log/asterisk/cdr-csv/Master.csv`), `cdr_custom`, `cdr_adaptive_odbc` (columnas libres, recomendado), `cdr_pgsql`, `cdr_radius`. Campos: `src`, `dst`, `dcontext`, `channel`, `dstchannel`, `lastapp`, `start/answer/end`, `duration`, `billsec`, `disposition`, `uniqueid`, `linkedid`, `userfield` (`Set(CDR(userfield)=...)`). Deshabilitar en una llamada: `Set(CDR_PROP(disable)=1)`.
- CEL (`cel.conf`, `cel_odbc`/`cel_pgsql`): eventos detallados (CHAN_START, ANSWER, BRIDGE_ENTER, LINKEDID_END…) para facturación/análisis precisos. Correlaciona con `linkedid`.
- `queue_log` a archivo o realtime (tabla `queue_log`, en MySQL/MariaDB 24 la columna `time` pasa a DATETIME(6)).
- Prometheus: `res_prometheus` + `prometheus.conf` (`enabled=yes`, `uri=metrics`, auth básica) sirve `/metrics` vía http.conf. MES (calidad de media) por RTCP en AMI/ARI.
- HEP/Homer: `res_hep`, `res_hep_pjsip`, `res_hep_rtcp` para captura centralizada de SIP.
