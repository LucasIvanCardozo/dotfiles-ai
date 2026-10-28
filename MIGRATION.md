# Migración: Pi → Gentle Shell (instalación limpia)

El estado objetivo: **Pi desaparece**, Gentle Shell queda como único runtime del
agente y el bundle de este repo se instala encima. Todo lo de la instalación
anterior de Pi se descarta — el historial de chats incluido — porque la
memoria que importa ya vive en Engram.

El orden importa:

```
1. quitar Pi y su estado
2. instalar Gentle Shell (como recomienda su propio repo)
3. provisionar el home
4. entregar la memoria al core de Gentle Shell
5. correr el bootstrap de este proyecto
6. iniciar sesión y volver a registrar los servidores MCP
7. borrar los directorios .pi/ de cada proyecto
8. verificar
```

No inviertas 1 y 2: el instalador empaquetado es autocontenido y no necesita
Pi, y una instalación limpia no tiene nada que importar.

---

## Leé esto antes del paso 1: Engram

Tu memoria vive en `~/.engram/engram.db` y hoy la sirve el binario standalone
`~/.local/bin/engram` (Engram **3.6.0**), que instalaste a mano. Gentle Shell
trae su propio core de Engram (**3.5.2**) y, como abre el store por defecto
(`~/.engram`), **sirve tu memoria sin migración**: el schema del store
(`user_version` 1) es el que espera el core empaquetado, así que no hay
choque de versiones.

El comando `gentle-shell memory migrate --confirm-quiescent` (paso 4) es la
vía de **recuperación** para stores que *provisionó el propio Shell*: esos
dejan un recibo en `~/.gentle-shell/config/engram-provenance.json` y el
comando copia el directorio, migra **solo la copia**, la promociona y renombra
el original como backup (`backup_dir`). Tu store lo creó el Engram standalone
que instalaste a mano, así que **no hay recibo y no hay nada que migrar**: el
comando aborta con

```
gentle-shell: memory migration failed: ENOENT: no such file or directory,
lstat '/home/lucas/.gentle-shell/config/engram-provenance.json'.
```

Eso es un refusal, no una falla: aborta antes de tocar nada (no deja marker,
ni copia, ni promoción). El paso 4 te dice cómo decidir.

**El orden sigue siendo obligatorio: verificar PRIMERO, sacar el binario viejo
DESPUÉS.** El binario 3.6.0 es más nuevo que el core empaquetado: no lo
borres, **archivalo** fuera del PATH (paso 4), así queda como red de seguridad
sin poder levantar un segundo servidor sobre el mismo store.

Lo que se conserva y lo que se va:

| Ruta | Qué es | Qué pasa |
|---|---|---|
| `~/.engram/engram.db` | el store de memoria | **se conserva** (lo sirve el core del shell) |
| `~/.local/bin/engram` | tu Engram 3.6.0 standalone | **sale del PATH** en el paso 4 |
| `~/.local/lib/engram-3.6.0/engram` | el mismo binario, archivado | **se conserva** (respaldo) |
| `~/.engram/*.bak-2026*` | backups viejos de septiembre | se borran (basura) |
| `~/.agents/skills/` | los skills de agente | **se conservan** |
| `~/.gentle-ai/`, `~/.local/bin/gentle-ai` | el CLI de Gentle AI y su estado | **se conservan** |

Los pasos 1 a 3 no tocan nada de eso.

---

## Paso 1 — Quitar Pi y su estado

```sh
# 1. el paquete global de Pi
pnpm remove -g @earendil-works/pi-coding-agent

# 2. (opcional) guardar las credenciales de la cuenta de Google para no
#    volver a iniciar sesión en el paso 6. Omití esta línea si preferís
#    autenticarte desde cero.
mkdir -p ~/.gentle-shell-migration
[ -f ~/.pi/agent/antigravity-accounts.json ] && \
  install -m 600 ~/.pi/agent/antigravity-accounts.json \
    ~/.gentle-shell-migration/antigravity-accounts.json

# 3. el home de Pi: settings, paquetes instalados, extensiones, sesiones y el
#    config home viejo. Esto es toda la instalación.
rm -rf ~/.pi

# 4. cualquier otra cosa que haya dejado Pi
rm -rf ~/.local/share/pi            # solo si existe
rm -rf ~/.config/pi-hashline-edit-pro

# 5. sacar el comando viejo de la caché del shell
hash -r
```

