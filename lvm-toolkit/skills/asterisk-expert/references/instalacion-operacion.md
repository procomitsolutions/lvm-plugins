# Instalación y operación

## Índice
1. Instalar desde fuente
2. Paquetes de distribución y contenedores
3. Archivos y directorios clave
4. Módulos y modules.conf
5. CLI: comandos esenciales
6. Logging
7. Servicio (systemd), arranque y parada
8. Rendimiento y dimensionamiento
9. Mantenimiento y actualización

## 1. Instalar desde fuente (método recomendado por el proyecto)

```bash
# Debian/Ubuntu/RHEL: como root
cd /usr/src
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar xzf asterisk-22-current.tar.gz && cd asterisk-22.*/
contrib/scripts/install_prereq install          # dependencias del SO
contrib/scripts/get_mp3_source.sh               # opcional: format_mp3
./configure --with-jansson-bundled              # pjproject va incluido (bundled) por defecto
make menuselect                                 # elegir módulos, sonidos, codecs
make -j$(nproc)
make install
make samples        # .conf de ejemplo comentados (sobrescribe /etc/asterisk) — o: make basic-pbx
make config         # script init / unit systemd según distro
make install-logrotate
ldconfig
```

Menuselect no interactivo (útil en CI/Docker):
```bash
make menuselect.makeopts
menuselect/menuselect --enable codec_opus --enable format_mp3 \
  --enable CORE-SOUNDS-ES-ULAW --enable CORE-SOUNDS-ES-G722 \
  --disable chan_dahdi --disable BUILD_NATIVE menuselect.makeopts
```
- `BUILD_NATIVE` desactivado si compilas en una máquina y ejecutas en otra (evita "illegal instruction").
- Sonidos en español: `CORE-SOUNDS-ES-*` y `EXTRA-SOUNDS-*` (idioma `es`); `Set(CHANNEL(language)=es)` o `language=es` en el endpoint.
- `codec_opus` y otros codecs binarios (p. ej. g729 de Sangoma) se descargan en `make install` desde menuselect "Codec Translators" (externos). `format_ogg_opus` es el formato de archivo.
- Para depurar crashes: `DONT_OPTIMIZE` y `BETTER_BACKTRACES` en "Compiler Flags".
- Usuario dedicado: `useradd -r -d /var/lib/asterisk asterisk && chown -R asterisk: /etc/asterisk /var/{lib,log,spool,run}/asterisk` y `runuser=asterisk`/`rungroup=asterisk` en asterisk.conf (o `AST_USER`/`AST_GROUP` en el entorno del servicio).

## 2. Paquetes y contenedores

- Paquetes de distro (Debian `asterisk`, EPEL…) suelen ir atrasados y con módulos distintos; aceptables para labs. Para producción compila una LTS vigente.
- Distribuciones completas (FreePBX/Sangoma, VitalPBX, Issabel, Wazo) gestionan la config por GUI: edita solo los `*_custom.conf`.
- **Docker**: no hay imagen oficial del proyecto. Compila tu propia imagen (ver plantillas). RTP necesita miles de puertos UDP: usa `network_mode: host` o reduce `rtpstart/rtpend` (p. ej. 10000–10200) y publica el rango. Monta `/etc/asterisk`, `/var/lib/asterisk`, `/var/spool/asterisk` y `/var/log/asterisk` como volúmenes.
- Kubernetes: posible pero delicado por NAT/RTP; usual es `hostNetwork: true` + nodos dedicados, o un SBC/rtpengine delante.

## 3. Archivos y directorios

| Ruta | Contenido |
|---|---|
| `/etc/asterisk/` | configuración (`asterisk.conf` define el resto de rutas) |
| `/var/lib/asterisk/` | sonidos (`sounds/<idioma>`), moh, `astdb.sqlite3`, keys, agi-bin |
| `/var/spool/asterisk/` | voicemail, monitor (grabaciones), outgoing (call files), tmp |
| `/var/log/asterisk/` | `messages`/`full`, `security`, `cdr-csv/`, `queue_log` |
| `/usr/lib/asterisk/modules/` (o lib64) | módulos `.so` |
| `/var/run/asterisk/asterisk.ctl` | socket de la consola remota |

Archivos principales: `asterisk.conf`, `modules.conf`, `logger.conf`, `pjsip.conf`, `pjsip_wizard.conf`, `extensions.conf`, `rtp.conf`, `http.conf`, `ari.conf`, `manager.conf`, `voicemail.conf`, `queues.conf`, `confbridge.conf`, `musiconhold.conf`, `features.conf`, `res_parking.conf`, `cdr.conf`, `cel.conf`, `res_odbc.conf`, `sorcery.conf`, `extconfig.conf`, `acl.conf`, `websocket_client.conf`, `chan_websocket.conf`, `stir_shaken.conf`, `indications.conf` (tonos por país: `country=es`, `ar`, `mx`…).

Sintaxis común de `.conf`: `[seccion]`, `clave=valor` (o `=>`), comentarios `;`, plantillas `[tpl](!)` y `[obj](tpl1,tpl2)`, `#include archivo.conf`, `#tryinclude`, `#exec script` (requiere `execincludes=yes`); para añadir líneas a una sección ya definida (p. ej. en otro archivo incluido) usa `[seccion](+)`.

