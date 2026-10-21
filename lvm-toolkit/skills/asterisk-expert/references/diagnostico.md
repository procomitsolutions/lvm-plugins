# Diagnóstico

Primero recolecta: `core show version`; `core set verbose 5`; `core set debug 4` (opcional); `pjsip set logger on` (o `host <ip>`); reproduce; revisa `/var/log/asterisk/full` filtrando por `[C-xxxxxxxx]`. Para captura de red: `sngrep` (SIP+RTP, interactivo) o `tcpdump -i any -nn -s0 -w cap.pcap port 5060 or portrange 10000-20000`. Ofusca credenciales al compartir trazas.

## Síntoma → causa probable → acción

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| Endpoint no aparece en `pjsip show endpoints` | Falta `type=`, opción mal escrita, error de carga | Revisa log de arranque (`Could not find option suitable`, `Could not create an object`), corrige, `pjsip reload` |
| 401 en bucle aunque la clave es correcta | El endpoint no existe/no se identificó (401 "falso") o usuario/clave con distinta mayúscula, `username` ausente | `pjsip show endpoint X`; si existe, revisa `InAuth:`, username/password/realm |
| 403 Forbidden al registrar | AOR sin `max_contacts` o lo excede | `max_contacts=1` + `remove_existing=yes` |
| Llamada entrante de troncal rechazada | No casa ningún `identify`; IP de origen distinta (otro POP) | `pjsip show identifies`, añade `match`; mira `Source address ... does not match` con debug |
| `extension not found in context` | Contexto del endpoint o número entrante distinto al esperado (formato E.164, `+`) | `dialplan show <ctx>`; usa `NoOp(${EXTEN})`, ajusta patrón |
| `No channel type registered for 'SIP'` | Dialplan con `SIP/` | Cambia a `PJSIP/` |
| `endpoint 'x' was not found` / `No route to destination` / `empty aor list` | Endpoint no cargado, AOR sin `aors=` o sin contactos (no registrado o sin `contact=`) | `pjsip show aor X`, `pjsip show contacts` |
| Registro saliente `Rejected`/`Unregistered` | Credenciales, `client_uri`/`server_uri` sin `sip:`, realm forzado | `pjsip show registrations`, logger; tras corregir `pjsip send register <reg>` |
| **Sin audio / audio en un solo sentido** | NAT: SDP con IP privada; RTP bloqueado; `direct_media` entre redes; SIP ALG | Revisa `c=` en el SDP con logger; configura `local_net` + `external_*`; abre rango RTP; `direct_media=no`; `rtp_symmetric=yes`; desactiva ALG; `rtp set debug on` para ver si llegan paquetes |
| Llamada se corta a ~30–32 s | ACK no llega (Contact inalcanzable por NAT, UDP fragmentado, ALG) | `rewrite_contact=yes`, `force_rport=yes`, `external_signaling_address`; usar TCP si los paquetes son grandes |
| Se corta tras X minutos | Session timers o `rtp_timeout` | `timers=no` (o ajustar), revisa RTP en espera (`rtp_timeout_hold`) |
| DTMF no funciona en IVR | Modo DTMF distinto, telephone-event no negociado, transcodificación con inband | `dtmf_mode=rfc4733` o `auto`; con `inband` usar ulaw/alaw |
| Audio robótico/cortado | Pérdida/jitter de red, CPU por transcodificación, frames mal temporizados (externalMedia/AudioSocket) | `rtp set stats`/RTCP, MES, `core show translation`, revisar temporización 20 ms |
| Eco | Terminales/gateways analógicos | Cancelación de eco en el gateway/DAHDI (`echocancel`) |
| Codec incompatible (488 Not Acceptable Here) | Sin intersección de codecs, opus no instalado | `core show codecs`, `allow=`, instala codec_opus |
| Teléfono no recibe llamadas tras un rato | Binding NAT expiró | `qualify_frequency=25`, expiración de registro más corta |
| BLF no actualiza | Hint en otro contexto, `allow_subscribe=no`, falta `res_pjsip_exten_state` | `core show hints`, contexto del endpoint |
| MWI denegado | `mailboxes` en endpoint y AOR a la vez; buzón sin `@contexto` | Deja uno; usa `1001@default` |
| ARI: `Stasis` falla al instante | Nadie conectado con esa app / outbound WS caído | `ari show apps`, `ari show sessions`, `STASISSTATUS` |
| ARI 404/409 en `channels/x/...` | Canal ya colgado o fuera de Stasis | Gestiona `StasisEnd`/`ChannelDestroyed` |
| chan_websocket: audio entrecortado o con huecos | Mensajes de tamaño distinto al `optimal_frame_size`, sin buffering, XOFF ignorado | START/STOP_MEDIA_BUFFERING, respetar XON/XOFF, `GET_STATUS` |
| chan_websocket se cuelga la llamada | Mensaje >65 500 bytes, control enviado como BINARY | Trocear; control en TEXT |
| WebRTC no conecta | Certificado no confiable, `wss` no habilitado, puerto 8089 cerrado, falta `res_http_websocket` | `http show status` (debe listar `/ws`), abre `https://host:8089/ws` en el navegador |
| WebRTC conecta pero sin audio | ICE/DTLS: falta STUN/TURN, rango RTP cerrado, `webrtc=yes` ausente | `rtp.conf` ice/stun/turn; revisar candidatos en el SDP |
| AMI no conecta | `bindaddr`, `permit/deny`, `enabled=no` | `manager show settings`, `manager show users` |
| Asterisk no arranca | Puerto ocupado, permisos, módulo roto | `asterisk -cvvvvvg`, `journalctl -u asterisk` |
| Crash | Bug/módulo de terceros | `ast_coredumper`, actualizar a la última minor, reportar con backtrace |

## Requisitos para que direct_media funcione

Dos endpoints en el mismo bridge, ambos con `direct_media=yes`, codecs compatibles, sin NAT detectado (si `disable_direct_media_on_nat=yes`), y sin nada que toque el audio (MixMonitor, ChanSpy, VOLUME, TALK_DETECT, jitterbuffer, snoop de ARI, ConfBridge, fax) ni opciones de Dial que intercepten DTMF (`t T k K w W x X`).

## Comandos rápidos

```
pjsip show endpoint 1001      pjsip show contacts         pjsip show registrations
pjsip set logger host 203.0.113.10                         pjsip show history
rtp set debug on ip 203.0.113.10                           core show channels verbose
dialplan show 1001@internos   core show hints              ari show sessions
module show like pjsip        core show settings           logger add channel /tmp/x.log debug,verbose
```