*Resultado esperado:* `command -v pi` no imprime nada y `ls ~/.pi` falla.

> Las sesiones (el historial de chats) se van con `~/.pi`. La memoria no:
> ese es el store de Engram en `~/.engram`.

## Paso 2 — Instalar Gentle Shell

Su repo recomienda el instalador del release: descarga un bundle verificado,
chequea el checksum y abre un wizard en el navegador que instala el producto
autocontenido (su propio Node, npm, pnpm y Pi dentro de `~/.gentle-shell/`,
sin tocar tu propio toolchain).

```sh
cd /tmp

# 1. el bundle del release y su archivo de checksum
curl -fLO https://github.com/Gentleman-Programming/gentle-shell/releases/latest/download/gentle-shell-installer-linux.tar.gz
curl -fLO https://github.com/Gentleman-Programming/gentle-shell/releases/latest/download/gentle-shell-installers-SHA256SUMS.txt

# 2. verificar antes de ejecutar
sha256sum -c --ignore-missing gentle-shell-installers-SHA256SUMS.txt

# 3. descomprimir e instalar (abre el wizard en el navegador)
tar -xzf gentle-shell-installer-linux.tar.gz
sh gentle-shell-installer/install-gentle-shell.sh
```

*Resultado esperado:* `gentle-shell-installer-linux.tar.gz: OK` y después el
wizard en `http://127.0.0.1:<puerto>`. Terminalo ahí: instala el producto
empaquetado y agrega `~/.gentle-shell/bin/gentle-shell` a tu PATH.

## Paso 3 — Provisionar el home

```sh
# el launcher ya está en el PATH; abrí una terminal nueva si esta está vieja
export PATH="$HOME/.gentle-shell/bin:$PATH"

# qué está corriendo y qué home usa
gentle-shell --version

# provisionar el home: corre `gentle-ai install --agent pi --scope global`
# contra el home aislado, que instala gentle-pi, gentle-engram,
# pi-web-access y pi-btw
gentle-shell setup
```

*Resultado esperado:* `home isolated ~/.gentle-shell/agent` y al final el
resultado de la instalación de Gentle AI.

> `setup` es obligatorio antes de instalar paquetes: el launcher saltea su
> auto-provisionado cuando el comando es un subcomando de Pi (tiene que dejar
> `argv[0]` intacto para que Pi pueda despachar `install`).

## Paso 4 — Entregar la memoria al core de Gentle Shell

A partir de acá queda **un solo Engram**: el del shell.

### 1. Decidir si hay algo que migrar

```sh
ls ~/.gentle-shell/config/engram-provenance.json 2>/dev/null \
  && echo "el store lo provisionó el Shell: hay migración" \
  || echo "no hay recibo: el store es de tu Engram standalone, no se migra"
```

- **Si aparece el recibo** (store provisionado por el Shell): corré la
  migración del punto 2.
- **Si no aparece** (tu caso: el store lo creó el Engram 3.6.0 que instalaste
  a mano): **no hay nada que migrar**. El core empaquetado abre `~/.engram`
  por defecto y sirve tu memoria tal cual. `memory migrate` no aplica y
  aborta con un `ENOENT` sobre el recibo — eso es un refusal, no una falla:
  no toca nada.

### 2. (solo con recibo) migrar el store

```sh
# 1. parar el servidor de Engram actual: está escribiendo el store
pkill -f "engram serve"
sleep 1
pgrep -af engram          # no debería quedar ningún servidor

# 2. migrar el store al core empaquetado (copia, migra solo la copia,
#    la promociona y renombra el original como backup)
gentle-shell memory migrate --confirm-quiescent
```

*Resultado esperado:* un JSON con `status: "migrated"`, `instance_id` y
`backup_dir`. **Anotá el `backup_dir`.**

