# Catálogo de la documentación de Asterisk

Base: `https://docs.asterisk.org/` (MkDocs, repo `github.com/asterisk/documentation`). Código: `github.com/asterisk/asterisk`. Comunidad: `community.asterisk.org`. Descargas y ChangeLogs: `https://downloads.asterisk.org/pub/telephony/asterisk/`.

> Algunas páginas de la doc son antiguas (siguen mencionando chan_sip, Skinny, mISDN o sintaxis vieja). Ante conflicto, manda la referencia generada del módulo (`Latest_API`) y el ChangeLog.

## Versiones (estado oct-2026)

| Serie | Tipo | Publicada | Solo seguridad desde | EOL | Estado / última |
|---|---|---|---|---|---|
| 18 | LTS | 2020-10 | 2024-10 | 2025-10-20 | EOL |
| 19 | Estándar | 2021-11 | — | 2023-11 | EOL |
| 20 | LTS | 2022-10-19 | 2026-10-19 | 2027-10-19 | 20.21.0 (20.22.0-rc1) |
| 21 | Estándar | 2023-10-18 | 2025-10-18 | 2026-10-18 | 21.12.3, solo seguridad |
| 22 | LTS | 2024-10-16 | 2028-10-16 | 2029-10-16 | 22.11.0 (22.12.0-rc1) — **recomendada** |
| 23 | Estándar | 2025-10-15 | 2026-10-15 | 2027-10-15 | 23.5.0 (23.6.0-rc1) |
| 24 | LTS | 2026-10-15 | 2030-10-15 | 2031-10-15 | 24.0.0-rc1 (pre-release) |

Política: una versión mayor por año (alterna estándar/LTS). LTS = 4 años completos + 1 de seguridad; estándar ≥1+1. Bugfix cada 4–6 semanas. Rama nueva el 2.º jueves de agosto, RC el 2.º jueves de septiembre, release el 3.er jueves de octubre.

Certified Asterisk (soporte comercial de Sangoma, ramas congeladas): 18.9, 20.7, 22.8.

Plataformas soportadas por el proyecto: Linux x86 32/64 bits en CentOS/RHEL, Fedora, Ubuntu y Debian no EOL. Otras (ARM, Alpine, BSD) = esfuerzo de la comunidad.

## Estructura de docs.asterisk.org

- **About the Project**: historia, vulnerabilidades (`/About-the-Project/Asterisk-Security-Vulnerabilities/`), versiones, plataformas, licencia (GPLv2).
- **Fundamentals**: arquitectura, tipos de módulos (channel drivers, apps, funciones, recursos, codecs, formatos, bridges, PBX, CDR/CEL), canales, bridges, frames.
- **Getting Started**: Beginning Asterisk, instalación desde fuente (What to Download, Prerequisites, Menuselect, Build & Install, Sample Files, Init Scripts, Validating, Sound Prompts), métodos alternativos, Hello World.
- **Configuration**:
  - Core Configuration (asterisk.conf, modules.conf, sintaxis de .conf, plantillas, `#include`, `#exec`, timing).
  - Channel Drivers: SIP → *Configuring res_pjsip* (Troubleshooting Guide, Outbound Registrations, IPv6, Presence, NAT, Dialing PJSIP Channels, Device/Mailbox State, Migrating from chan_sip, Advanced Codec Negotiation, Authentication, Sections and Relationships, Configuration Wizard, Transport Selection, Proxies, Publishing Extension State, RLS, Realtime, Configuration Examples, Remote Attended Transfers); DAHDI; IAX2; Local Channel; AudioSocket; WebSocket; Mobile; Motif; IP QoS.
  - Dialplan, Applications, Functions, Features (transferencias, parking, pickup, call completion, colas, voicemail, conferencias…).
  - Interfaces: AMI, ARI (Libraries, Outbound Websockets, REST over WebSocket, Versioning, Configuration, Getting Started, Transfers, Bridges, Broadcast, Channels, Media), AGI, AEAP (speech externo), Realtime/DB, Distributed Device State, Call Files, Calendaring, StatsD.
  - Reporting (CDR, CEL, queue_log), Miscellaneous (ICE/STUN/TURN, video, fax…), WebRTC (Configuring Asterisk for WebRTC Clients, CyberMegaPhone, sipML5), Codec Opus.
