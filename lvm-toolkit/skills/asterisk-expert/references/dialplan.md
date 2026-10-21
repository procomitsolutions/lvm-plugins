# Dialplan (extensions.conf)

## Índice
1. Sintaxis y patrones
2. Variables, expresiones y funciones
3. Control de flujo y Gosub
4. Dial: opciones y resultados
5. Entrantes, salientes e IVR
6. Horarios
7. Voicemail
8. Colas (app_queue)
9. Conferencias (ConfBridge)
10. Grabación (MixMonitor)
11. Transferencias, parking, pickup, features
12. Hints y estado
13. Utilidades (AMD, fax, speech, límites)

## 1. Sintaxis y patrones

```ini
[general]
static = yes
writeprotect = yes        ; impide que "dialplan save" sobrescriba el archivo
clearglobalvars = no

[globals]
TRONCAL = prov

[internos]
exten => 1000,1,NoOp(Llamada a ${EXTEN} desde ${CALLERID(all)})
 same => n,Dial(PJSIP/${EXTEN},20)
 same => n,Hangup()
```
- Prioridades: `1`, luego `n`. Etiquetas: `same => n(fin),Hangup()`.
- Patrones (empiezan con `_`): `X`=0-9, `Z`=1-9, `N`=2-9, `[15-7]` rango, `.` = uno o más, `!` = cero o más (marcado inmediato). Ej.: `_9NXXXXXXX`, `_0[67]XXXXXXXX`, `_+.`.
- El patrón más específico gana: `dialplan show 5551234@ctx` muestra cuál coincide.
- Extensiones especiales: `s` (inicio sin número), `i` (inválida), `t` (timeout), `h` (hangup), `e` (excepción), `T` (timeout absoluto).
- `include => otro_contexto` (también con horario), `switch =>` (raro).
- Alternativas: `pbx_lua` (extensions.lua), AEL (`extensions.ael`, poco usado). La mayoría usa extensions.conf + ARI/AGI.

## 2. Variables y funciones

- Canal: `${EXTEN}`, `${CONTEXT}`, `${CHANNEL}`, `${UNIQUEID}`, `${CALLERID(num)}`, `${CALLERID(name)}`, `${DIALSTATUS}`, `${HANGUPCAUSE}`, `${DIALEDTIME}`, `${ANSWEREDTIME}`.
- Subcadenas: `${EXTEN:1}` (quita 1), `${EXTEN:-4}` (últimos 4), `${VAR:2:3}`.
- Herencia: `_VAR` (un nivel), `__VAR` (todos) para pasar al canal llamado.
- Globales: `${GLOBAL(TRONCAL)}`, `Set(GLOBAL(X)=1)`.
- Expresiones: `$[${A} + 1]`, `$[${LEN(${EXTEN})} > 4]`, `$["${X}" = "abc"]`, regex `$["${EXTEN}" =~ "^00"]`.
- Funciones frecuentes: `LEN`, `CUT`, `IF(cond?a:b)`, `REGEX`, `REPLACE`, `FILTER`, `TOUPPER`, `STRFTIME(${EPOCH},,%H%M)`, `RAND`, `DB(fam/clave)`, `DB_EXISTS`, `ODBC_*` (func_odbc.conf), `CURL(url)` (+ `CURLOPT`), `SHELL()` (con entrada saneada; invocarla desde AMI/ARI/AGI exige `live_dangerously=yes`, no lo actives), `DIALPLAN_EXISTS(ctx,exten,1)`, `GROUP()`/`GROUP_COUNT()`, `CHANNEL(...)`, `PJSIP_HEADER`, `CALLERID`, `CONNECTEDLINE`, `DEVICE_STATE`, `EXTENSION_STATE`, `HASH`, `SPRINTF`, `URIENCODE`, `VOLUME(TX)`, `TALK_DETECT`, `TONE_DETECT`, `TIMEOUT(absolute)=3600`.
- **Seguridad**: nunca pases `${EXTEN}`/`${CALLERID}` sin filtrar a `System()`, `SHELL()` o SQL. Usa `FILTER(0-9,${EXTEN})`.

## 3. Control de flujo y Gosub