> La confirmación (`--confirm-quiescent`) es una aserción tuya, no un lock:
> el store tiene que estar quieto de verdad. Nunca corras esto con otro
> cliente de Engram usando el store.

### 3. Verificar antes de tocar nada

```sh
gentle-shell
```

Dentro de la sesión: confirmá que las tools de memoria están registradas
(`mem_search`, `mem_save`) y que un `mem_search` devuelve tus registros. Recién
después seguí.

### 4. Sacar el Engram viejo del PATH (archivado, no borrado)

```sh
# 1. backup fresco del store, por si acaso
pkill -f "engram serve"; sleep 1
cp -a ~/.engram ~/.engram.bak-$(date +%F)

# 2. el binario standalone 3.6.0 (22 MB) sale del PATH pero se conserva:
#    es MÁS NUEVO que el core empaquetado, así que queda como red de
#    seguridad. Borrarlo sería tirar lo único capaz de reparar el store.
mkdir -p ~/.local/lib/engram-3.6.0
mv ~/.local/bin/engram ~/.local/lib/engram-3.6.0/engram
hash -r

# 3. los backups viejos de septiembre dentro del store
rm -f ~/.engram/engram.db.bak-* ~/.engram/engram.db-shm.bak-* ~/.engram/engram.db-wal.bak-*
```

*Resultado esperado:* `command -v engram` no encuentra nada,
`~/.gentle-shell/runtime/` tiene el core del shell y
`~/.local/lib/engram-3.6.0/engram` sigue ahí.

> Por qué archivado y no borrado: dos Engram sobre el mismo store es el peor
> escenario (dos servidores escribiendo el mismo `engram.db`). Sacándolo del
> PATH te queda uno solo sirviendo, y el 3.6.0 queda disponible a mano si
> algún día hace falta.

> No definas `ENGRAM_BIN`, `ENGRAM_URL` ni `ENGRAM_DATA_DIR` a mano: una
> selección explícita de esas variables **desactiva** la memoria empaquetada
> (el shell no sondea ni arranca nada en ese caso).

## Paso 5 — Instalar el bundle de este proyecto

> **En esta máquina ya está aplicado**: el bundle quedó instalado (paquetes,
> skills, configs, reglas horneadas, docs de Next.js y los MCP declarados).
> Volver a correrlo es idempotente y refresca todo a upstream HEAD, pero
> **no hace falta**: si no lo querés repetir, saltá este paso y seguí con el
> 6. En una máquina nueva, corrélo.

```sh
cd ~/Documentos/Workspace/dotfiles-ai
./bootstrap.sh
```

Qué instala, todo dentro del home nuevo:

| Qué | Dónde |
|---|---|
| `pi-antigravity` (tu provider), `diagram-design`, `pi-codegraph-enhanced` | `~/.gentle-shell/agent/npm/` |
| los 21 skills de agente de upstream + los 5 locales | `~/.agents/skills/` |
| el CLI `agent-browser` | tu npm global |
| `gentle-ai/profiles.json` (Full-Code / Chill-Code / Boludear) | el config home de Gentle Shell |
| los servidores MCP declarados (`pencil`) | `<agent home>/mcp.json` |
| las reglas de web-design horneadas y el snapshot de docs de Next.js | `~/.agents/skills/` |

*Resultado esperado:* un `✓` por cada ítem y después `✓ Done. Open
gentle-shell to use it.`

## Paso 6 — Iniciar sesión y volver a registrar los servidores MCP

Una instalación limpia no tiene credenciales: la sign-in vivía bajo
`~/.pi/agent/`. Los servidores MCP, en cambio, los declara el bundle (paso 5)
o se registran a mano con `gentle-shell mcp add` (abajo).

### Iniciar sesión

O te autenticás desde cero:

```sh
gentle-shell
# dentro de la sesión: /login  → elegí el provider Antigravity e iniciá sesión
```

O reutilizás la cuenta guardada en el paso 1:

```sh
install -m 600 ~/.gentle-shell-migration/antigravity-accounts.json \
  ~/.gentle-shell/agent/antigravity-accounts.json
```