asterisk.conf útil:
```ini
[options]
runuser = asterisk
rungroup = asterisk
live_dangerously = no        ; impide SHELL()/SYSTEM/funciones peligrosas desde AMI/ARI
transmit_silence = yes       ; mantiene RTP en grabaciones/espera (algunos NAT/proveedores)
maxcalls = 500               ; límite global (opcional)
maxload = 0.9                ; rechaza llamadas con carga alta (opcional)
; disable_remote_console_shell = yes   ; 22.5+
```

## 4. Módulos

```ini
; modules.conf
[modules]
autoload = yes
noload = chan_dahdi.so       ; si no hay hardware
noload = chan_iax2.so        ; si no se usa
noload = res_hep.so
noload = pbx_ael.so
noload = chan_unistim.so
noload = chan_mobile.so
; preload = res_odbc.so      ; cuando realtime ODBC debe cargarse antes
```
CLI: `module show like pjsip`, `module load|unload|reload <mod>.so`, `module refresh <mod>` (recarga dependientes). Desactivar lo que no usas reduce superficie de ataque.

## 5. CLI esencial

Conectar: `asterisk -rvvvvv` (consola remota con verbosidad), `asterisk -rx "comando"` (no interactivo), `asterisk -cvvv` (primer plano, para depurar arranque), `asterisk -g` (core dumps).

| Tarea | Comando |
|---|---|
| Versión / ajustes | `core show version`, `core show settings`, `core show uptime` |
| Canales y llamadas | `core show channels [verbose|concise]`, `core show channel <canal>`, `channel request hangup <canal|all>` |
| Originar llamada de prueba | `channel originate PJSIP/1001 extension 600@internal` |
| Dialplan | `dialplan show <ctx>`, `dialplan show 100@internal`, `dialplan reload` |
| PJSIP | `pjsip show endpoints|endpoint X|aors|contacts|auths|transports|registrations|identifies|channels`, `pjsip qualify X`, `pjsip send register X`, `pjsip reload` |
| Traza SIP | `pjsip set logger on|off|host <ip>|method INVITE`, `pjsip set history on` + `pjsip show history` |
| RTP | `rtp set debug on [ip <ip>]`, `rtcp set debug on`, `rtp set stats on` |
| Verbosidad/depuración | `core set verbose 5`, `core set debug 5 [módulo]`, `core set debug channel <canal>` |
| Ayuda | `core show help <prefijo>`, `core show application Dial`, `core show function CALLERID`, `config show help res_pjsip endpoint`, `manager show command Originate`, `agi show commands` |
| Base de datos interna | `database show [familia]`, `database put fam clave val`, `database del fam clave` |
| Colas / VM / conf | `queue show [cola]`, `voicemail show users`, `confbridge list` |
| ARI/HTTP | `http show status`, `ari show apps|users|sessions|outbound-websockets` |
| AMI | `manager show connected|users` |
| Parar/reiniciar | `core stop gracefully|when convenient|now`, `core restart gracefully` |
| Codecs / traducción | `core show codecs`, `core show translation` |
| Hints/estado | `core show hints`, `devstate list` |

## 6. Logging

```ini
; logger.conf
[general]
dateformat = %F %T.%3q
use_callids = yes            ; añade [C-0000002a] para seguir una llamada
rotatestrategy = rotate
[logfiles]
console  => notice,warning,error,verbose
messages => notice,warning,error,verbose
security => security         ; para fail2ban
full     => notice,warning,error,debug,verbose,dtmf   ; solo mientras depuras
```
`logger reload`, `logger rotate`, `logger add channel /tmp/debug.log notice,warning,error,debug,verbose` (temporal). Para una llamada concreta: `grep "C-0000002a" /var/log/asterisk/full`.

## 7. Servicio

`make config` instala la unidad. Unit mínima: ver `plantillas.md`. Arranque: `systemctl enable --now asterisk`. Comprueba con `asterisk -rx "core show version"`. Si no arranca: `asterisk -cvvvvvg` en primer plano para ver el error (permisos, módulo, puerto ocupado).

## 8. Rendimiento

- Ancho de banda aprox. por llamada (IP+UDP+RTP, 20 ms): G.711 ≈ 87 kbps; G.722 ≈ 87 kbps; Opus 8–40 kbps según config; G.729 ≈ 31 kbps.
- Transcodificación y grabación consumen CPU; la conmutación sin transcodificar es barata. `direct_media=yes` saca el RTP de Asterisk cuando ambos extremos lo permiten (no con NAT, grabación, DTMF interceptado, ConfBridge, etc.).
- Ajustes: `rtp.conf` rango suficiente (2 puertos por stream), límites de file descriptors (`LimitNOFILE` en systemd), `taskprocessor` (`core show taskprocessors` para detectar colas largas), `pjsip` `threadpool` en `[system]`.
- Prueba carga con SIPp. Monitoriza con `res_prometheus` (`prometheus.conf`, endpoint `/metrics` del servidor HTTP) o AMI/ARI.

## 9. Mantenimiento

- Suscríbete a avisos de seguridad y actualiza dentro de la serie (minor) con frecuencia: `make && make install` sobre la nueva versión, sin `make samples`.
- Backups: `/etc/asterisk`, `/var/lib/asterisk/astdb.sqlite3`, `/var/spool/asterisk/voicemail`, BD de realtime/CDR.
- Crash: `ast_coredumper` (contrib/scripts) genera backtraces para reportar en GitHub issues.
