# Plantillas listas para copiar

Reemplaza IPs de documentación (192.0.2.x, 198.51.100.x, 203.0.113.x), dominios y secretos. Genera contraseñas con `openssl rand -base64 24`.

## Índice
1. PBX básica: pjsip.conf
2. PBX básica: extensions.conf
3. rtp.conf, logger.conf, modules.conf
4. Troncal con el wizard
5. ARI: http.conf + ari.conf
6. App ARI mínima en Python (eventos + REST)
7. Bot de voz: ARI + externalMedia chan_websocket (Python)
8. FastAGI en Python
9. AMI: originar llamada (Python asyncio)
10. systemd
11. Dockerfile + docker-compose
12. Script de compilación no interactivo

## 1. pjsip.conf (oficina tras NAT, troncal con registro)

```ini
[global]
type = global
user_agent = PBX
endpoint_identifier_order = ip,username

[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5060
local_net = 192.0.2.0/24
local_net = 127.0.0.1/32
external_media_address = 198.51.100.5
external_signaling_address = 198.51.100.5

; ---------- Plantillas ----------
[phone](!)
type = endpoint
transport = transport-udp
context = internos
disallow = all
allow = g722,alaw,ulaw
direct_media = no
rtp_symmetric = yes
force_rport = yes
rewrite_contact = yes
language = es
device_state_busy_at = 1
send_pai = yes

[phone-aor](!)
type = aor
max_contacts = 1
remove_existing = yes
qualify_frequency = 30

[phone-auth](!)
type = auth
auth_type = digest

; ---------- Extensiones ----------
[1001](phone)
auth = 1001
aors = 1001
callerid = "Ana" <1001>
mailboxes = 1001@default
[1001](phone-aor)
[1001](phone-auth)
username = u1001-k3x9
password = CAMBIAR_1001

[1002](phone)
context = internos-sin-internacional
auth = 1002
aors = 1002
callerid = "Bruno" <1002>
mailboxes = 1002@default
[1002](phone-aor)
[1002](phone-auth)
username = u1002-p7q2
password = CAMBIAR_1002

; ---------- Troncal ----------
[prov-auth]
type = auth
auth_type = digest
username = 1112223333
password = CAMBIAR_TRONCAL

[prov-reg]
type = registration
transport = transport-udp
outbound_auth = prov-auth
server_uri = sip:sip.proveedor.example
client_uri = sip:1112223333@sip.proveedor.example
contact_user = 1112223333
retry_interval = 60
forbidden_retry_interval = 600
expiration = 3600

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
rtp_symmetric = yes
force_rport = yes

[prov]
type = aor
contact = sip:sip.proveedor.example
qualify_frequency = 30

[prov]
type = identify
endpoint = prov
match = sip.proveedor.example
; match = 203.0.113.0/24
```

## 2. extensions.conf

```ini
[general]
static = yes
writeprotect = yes

[globals]
TRONCAL = prov
DID_PRINCIPAL = 1112223333

; ===== Entrantes: SOLO DIDs =====
[desde-proveedor]
exten => ${DID_PRINCIPAL},1,Goto(ivr,s,1)
exten => _X.,1,NoOp(DID no esperado: ${EXTEN})
 same => n,Hangup(1)

; ===== Internos =====
[internos-base]
exten => _10XX,1,Gosub(sub-interno,s,1(${EXTEN}))
exten => 1001,hint,PJSIP/1001
exten => 1002,hint,PJSIP/1002
exten => *97,1,VoiceMailMain(${CALLERID(num)}@default)
exten => 600,1,Answer()
 same => n,Playback(demo-echotest)
 same => n,Echo()
exten => 700,1,ConfBridge(sala)

[salida-nacional]
; Ajusta a tu plan de numeración nacional
exten => _0NXXXXXXXX.,1,Gosub(sub-saliente,s,1(${EXTEN}))

[salida-internacional]
exten => _00.,1,Authenticate(4872)
 same => n,Gosub(sub-saliente,s,1(${EXTEN}))

[internos]
include => internos-base
include => salida-nacional
include => salida-internacional

[internos-sin-internacional]
include => internos-base
include => salida-nacional

; ===== Subrutinas =====
[sub-interno]
exten => s,1,Dial(PJSIP/${ARG1},20,tT)
 same => n,GotoIf($["${DIALSTATUS}" = "BUSY"]?ocup)
 same => n,VoiceMail(${ARG1}@default,u)
 same => n,Return()
 same => n(ocup),VoiceMail(${ARG1}@default,b)
 same => n,Return()

[sub-saliente]
exten => s,1,Set(NUM=${FILTER(0-9,${ARG1})})
 same => n,Set(GROUP(out)=global)
 same => n,GotoIf($[${GROUP_COUNT(out@global)} > 6]?lleno)
 same => n,Set(CALLERID(num)=${GLOBAL(DID_PRINCIPAL)})
 same => n,Dial(PJSIP/${NUM}@${GLOBAL(TRONCAL)},60,L(3600000))
 same => n,Return()
 same => n(lleno),Playback(all-circuits-busy-now)
 same => n,Return()

; ===== IVR con horario =====
[ivr]
exten => s,1,Answer()
 same => n,Set(CHANNEL(language)=es)
 same => n,GotoIfTime(09:00-18:00,mon-fri,*,*?abierto)
 same => n,Playback(custom/fuera-de-horario)
 same => n,VoiceMail(1001@default,u)
 same => n,Hangup()
 same => n(abierto),Set(TIMEOUT(digit)=3)
 same => n,Set(TIMEOUT(response)=6)
 same => n(menu),Background(custom/menu)
 same => n,WaitExten()
exten => 1,1,Queue(ventas,t,,,300)
 same => n,VoiceMail(1001@default,u)
exten => 2,1,Gosub(sub-interno,s,1(1002))
exten => i,1,Playback(invalid)
 same => n,Goto(s,menu)
exten => t,1,Goto(1,1)
```