### Servidores MCP

El MCP se configura con el comando de Pi, que el shell expone:

```sh
gentle-shell mcp list                    # qué hay configurado
gentle-shell mcp add <nombre> [opciones] -- <comando> [args...]
gentle-shell mcp remove <nombre>
gentle-shell mcp login <nombre>          # OAuth, por navegador
```

El archivo que escribe es `<agent home>/mcp.json` (en el home aislado:
`~/.gentle-shell/agent/mcp.json`). **No lo edites a mano**: `mcp add` valida
la entrada y mantiene el formato que Pi escribe.

> Ojo con el orden: todo lo que va después del `--` es el comando del
> servidor. Las opciones de Pi (`--exposure`, `--description`, `--url`,
> `--env`, `--cwd`) van **antes** del `--`; si van después, el servidor las
> recibe y muere con `flag provided but not defined`.

En esta máquina:

```sh
# pencil: lo instala el bundle (declarado en install-mcp-servers.sh, paso 5)
gentle-shell mcp list
# → pencil: connected (direct, global)

# context7: opcional, no quedó instalado
# gentle-shell mcp add context7 --exposure direct \
#   -- npx -y --package=@upstash/context7-mcp@2.2.5 -- context7-mcp
```

Sobre `--exposure`: `direct` declara las tools del servidor al modelo como
tools normales (es lo que quiere el skill `pen-dev`); `codemode` (el default
de Pi) las deja solo alcanzables desde un script JS; `deferred` las declara
recién cuando `tool_search` las trae.

*Resultado esperado:* la próxima sesión lista los servidores; en
`gentle-shell`, el panel de MCP los muestra conectados.

## Paso 7 — Borrar los directorios `.pi/` de cada proyecto

Un `.pi/` de proyecto es la **configuración de proyecto** de Pi (overrides de
modelo/agente por proyecto, servidores MCP, skills, extensiones, persona). Pi
la lee desde el directorio de trabajo, así que sigue funcionando bajo Gentle
Shell: borrarla es una limpieza deliberada, no una reparación.

**Regla de este paso: los servidores MCP del proyecto se conservan.** Un
`.pi/mcp.json` registra servidores que el proyecto necesita, así que su
`.pi/` no se borra entero: se borra todo su contenido **menos** el
`mcp.json`. La única excepción es el de `photocraft`, que sí se borra.

| Proyecto | MCP | Qué pasa |
|---|---|---|
| `NextJs/JulsGYM` | `motion` (HTTP) | **se conserva** el `mcp.json`; el resto del `.pi/` va |
| `IA/chat` | `photocraft` (stdio) | **se borra** el `mcp.json` (y con él, el `.pi/`) |

```sh
# verlos primero
find ~/Documentos -maxdepth 6 -type d -name ".pi" -not -path "*/node_modules/*"
```

Borrar la config de Pi de cada proyecto, conservando los MCP del proyecto:

```sh
find ~/Documentos -maxdepth 6 -type d -name ".pi" -not -path "*/node_modules/*" -print0 |
while IFS= read -r -d $'\0' d; do
  repo="${d%/.pi}"
  if [[ -f "$d/mcp.json" && "$repo" == *"/IA/chat" ]]; then
    # excepción: el MCP de photocraft sí se borra
    rm -rf "$d"
    printf 'borrado (con su MCP): %s\n' "$d"
  elif [[ -f "$d/mcp.json" ]]; then
    # conserva el mcp.json del proyecto; borra el resto de la config de Pi
    find "$d" -mindepth 1 -maxdepth 1 ! -name mcp.json -exec rm -rf {} +
    printf 'conservado (solo mcp.json): %s\n' "$d"
  elif git -C "$repo" ls-files --error-unmatch .pi >/dev/null 2>&1; then
    printf 'trackeado — borralo en ese repo: %s\n' "$d"
  else
    rm -rf "$d"
    printf 'borrado: %s\n' "$d"
  fi
done
```

Los trackeados necesitan un commit en su propio repo — un comando cada uno
(los que no tienen `mcp.json`):