- **Deployment**: Security Framework, Basic PBX, Deployment in your network, DUNDi, Emergency Calling, Enhanced Messaging, Geolocation, **Important Security Considerations** (Dialplan, Log, Network Security), i18n, IPv6, Media Experience Score, PLC, Performance Tuning, Phone Provisioning, Privacy, PSTN Connectivity, Reference Use Cases, Secure Calling (TLS/SRTP), STIR/SHAKEN, Troubleshooting.
- **Operation**: Audio/Video capabilities, CLI, Logging, Maintenance & Upgrades, Running Asterisk, System Requirements.
- **Development**: políticas, debugging (backtraces, `ast_coredumper`), referencia, roadmap, deprecaciones de C API y de **módulos** (`/Development/Asterisk-Module-Deprecations/`).
- **Latest API** y **Asterisk NN Documentation** (por versión): Upgrading, What's New, API Documentation (AMI Actions/Events, ARI, Dialplan Applications/Functions, Module Configuration, AGI Commands).

## URLs más útiles

| Necesitas | URL |
|---|---|
| Opciones de pjsip.conf | `/Latest_API/API_Documentation/Module_Configuration/res_pjsip/` |
| Registro saliente | `.../Module_Configuration/res_pjsip_outbound_registration/` |
| identify por IP | `.../Module_Configuration/res_pjsip_endpoint_identifier_ip/` |
| ACL PJSIP | `.../Module_Configuration/res_pjsip_acl/` |
| ari.conf / websocket_client.conf / chan_websocket.conf | `.../Module_Configuration/res_ari/`, `res_websocket_client/`, `chan_websocket/` |
| Dial | `/Latest_API/API_Documentation/Dialplan_Applications/Dial/` |
| ARI channels | `/Latest_API/API_Documentation/Asterisk_REST_Interface/Channels_REST_API/` |
| NAT PJSIP | `/Configuration/Channel-Drivers/SIP/Configuring-res_pjsip/Configuring-res_pjsip-to-work-through-NAT/` |
| Troubleshooting PJSIP | `/Configuration/Channel-Drivers/SIP/Configuring-res_pjsip/Asterisk-PJSIP-Troubleshooting-Guide/` |
| Auth PJSIP (SHA-256) | `/Configuration/Channel-Drivers/SIP/Configuring-res_pjsip/PJSIP-Authentication/` |
| Wizard | `/Configuration/Channel-Drivers/SIP/Configuring-res_pjsip/PJSIP-Configuration-Wizard/` |
| WebRTC | `/Configuration/WebRTC/Configuring-Asterisk-for-WebRTC-Clients/` |
| chan_websocket | `/Configuration/Channel-Drivers/WebSocket/` |
| ARI outbound WS | `/Configuration/Interfaces/Asterisk-REST-Interface-ARI/ARI-Outbound-Websockets/` |
| ARI REST sobre WS | `/Configuration/Interfaces/Asterisk-REST-Interface-ARI/ARI-REST-over-WebSocket/` |
| External media | `/Development/Reference-Information/Asterisk-Framework-and-API-Examples/External-Media-and-ARI/` |
| STIR/SHAKEN | `/Deployment/STIR-SHAKEN/` |
| Seguridad dialplan | `/Deployment/Important-Security-Considerations/Dialplan-Security/` |

Ejemplos de código oficiales: `github.com/asterisk/ari-examples`, `github.com/asterisk/asterisk-websocket-examples` (Python, ARI + media WebSocket). Avisos de seguridad: `github.com/asterisk/asterisk/security/advisories`.