## 3. rtp.conf, logger.conf, modules.conf

```ini
; rtp.conf
[general]
rtpstart = 10000
rtpend = 20000
strictrtp = yes
; icesupport = yes
; stunaddr = stun.l.google.com:19302

; logger.conf
[general]
dateformat = %F %T.%3q
use_callids = yes
[logfiles]
console => notice,warning,error,verbose
messages => notice,warning,error,verbose
security => security

; modules.conf
[modules]
autoload = yes
noload = chan_iax2.so
noload = chan_dahdi.so
noload = pbx_dundi.so
noload = chan_unistim.so
noload = chan_mobile.so
noload = res_phoneprov.so
```

## 4. Troncal con el wizard (pjsip_wizard.conf)

```ini
[trunk-tpl](!)
type = wizard
transport = transport-udp
endpoint/allow = !all,alaw,ulaw
endpoint/direct_media = no
endpoint/rtp_symmetric = yes
endpoint/force_rport = yes
aor/qualify_frequency = 30

; Con registro
[prov](trunk-tpl)
sends_auth = yes
sends_registrations = yes
remote_hosts = sip.proveedor.example
endpoint/context = desde-proveedor
outbound_auth/username = 1112223333
outbound_auth/password = CAMBIAR
registration/expiration = 3600

; Autenticado por IP con varios POPs
[prov-ip](trunk-tpl)
remote_hosts = 203.0.113.10,203.0.113.20
endpoint/context = desde-proveedor

; Teléfono
[phone-tpl](!)
type = wizard
transport = transport-udp
accepts_registrations = yes
accepts_auth = yes
has_hint = yes
hint_context = internos
endpoint/context = internos
endpoint/allow = !all,g722,ulaw
endpoint/rewrite_contact = yes
endpoint/rtp_symmetric = yes
aor/max_contacts = 1
aor/remove_existing = yes
aor/qualify_frequency = 30

[1003](phone-tpl)
hint_exten = 1003
inbound_auth/username = u1003-z8
inbound_auth/password = CAMBIAR
```

## 5. ARI: http.conf + ari.conf

```ini
; http.conf
[general]
enabled = yes
bindaddr = 127.0.0.1
bindport = 8088

; ari.conf
[general]
enabled = yes
pretty = no
[bot]
type = user
read_only = no
password = CAMBIAR_ARI
password_format = plain

; extensions.conf
[desde-proveedor]
exten => 1112223334,1,Stasis(bot,${EXTEN})
 same => n,Hangup()
```

## 6. App ARI mínima (Python, `pip install websockets httpx`)

