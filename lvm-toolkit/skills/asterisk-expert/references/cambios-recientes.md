# Cambios por versión: eliminaciones, deprecaciones y novedades

Consulta esto antes de dar configuración. Fuente: ChangeLogs oficiales y `/Development/Asterisk-Module-Deprecations/`.

## Tabla de "esto ya no existe → usa esto"

| Obsoleto / eliminado | Desde | Reemplazo |
|---|---|---|
| `chan_sip`, `sip.conf`, `Dial(SIP/...)`, `SIPPEER()`, `SIP_HEADER()` | eliminado 21 | `chan_pjsip`/`pjsip.conf`, `PJSIP/`, `PJSIP_HEADER()`, `CHANNEL(pjsip,...)`, `PJSIP_ENDPOINT()` |
| `app_macro` / `Macro()`, `Dial(...M())` | eliminado 21 | `Gosub()`/`Return()`, `Dial(...U())`, pre-dial `b()`/`B()` |
| `res_monitor` / `Monitor()`, `StopMonitor`, Queue opciones `w`/`W`, `monitor-type` | eliminado 21 | `MixMonitor()`, `StopMixMonitor`, AMI `MixMonitor` |
| `chan_skinny`, `chan_mgcp`, `chan_alsa`, `app_osplookup`, `res_pktccops` | eliminado 21 | PJSIP / sin reemplazo |
| `NoCDR`, `ResetCDR(e)`, `ImportVar`, `SetAMAFlags` | eliminado 21 | `CDR_PROP(disable)`, `IMPORT()`, `CHANNEL(amaflags)` |
| `SLAStation`/`SLATrunk` en app_meetme | movido 21 | módulo `app_sla` (cárgalo si `autoload=no`) |
| `users.conf` | deprecado 21, **eliminado 23** | config propia de cada driver; res_phoneprov → `phoneprov_users.conf` |
| `DeadAGI` | eliminado 23 | `AGI()` |
| MOH `random=yes`, `application=...r` | eliminado 23 | `sort=random` |
| voicemail `maxmessage`/`minmessage`, idioma `cz` | eliminado 23 | `maxsecs`/`minsecs`, `cs` |
| `QUEUE_MEMBER_COUNT()` | eliminado 23 | `QUEUE_MEMBER(cola,logged)` |
| `VALID_EXTEN()` | eliminado 23 | `DIALPLAN_EXISTS()` |
| CLI `no debug channel` | eliminado 23 | `core set debug channel` |
| logger `rotatetimestamp` | eliminado 23 | `rotatestrategy` |
| `app_meetme` / `MeetMe()` | deprecado (19), retirada en pausa | `ConfBridge()` |
| `app_fax`, `cdr_mysql`, `app_mysql`, `chan_misdn`, `chan_oss`, `res_config_sqlite`, `cdr_syslog`… | eliminado 19 | `res_fax`+`res_fax_spandsp` (ReceiveFAX/SendFAX), `cdr_adaptive_odbc`, ODBC |
| PJSIP `auth_type=userpass` / `md5`, `md5_cred` | deprecado (20.12/21.7/22.2) | `auth_type=digest`, `password_digest=MD5:...` |
| chan_websocket control en texto plano | deprecado (20.18/22.8/23.2) | formato JSON (`f(json)` o chan_websocket.conf) |
| app_getcpeid, app_adsiprog, res_adsi | deprecados (16), mantenidos | — |

## Cambio de semántica en 23 (configuración)

La herencia de plantillas cambió: `ast_variable_retrieve`/`ast_variable_update` ahora devuelven/actualizan el **último** valor (el que sobrescribe la plantilla), no el primero. Configs que dependían del comportamiento viejo pueden cambiar de efecto. Equivale a `AST_CONFIG(...,-1)`.

## Novedades relevantes (con versión de llegada)

