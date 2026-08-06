---
name: contexto-infra-procom
description: Referencia viva de la infraestructura de Procom/Flexxus/Wuala que maneja Martín (equipo LVM) — nodos de Docker Swarm, entornos de Portainer, load balancers, cuentas y zonas de Cloudflare, orgs de GitHub, convenciones de nombres. Usar SIEMPRE que la conversación mencione stacks, nodos wn0X, Portainer, Cloudflare, Flexxus, Wuala/PrestaShop, Traefik, o cualquier tarea de infraestructura de Procom — para no volver a preguntar datos que ya están documentados acá. También usar cuando Martín corrija o agregue un dato de infra nuevo (IP, cuenta, convención) para anotarlo en este archivo.
---

# Contexto de infraestructura Procom

Este skill es una libreta de referencia, no un flujo de pasos. Leelo entero al arrancar cualquier
tarea de infra de Procom y usalo para no volver a preguntar cosas ya conocidas.

**Mantenimiento**: cuando en la conversación aparezca un dato nuevo o una corrección (IP, cuenta,
convención de nombres, nodo agregado/dado de baja), actualizá la sección correspondiente de este
archivo con `str_replace` antes de terminar el turno. Si el dato es efímero (una IP de test, un
password de un incidente puntual) NO lo agregues acá — esto es para lo que se repite.

## Topología Docker Swarm

- Dos entornos en el mismo Portainer (Business Edition, ~2.27–2.39 LTS según stack):
  - **MSOffice**: workers 1–7, 14, 15. Portainer endpoint ID 3. LB: `lb-wuala.procomitsolutions.com`
  - **Capitalinas**: workers 8–13. Portainer endpoint ID 5. LB: `lb03.mitiendaonline.com`
- Mapeo nodo→datacenter (columna `datacenter`): wn01–wn07, wn14, wn15 → MSoffice; el resto → Capitalinas
- `worker8` es el host fijo de origen para rsync de volúmenes template (`template824`)
- Flexxus corre en Portainer separado (single endpoint `primary`), Business Edition 2.27.3 LTS
- Convivencia de endpoints Standalone + Swarm en el mismo Portainer: `build:` en compose SOLO
  funciona en Standalone; cualquier stack destinado a Swarm necesita imágenes pre-construidas
- Traefik como reverse proxy delante de todo, logging a Loki. Contenedores en UTC, hosts worker en
  ART (UTC-3) — diferencia de 3h a tener en cuenta al leer timestamps de logs

## Portainer — API / gotchas

- El agente de Portainer requiere el header `X-PortainerAgent-Target` con el hostname del nodo para
  `inspect` per-container en modo Swarm — sin eso, 404
- Versión real de PrestaShop: leer env var `PS_VERSION` vía inspect, NO el tag de imagen (la mayoría
  usa `latest`)
- Credenciales admin en env vars: `ADMIN_PASSWD` (no `ADMIN_PASSWORD`) y `ADMIN_MAIL`

## Cloudflare — cuentas y zonas

| Contexto | Cuenta | Zona / dominio | Proxy |
|---|---|---|---|
| Wuala (PrestaShop) | `webmaster@wuala.net` | `mitiendaonline.com` | Desactivado |
| Flexxus API (procomisp) | `soporte@procomargentina.com` | `procomisp.com.ar` (zone id `6889adfeb5005e5c8c439367b1cd7d1c`) | Activado |
| Flexxus API-APP (extra) | `Emiliano.barrera@flexxus.com.ar` | `flexxus.com.ar` | — |

- Alta Wuala: CNAME `<cliente>.mitiendaonline.com` y `www.<cliente>.mitiendaonline.com` →
  `lb-wuala.procomitsolutions.com` o `lb03.mitiendaonline.com` según worker
