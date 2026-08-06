---
name: chequeo-compose
description: Triage automático de un docker-compose.yml que falla al deployar en Docker Swarm/Portainer. Usar SIEMPRE que Martín pegue o suba un archivo compose y mencione un error de deploy, un stack que no levanta, o pida "revisá este compose" — sin esperar a que describa el síntoma primero. Corre el checklist completo de causas conocidas antes de pedir más información.
---

# Chequeo de docker-compose (Swarm/Portainer)

Cuando Martín pegue un compose, recorré este checklist ANTES de pedirle logs o más contexto — la
mayoría de sus errores pasados cayeron en una de estas categorías. Reportá todo lo que encuentres
de una, no de a uno.

## Checklist (en orden de frecuencia observada)

1. **`build:` en un servicio** → Swarm (`docker stack deploy`) lo ignora silenciosamente y falla con
   "no image specified". Si el compose se destina a Swarm, necesita imagen pre-construida en
   registry. Confirmar con Martín si el target es el endpoint Standalone o Swarm de Portainer (en su
   Portainer conviven los dos — ver `contexto-infra-procom`).
2. **`links:`** → no hace falta en Swarm, la resolución DNS por nombre de servicio ya funciona
   dentro del stack. Señalar como innecesario, no como error bloqueante.
3. **`secrets:` referenciado sin bloque top-level** → si un servicio usa
   `secrets: [nombre_secret]`, TIENE que existir el bloque top-level `secrets:` con
   `external: true`. Sin esto, Swarm rechaza el stack entero.
4. **Nombre de secret desalineado** → el nombre en el compose puede no coincidir con el secret real
   registrado en el nodo (`docker secret ls` es a nivel cluster, no por nodo — puede haber
   inconsistencias entre nodos). Si el error es "secret not found" con el compose aparentemente
   correcto, sospechar esto primero.
5. **Interpolación de variables con guion en vez de guion bajo** → `${MINIHOTEL-USER}` es sintaxis
   de "valor por default", NO una variable llamada `MINIHOTEL-USER`. Docker Compose no soporta
   guiones en nombres de variables; revisar que todas usen `_`.
6. **`depends_on`** → se ignora silenciosamente en modo Swarm. Si el compose depende del orden de
   arranque, señalar que hace falta un healthcheck + retry en la app, no `depends_on`.
7. **Traefik labels**:
   - Middleware de redirect declarado pero no asignado a ningún router (`traefik.http.routers.X.middlewares`
     vacío u omitido)
   - Falta `traefik.docker.network=traefik-network` cuando el servicio está en más de una red
   - Entrypoint incorrecto: el default suele ser `websecure`, no `https` — típico copy-paste error
   - Certresolver con nombre que no coincide con el configurado en la instancia real de Traefik
8. **`ports:` expuestos en un servicio ruteado por Traefik** → suele ser innecesario y es superficie
   de ataque de más (puerto público sin pasar por el proxy). Señalar como riesgo aunque no sea el
   error actual.
9. **Rutas relativas para volúmenes de datos** (p. ej. `SQLITE_PATH=./data/...`) → no resuelven
   igual dentro del contenedor que en el compose; si hay un volumen montado, la ruta debe ser
   absoluta y coincidir con el mountpoint.
10. **MariaDB/MySQL con puerto público expuesto** → flag de riesgo de seguridad, no de deploy, pero
    reportarlo igual si aparece.

## Si el compose "levanta" pero el servicio falla

Triage en 3 capas (en este orden):

1. **Portainer rechaza el deploy** → error de validación del compose mismo (categorías de arriba)
2. **La tarea no arranca** → `docker service ps <stack>_<servicio> --no-trunc` para ver el motivo
   exacto (imagen no encontrada, placement constraint, etc.)
3. **La tarea arranca y crashea** → `docker service logs <stack>_<servicio>`

Sospechosos típicos en esta capa: arquitectura de imagen (build platform vs. nodo), auth de registry
que no propaga a los workers de Swarm, placement constraints mal escritas (`${NODE}` sin resolver),
o la app fallando porque su dependencia (DB) todavía no está lista.

## Formato de respuesta

Primero el diagnóstico (qué está mal, en la lista de arriba), después el compose corregido completo
(no un diff parcial salvo que Martín pida solo el fragmento). Si hay más de un problema, numéralos
en el mismo orden en que aparecen en el archivo.