`Goto(ctx,exten,prio)`, `GotoIf($[cond]?si:no)`, `ExecIf($[cond]?App(args))`, `While/EndWhile/ExitWhile`, `Gosub(ctx,exten,1(arg1,arg2))` con `${ARG1}`, `Return(valor)` → `${GOSUB_RETVAL}`, `LOCAL(x)` para variables locales, `StackPop`.
Hangup handlers: `same => n,Set(CHANNEL(hangup_handler_push)=hh,s,1)` (preferible a `h` para lógica fiable).

## 4. Dial

`Dial(Tecnologia/recurso[&otro],timeout,opciones,URL)`
Opciones clave: `t`/`T` (transferencia ciega/atendida con features.conf), `k`/`K` (parking), `x`/`X` (automixmonitor), `h`/`H` (colgar con *), `g` (seguir dialplan tras colgar el llamado), `m(clase)` (música en vez de tono), `r` (indicar ringing), `L(x:y:z)` (límite de duración), `U(gosub)` (al contestar, en el llamado), `b(ctx^ext^prio)` (pre-dial en cada canal saliente — cabeceras), `B()` (pre-dial en el llamante), `M()` ya **no existe**, `D(dtmf)`, `e` (h ext en el llamado), `i` (ignorar forwards), `o`/`f` caller ID, `j`.
Resultado `${DIALSTATUS}`: ANSWER, BUSY, NOANSWER, CANCEL, CONGESTION, CHANUNAVAIL, DONTCALL, TORTURE, INVALIDARGS.

```ini
[sub-llamar-interno]
exten => s,1,Dial(PJSIP/${ARG1},20,tT)
 same => n,GotoIf($["${DIALSTATUS}" = "BUSY"]?ocupado)
 same => n,VoiceMail(${ARG1}@default,u)
 same => n,Return()
 same => n(ocupado),VoiceMail(${ARG1}@default,b)
 same => n,Return()
```

## 5. Entrantes, salientes e IVR

```ini
[desde-proveedor]                     ; context del endpoint troncal: SOLO DIDs
exten => 541133334444,1,Goto(ivr-principal,s,1)
exten => _X.,1,Hangup()               ; todo lo demás se rechaza

[salidas-nacional]
exten => _0[1-9]XXXXXXXXX,1,Gosub(sub-saliente,s,1(${EXTEN}))   ; ajusta el patrón a tu país
[salidas-internacional]              ; solo se incluye para usuarios autorizados
exten => _00.,1,Gosub(sub-saliente,s,1(${EXTEN}))

[sub-saliente]
exten => s,1,Set(GROUP(salientes)=${CHANNEL(endpoint)})
 same => n,GotoIf($[${GROUP_COUNT(salientes)} > 4]?limite)
 same => n,Set(CALLERID(num)=541133334444)
 same => n,Dial(PJSIP/${ARG1}@${GLOBAL(TRONCAL)},60)
 same => n,Return()
 same => n(limite),Playback(all-circuits-busy-now)
 same => n,Return()

[internos]
include => salidas-nacional
exten => _1XXX,1,Gosub(sub-llamar-interno,s,1(${EXTEN}))
exten => *97,1,VoiceMailMain(${CALLERID(num)}@default)

[ivr-principal]
exten => s,1,Answer()
 same => n,Set(TIMEOUT(digit)=3)
 same => n,Set(TIMEOUT(response)=7)
 same => n(menu),Background(custom/bienvenida)
 same => n,WaitExten(5)
exten => 1,1,Queue(ventas,t,,,300)
exten => 2,1,Gosub(sub-llamar-interno,s,1(1001))
exten => i,1,Playback(invalid)
 same => n,Goto(s,menu)
exten => t,1,Goto(1,1)
```
Read de dígitos: `Read(var,prompt,maxdig,,intentos,timeout)`.

## 6. Horarios

`GotoIfTime(09:00-18:00,mon-fri,*,*?abierto,s,1)`; función `IFTIME`; `include => abierto,09:00-18:00,mon-fri,*,*`. Zona horaria opcional como 5.º argumento. Feriados: lista en `DB` o un contexto con fechas (`*,*,25,dec`).

## 7. Voicemail (voicemail.conf)