```python
import asyncio, json, httpx, websockets

ARI = "http://127.0.0.1:8088/ari"
USER, PWD, APP = "bot", "CAMBIAR_ARI", "bot"

async def main():
    async with httpx.AsyncClient(base_url=ARI, auth=(USER, PWD), timeout=10) as http:
        url = f"ws://127.0.0.1:8088/ari/events?app={APP}&api_key={USER}:{PWD}"
        async with websockets.connect(url) as ws:
            async for raw in ws:
                ev = json.loads(raw)
                if ev["type"] == "StasisStart":
                    ch = ev["channel"]["id"]
                    await http.post(f"/channels/{ch}/answer")
                    await http.post(f"/channels/{ch}/play", params={"media": "sound:hello-world"})
                elif ev["type"] == "PlaybackFinished":
                    ch = ev["playback"]["target_uri"].split(":", 1)[1]
                    await http.delete(f"/channels/{ch}")
                elif ev["type"] == "ChannelDtmfReceived":
                    print("DTMF", ev["digit"])

asyncio.run(main())
```

## 7. Bot de voz: ARI + externalMedia sobre chan_websocket (Asterisk 22.8+/23.2+ por formato JSON)

Asterisk como servidor de media (tu app conecta a `/media/<id>`); usa el servidor HTTP de Asterisk (http.conf).

```python
# pip install "websockets>=14" httpx
import asyncio, base64, json, httpx, websockets

HOST = "127.0.0.1:8088"; USER, PWD, APP = "bot", "CAMBIAR_ARI", "bot"
FRAME = 640  # slin16, 20 ms
AUTH = {"Authorization": "Basic " + base64.b64encode(f"{USER}:{PWD}".encode()).decode()}

async def media_session(conn_id: str):
    # websockets>=14 usa additional_headers (versiones viejas: extra_headers)
    async with websockets.connect(f"ws://{HOST}/media/{conn_id}", additional_headers=AUTH) as ws:
        async for msg in ws:
            if isinstance(msg, bytes):
                pass  # audio del llamante (slin16) -> enviar a STT
            else:
                ev = json.loads(msg)
                if ev.get("event") == "MEDIA_START":
                    # ejemplo: reproducir audio TTS (bytes slin16) con buffering
                    tts = b"\x00" * FRAME * 50   # 1 s de silencio como placeholder
                    await ws.send(json.dumps({"command": "START_MEDIA_BUFFERING"}))
                    for i in range(0, len(tts), 32000):
                        await ws.send(tts[i:i+32000])          # BINARY, <65500 bytes
                    await ws.send(json.dumps({"command": "STOP_MEDIA_BUFFERING", "correlation_id": "saludo"}))
                elif ev.get("event") == "MEDIA_XOFF":
                    pass  # pausar envío hasta MEDIA_XON
                # barge-in: await ws.send(json.dumps({"command": "FLUSH_MEDIA"}))

async def main():
    async with httpx.AsyncClient(base_url=f"http://{HOST}/ari", auth=(USER, PWD)) as http:
        async with websockets.connect(f"ws://{HOST}/ari/events?app={APP}&api_key={USER}:{PWD}") as ev_ws:
            async for raw in ev_ws:
                ev = json.loads(raw)
                if ev["type"] != "StasisStart" or ev["channel"]["name"].startswith("WebSocket/"):
                    continue
                caller = ev["channel"]["id"]
                await http.post(f"/channels/{caller}/answer")
                bridge = (await http.post("/bridges", params={"type": "mixing"})).json()["id"]
                em = (await http.post("/channels/externalMedia", params={
                    "app": APP, "transport": "websocket", "encapsulation": "none",
                    "external_host": "INCOMING", "connection_type": "server",
                    "format": "slin16", "transport_data": "f(json)"})).json()
                await http.post(f"/bridges/{bridge}/addChannel", params={"channel": f"{caller},{em['id']}"})
                conn_id = (await http.get(f"/channels/{em['id']}/variable",
                                          params={"variable": "MEDIA_WEBSOCKET_CONNECTION_ID"})).json()["value"]
                asyncio.create_task(media_session(conn_id))

asyncio.run(main())
```
Notas: la autenticación del WS `/media` usa el usuario ARI/HTTP (verifica en tu versión; los ejemplos oficiales en `github.com/asterisk/asterisk-websocket-examples` son la referencia). En producción gestiona `StasisEnd`, cuelga el canal externo y destruye el bridge, y respeta XON/XOFF.

## 8. FastAGI (Python, sin dependencias)