**PJSIP**
- Digest **SHA-256 y SHA-512-256** (20.12.0, 21.7.0, 22.2.0; pjproject 2.15.1; OpenSSL ≥1.1.1 para SHA-512-256). Opciones `password_digest`, `supported_algorithms_uas`, `supported_algorithms_uac`, y globales `default_auth_algorithms_uas/uac`. Ver con `pjproject show buildopts`.
- `identify_by=transport` (21.3/20.8): identifica el endpoint por el transport de llegada.
- Transferencias controladas por ARI: `Set(PJSIP_TRANSFER_HANDLING(ari-only)=...)` (22.3).
- 24: el qualify sondea **todos** los destinos SRV/A/AAAA resueltos (contacto alcanzable si responde cualquiera).
- 24: `pjsip_wizard.conf.sample` con ejemplos de troncal por IP con varios hosts y TLS+SRTP. Recordatorio: el wizard no crea transports.

**ARI / WebSockets / IA**
- `ChannelToneDetected` (22.0) al usar `TONE_DETECT` en canales de ARI.
- **ARI Outbound WebSockets** + `res_websocket_client` + `websocket_client.conf` (22.5.0 y equivalentes 20/21): Asterisk conecta a tu app (persistente o por llamada).
- **ARI REST sobre WebSocket** (misma época, serie 22): `RESTRequest`/`RESTResponse` por el WS de eventos.
- **chan_websocket** (23.0.0, 22.6.0, 21.11.0, 20.16.0): media cruda por WebSocket sin RTP; `externalMedia` con `transport=websocket&encapsulation=none`.
  - JSON en control y `transport_data` en externalMedia (20.18.0, 22.8.0, 23.2.0).
  - Opciones `p` (passthrough; automático para opus/speex/g729), `v()` (parámetros URI), evento `DTMF_END` (23.0 y backports).
  - 24: modo `u` (unbuffered), `write_timeout` en websocket_client.conf y chan_websocket.conf (ari.conf ya tenía `websocket_write_timeout`), MEDIA_START con `passthrough`/`unbuffered`, MARK_MEDIA en passthrough.
- ARI `POST /channels/{id}/progress` (23.0).
- 24: `channels.record` funciona mientras el canal marca vía ARI.

**Otros**
- `disable_remote_console_shell` en asterisk.conf (22.5): impide `!comando` de shell desde consolas remotas.
- Backend alternativo de almacenamiento de canales (22.5; ver `channelstorage_backend` en asterisk.conf — verificar nombre exacto).
- Media Experience Score (MES) en RTCP/AMI/ARI (21+; cálculo corregido en 24).
- STIR/SHAKEN refactorizado (20.7/21.2): config nueva de `stir_shaken.conf`; las configs anteriores no son compatibles.
- `sorcery.conf [general] update_or_create_on_update_miss` (23) para backends múltiples (astdb+realtime).
- `app_queue` `log_unpause_on_reason_change` (23); 24: `queue_log.time` → `DATETIME(6)` en MySQL/MariaDB vía Alembic (ALTER bloqueante en tablas grandes).
- ConfBridge `announcements=no` en bridge profile (24): sin canal anunciador.
- `res_prometheus`: `channels_detail_metrics_enabled`, `bridges_detail_metrics_enabled` (24).
- `ChanSpy`/`ExtenSpy` opción `N` (no contestar) (23); `WaitExten(d(tono))` (23); `TONE_DETECT` opción `e` auto-stop (23).
- Seguridad 23.0: GHSA-64qc-9x89-rx5j (crash por Authorization malformado) → mantén versiones al día.

## Cómo actualizar entre versiones

1. Lee el ChangeLog de **cada** versión mayor intermedia (sección *Upgrade Notes*).
2. Busca en tu config módulos eliminados: `grep -RniE "SIP/|Macro\(|Monitor\(|users.conf|DeadAGI|VALID_EXTEN|QUEUE_MEMBER_COUNT" /etc/asterisk`.
3. Recompila módulos de terceros (codec_g729, codec_opus, etc.) para la versión nueva.
4. Si usas realtime, aplica migraciones Alembic (`contrib/ast-db-manage`).
5. Prueba en staging con `make samples` aparte para comparar `.conf.sample` nuevos.