```sh
cd ~/Documentos/Workspace/Astro/rol-data           && git rm -r .pi && git commit -m "chore: drop pi project config"
cd ~/Documentos/Workspace/dotfile                  && git rm -r .pi && git commit -m "chore: drop pi project config"
cd ~/Documentos/Workspace/Facultad/TP-especial-SO  && git rm -r .pi && git commit -m "chore: drop pi project config"
cd "$HOME/Documentos/Facultad/Fundamento de Lenguajes Formales" && git rm -r .pi && git commit -m "chore: drop pi project config"
```

`JulsGYM` **no** entra en esa lista: su `.pi/mcp.json` (el servidor `motion`)
se queda. Si algún día querés sacarlo, borrá ese archivo y el `.pi/` queda
vacío.

> Leé cada uno antes de borrarlo: `dotfile` y `TP-especial-SO` tienen tus
> overrides de MiniMax M2.7 por agente y `rol-data` una extensión de proyecto.
> Si querés conservar alguno, no corras su comando.

## Paso 8 — Verificar

```sh
# el runtime y su home
gentle-shell --version

# el home tiene los paquetes y el config home tiene los perfiles
ls ~/.gentle-shell/agent/settings.json
ls ~/.gentle-shell/config/gentle-ai/profiles.json 2>/dev/null || ls ~/.gentle-shell/gentle-ai/profiles.json

# Pi realmente no está
command -v pi || echo "pi: no está"
ls ~/.pi 2>/dev/null || echo "~/.pi: no está"

# Engram: un solo core, el del shell
command -v engram || echo "engram global: no está (va bien)"
ls ~/.gentle-shell/runtime/ | grep -i engram
ls ~/.local/lib/engram-3.6.0/engram 2>/dev/null && echo "el 3.6.0 quedó archivado (va bien)"

# el store de memoria sobrevivió y lo sirve el shell
ls -la ~/.engram/engram.db

# el switch de review sigue apagado a nivel de clon
gentle-ai review mode status
```

Después arrancá una sesión y probala de punta a punta:

```sh
cd ~/Documentos/Workspace/dotfiles-ai
gentle-shell
```

Dentro de la sesión: los skills cargan (`/skill-registry:refresh` los lista),
las tools de memoria responden, las tools de web responden y el routing de
modelos de los agentes coincide con el perfil que tenías.

---

## Rollback

Los pasos 1, 4 y 7 son los que borran algo, y son justamente el objetivo de
una instalación limpia. Si la instalación nueva se porta mal, Pi está a un
comando de distancia:

```sh
pnpm add -g @earendil-works/pi-coding-agent
```

Para la memoria, el backup del store que hiciste en el paso 4
(`~/.engram.bak-<fecha>`, o el `backup_dir` de una migración real) sigue ahí
hasta que lo borres a propósito: si algo salió mal, se puede restaurar.

## Troubleshooting

- **`gentle-shell: No pi runtime could be found`** — una instalación
  empaquetada trae su propio Pi; si instalaste la standalone, Pi tiene que
  estar en el PATH.
- **`gentle-shell install` no hace nada** — el home nunca fue provisionado:
  corré `gentle-shell setup`.
- **`memory migrate` falla con `ENOENT` sobre `engram-provenance.json`** — tu
  store lo creó el Engram standalone que instalaste a mano, no el Shell: no
  hay recibo y no hay nada que migrar. El comando aborta sin tocar nada. La
  memoria funciona igual (el core empaquetado abre `~/.engram` por defecto).
  Seguí el paso 4: archivá el binario viejo y seguí.
- **La memoria dice "disabled" en cada arranque** — no definas `ENGRAM_BIN`,
  `ENGRAM_URL` ni `ENGRAM_DATA_DIR` a mano: una selección explícita desactiva
  la memoria empaquetada.
- **El agente usa el modelo equivocado** — `gentle-ai/profiles.json` no
  aterrizó en el config home; volvé a correr el paso 5.
- **`purge-pi-opencode-gentle.sh` borra `~/.agents` y
  `~/.local/bin/engram`** — ese script no es parte de esta migración y
  eliminaría todos los skills de agente. No lo corras.