```python
import socketserver

class AGI(socketserver.StreamRequestHandler):
    def cmd(self, c):
        self.wfile.write((c + "\n").encode()); self.wfile.flush()
        return self.rfile.readline().decode().strip()
    def handle(self):
        env = {}
        while (line := self.rfile.readline().decode().strip()):
            k, v = line.split(": ", 1); env[k] = v
        num = env.get("agi_callerid", "")
        destino = "1001" if num.startswith("11") else "1002"   # consulta tu CRM aquí
        self.cmd(f'SET VARIABLE DESTINO "{destino}"')

socketserver.ThreadingTCPServer.allow_reuse_address = True
socketserver.ThreadingTCPServer(("0.0.0.0", 4573), AGI).serve_forever()
```
Dialplan: `same => n,AGI(agi://10.0.0.5:4573/ruteo)` y luego `same => n,Gosub(sub-interno,s,1(${DESTINO}))`.

## 9. AMI: originar (Python, `pip install panoramisk`)

```python
import asyncio
from panoramisk import Manager

async def main():
    m = Manager(host="127.0.0.1", port=5038, username="crm", secret="CAMBIAR")
    await m.connect()
    r = await m.send_action({"Action": "Originate", "Channel": "PJSIP/1001",
                             "Context": "internos", "Exten": "1002", "Priority": "1",
                             "CallerID": "Click2Call <1001>", "Async": "true"})
    print(r)
    m.close()
asyncio.run(main())
```

## 10. systemd

```ini
# /etc/systemd/system/asterisk.service
[Unit]
Description=Asterisk PBX
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=asterisk
Group=asterisk
ExecStart=/usr/sbin/asterisk -mqf -C /etc/asterisk/asterisk.conf
ExecReload=/usr/sbin/asterisk -rx 'core reload'
ExecStop=/usr/sbin/asterisk -rx 'core stop gracefully'
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
LimitCORE=infinity
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
```

## 11. Dockerfile + compose

```dockerfile
FROM debian:bookworm-slim AS build
ARG AST_VER=22-current
RUN apt-get update && apt-get install -y wget build-essential ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /usr/src
RUN wget -q https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${AST_VER}.tar.gz \
 && tar xzf asterisk-*.tar.gz && rm asterisk-*.tar.gz && mv asterisk-* asterisk
WORKDIR /usr/src/asterisk
RUN yes | contrib/scripts/install_prereq install \
 && ./configure --with-jansson-bundled \
 && make menuselect.makeopts \
 && menuselect/menuselect --disable BUILD_NATIVE --enable codec_opus \
      --enable CORE-SOUNDS-ES-ULAW --disable chan_dahdi menuselect.makeopts \
 && make -j"$(nproc)" && make install && make samples && ldconfig

FROM build AS runtime
RUN useradd -r -d /var/lib/asterisk asterisk \
 && chown -R asterisk: /etc/asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk /var/run/asterisk
USER asterisk
CMD ["/usr/sbin/asterisk", "-fp"]
```
(Para imagen pequeña, copia solo `/usr/sbin/asterisk`, `/usr/lib/asterisk`, `/var/lib/asterisk` y librerías a una etapa runtime; requiere instalar las dependencias runtime.)

```yaml
# docker-compose.yml
services:
  asterisk:
    build: .
    network_mode: host          # RTP: evita publicar miles de puertos
    restart: unless-stopped
    volumes:
      - ./etc:/etc/asterisk
      - ast-lib:/var/lib/asterisk
      - ast-spool:/var/spool/asterisk
      - ./logs:/var/log/asterisk
volumes: { ast-lib: {}, ast-spool: {} }
```

## 12. Compilación no interactiva (host)

```bash
#!/usr/bin/env bash
set -euo pipefail
VER=${1:-22-current}
cd /usr/src
wget -q "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${VER}.tar.gz"
tar xzf "asterisk-${VER}.tar.gz"; cd asterisk-*/
yes | contrib/scripts/install_prereq install
./configure --with-jansson-bundled
make menuselect.makeopts
menuselect/menuselect --enable codec_opus --enable CORE-SOUNDS-ES-ULAW --enable CORE-SOUNDS-ES-G722 menuselect.makeopts
make -j"$(nproc)"; make install; make config; make install-logrotate; ldconfig
id asterisk &>/dev/null || useradd -r -d /var/lib/asterisk asterisk
chown -R asterisk: /etc/asterisk /var/{lib,log,spool,run}/asterisk
echo "Ahora: make samples (solo instalación nueva) o copia tu configuración."
```