- Alta Flexxus API: CNAME `<cliente>.procomisp.com.ar` → `lb01.flexxus.com.ar`
- Variante API-APP Flexxus agrega además un CNAME en el AD Windows de Flexxus (192.168.121.12, vía
  administrador de DNS), alias `<cliente>` → `lb01.flexxus.com.ar`

## GitHub — orgs y templates

- **wuala-net**: template `wuala-net/template824-mitiendaonline-com`; registro de puertos en
  `wuala-net/customers` (README.md)
- **gitflexxus**: template `apiflexxustemplate-flexxus-com-ar`; registro de puertos en
  `gitflexxus/PortsInUsed/ports.json` (array `{cliente, port}`, próximo puerto = `max(port)+1`,
  arrancaba en 15516; escritura con optimistic locking vía `sha` del archivo)
- Convención de nombre de cliente: `<cliente>-flexxus-com-ar` (Flexxus) / minúsculas siempre para
  Wuala (paths de volumen, dominios, destino de rsync)
- Auth de GitHub REST API: Bearer token solo (no `GITHUB_USER`). Portainer usa credential ID
  guardado (`PORTAINER_GIT_CREDENTIAL_ID`), no credenciales inline

## Firebird — clientes y réplicas conocidas

- **Rosso Materiales**: origen `10.150.2.250:m:\ROSSO\DB-ROSSO.gdb` (MAIN, 29GB) y
  `\ROSSO\DB-MLT-ROSSO.gdb` (MLT, 2.1GB), Windows Server FB 2.5.9.27139 (ODS 11.2, page size 8192).
  Destino: contenedor Linux en worker7 (10.150.4.11), `fbrossomateriales.gdb` /
  `fbrossomateriales-mlt.gdb`. Firewall entre VLANs: solo puerto 3050 pasa (445/139/ICMP dropeados)
- Orquestación estándar de réplicas: cron en TrueNAS → `ssh root@<host-swarm> 'bash -s' < script.sh`
  (el script corre en el host Linux, no en el TrueNAS)
- Gestión de usuarios en Firebird 2.5: no hay `CREATE USER` SQL, usar `gsec` en
  `/usr/local/firebird/bin/gsec`. Passwords de 8 caracteres exactos (FB 2.5 trunca a 8 bytes)

## Otros stacks / clientes con historial

- `sibiu-mitiendaonline-com` (host wn04) — sin Cloudflare delante, cayó por bot flood a `/carrito`
- `ovnipress-mitiendaonline-com` — DB saturada, 2 cores al 100%, patrón conocido de este cluster
- `crm.flexxus.com.ar` — detrás de `lb01.flexxus.com.ar` (dos A records), certs Let's Encrypt vía
  Traefik multi-réplica (cuidado: challenge ACME solo existe en la réplica que originó la orden)
- Kong + Nginx Proxy Manager HA (escribanos/SIDANO): Kong `192.168.3.30:8001`, NPM
  `192.168.3.31`, servicio único `npm-cluster-service`, routing por Host header
  (`preserve_host=true`, `strip_path=false` obligatorios)

## Rundeck

- Está por instalarse una VM dedicada exclusivamente para Rundeck en Procom
- Patrón de jobs existente: launcher SSH a nodo remoto + script worker; sudo vía
  `/etc/sudoers.d/` con `NOPASSWD` y rutas exactas (no confiar en el privilege escalation nativo
  de Rundeck)
- Automatizaciones candidatas a ser jobs: alta-stack-wuala, alta-stack-flexxus, truncado de caché,
  sync KONG↔NPM, listado de tiendas a Grafana

## VM inventory (área LVM)

- Enfoque híbrido: vCenter/RVTools para lista maestra (OS, versión, IP) + agente bash SSH
  (`audit_agent.sh`) para detectar servicios (nativos y en Docker)
- Acceso a vCenter vía SSO/Entra ID — PowerCLI no es viable (loop de MFA)
- Host orquestador: `PROCOM-UBUNTUMATE-LVM` (10.148.0.88)