```ini
[general]
format = wav49|wav
attach = yes
serveremail = pbx@ejemplo.com
maxsecs = 180
minsecs = 2
[default]
1001 => 4826,Ana Pérez,ana@ejemplo.com,,attach=yes|tz=argentina
```
Apps: `VoiceMail(1001@default,u|b|s)`, `VoiceMailMain`. Email vía `mailcmd` (sendmail/msmtp). Almacenamiento ODBC/IMAP opcional (compilación).

## 8. Colas (queues.conf)

```ini
[general]
persistentmembers = yes
[ventas]
strategy = rrmemory           ; ringall, leastrecent, fewestcalls, random, linear, wrandom
timeout = 15
retry = 5
wrapuptime = 10
maxlen = 20
announce-frequency = 60
announce-position = yes
joinempty = no
leavewhenempty = yes
musicclass = default
member => PJSIP/1001,0,Ana,PJSIP/1001
```
Dialplan: `Queue(ventas,t,,,300)`, `AddQueueMember(ventas,PJSIP/1002)`, `RemoveQueueMember`, `PauseQueueMember(,PJSIP/1001,,almuerzo)`, `UnpauseQueueMember`, función `QUEUE_MEMBER(ventas,logged|free|ready|paused|count)`. Grabar: `monitor-format = wav` en la cola (desde 21 usa MixMonitor; confirma opciones en `queues.conf.sample`) o ejecuta `MixMonitor` antes de `Queue`. CLI `queue show ventas`. Log en `/var/log/asterisk/queue_log` (o realtime).

## 9. ConfBridge (confbridge.conf)

`ConfBridge(sala1,bridge_perfil,usuario_perfil,menu)`. Perfiles: `type=bridge` (`max_members`, `record_conference`, `video_mode=sfu`, `announcements=no` en 24), `type=user` (`admin`, `marked`, `wait_marked`, `pin`, `music_on_hold_when_empty`, `announce_user_count`), `type=menu` (DTMF: `*1=toggle_mute`). CLI: `confbridge list`, `confbridge kick`.

## 10. Grabación

`MixMonitor(${UNIQUEID}.wav,b,/usr/local/bin/post.sh ^{MIXMONITOR_FILENAME})` — `b` graba solo cuando hay bridge; `r()`/`t()` pistas separadas; `W()`/`v()` volumen. Parar: `StopMixMonitor`. Grabación bajo demanda: `Dial(...,x)` + features `automixmon`. Aviso legal de grabación según país.

## 11. Features, transferencias, parking, pickup

- `features.conf`: `[featuremap] blindxfer=##`, `atxfer=*2`, `automixmon=*3`, `disconnect=**`; `[general] transferdigittimeout`, `atxfernoanswertimeout`. Habilitar en Dial con `t/T/x/X/h/H`. Transferencias SIP REFER las maneja PJSIP sin features (`allow_transfer` en endpoint).
- Parking: `res_parking.conf` (`parkext => 700`, `parkpos => 701-720`, `context => parkedcalls`) y `include => parkedcalls`.
- Pickup: `named_call_group`/`named_pickup_group` en endpoints + `*8` (`pickupexten` en features.conf) o `Pickup(1001@internos)`.
- Música en espera: `musiconhold.conf` (`mode=files`, `directory=moh`, `sort=random`).

## 12. Hints y estado

`exten => 1001,hint,PJSIP/1001` (BLF). Estado custom: `exten => 2000,hint,Custom:noche` y `Set(DEVICE_STATE(Custom:noche)=INUSE)` (útil para modo noche con un BLF). `core show hints`.

## 13. Utilidades

- `AMD()` detección de contestador (variables `AMDSTATUS`, `AMDCAUSE`).
- Fax: `ReceiveFAX(/tmp/fax.tif)` / `SendFAX` con `res_fax_spandsp`; T.38 con `t38_udptl=yes` en el endpoint.
- Speech: `SpeechCreate/SpeechBackground` con motores externos (AEAP para STT externo). Para IA moderna, prefiere ARI + chan_websocket.
- Límite de llamadas concurrentes por endpoint: `GROUP()`/`GROUP_COUNT()` o `device_state_busy_at`.
- Call files (`/var/spool/asterisk/outgoing`) para originar sin AMI: crea en tmp y `mv` (operación atómica).
- `Echo()` y `Playback(demo-congrats)` para pruebas de audio; `Milliwatt()` para tono.
