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
4. correr el bootstrap de este repo
5. iniciar sesión y volver a registrar los servidores MCP
6. borrar los directorios .pi/ de cada proyecto
7. verificar
```

No inviertas 1 y 2: el instalador empaquetado es autocontenido y no necesita
Pi, y una instalación limpia no tiene nada que importar.

---

## Leé esto antes del paso 1: Engram

El store de memoria **no** vive bajo `~/.pi`:

| Ruta | Qué es | ¿Se conserva? |
|---|---|---|
| `~/.engram/engram.db` | el store de memoria (25 MB + WAL) | **sí** |
| `~/.local/bin/engram` | tu binario de Engram 3.6.0 | **sí** |
| `~/.agents/skills/` | los skills de agente | **sí** |
| `~/.gentle-ai/`, `~/.local/bin/gentle-ai` | el CLI de Gentle AI y su estado | **sí** |

El paso 1 no toca nada de eso. Pero hay un detalle de versiones que conviene
conocer:

- tu Engram es **3.6.0**; el core de Engram que empaqueta Gentle Shell es más
  viejo (**3.5.2** en el layout actual);
- cuando el store fue migrado por un Engram más nuevo que el core del shell,
  el shell se niega a levantar un servidor sobre él y avisa: *"Engram memory
  disabled: `~/.engram` was migrated by a newer Engram than Shell's bundled
  core"*;
- la salida es levantar tu propio servidor y dejar que el shell lo reutilice:

  ```sh
  engram serve &
  ```

  El shell verifica el endpoint `/compatibility` del servidor antes de usarlo
  (Engram ≥ 3.4.0 lo responde, así que 3.6.0 sirve). La alternativa del
  bundle es `gentle-shell memory migrate --confirm-quiescent`, que exige que
  ningún cliente de Engram esté corriendo.

**No borres `~/.local/bin/engram`.** `purge-pi-opencode-gentle.sh` lo borra
(junto con `~/.agents`, que es donde viven tus skills): eso es un bug de ese
script, no parte de esta migración.

---

## Paso 1 — Quitar Pi y su estado

```sh
# 1. el paquete global de Pi
pnpm remove -g @earendil-works/pi-coding-agent

# 2. (opcional) guardar las credenciales de la cuenta de Google para no
#    volver a iniciar sesión en el paso 5. Omití esta línea si preferís
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

## Paso 4 — Instalar el bundle de este proyecto

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
| las reglas de web-design horneadas y el snapshot de docs de Next.js | `~/.agents/skills/` |

*Resultado esperado:* un `✓` por cada ítem y después `✓ Done. Open
gentle-shell to use it.`

## Paso 5 — Iniciar sesión y volver a registrar los servidores MCP

Una instalación limpia no tiene credenciales ni configuración MCP: ambos
vivían bajo `~/.pi/agent/`.

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

Pi lee `<agent home>/mcp.json`; no existe un comando `pi mcp add`, así que se
escribe el archivo:

```sh
cat > ~/.gentle-shell/agent/mcp.json <<'JSON'
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "--package=@upstash/context7-mcp@2.2.5", "--", "context7-mcp"]
    },
    "pencil": {
      "command": "/home/lucas/.local/opt/pen/mcp/mcp-server-linux-x64",
      "args": ["--app", "desktop"],
      "description": "Pen (pen.dev) design canvas: inspect and edit .pen documents in the running Pen desktop app."
    }
  }
}
JSON
```

*Resultado esperado:* la próxima sesión lista los dos servidores; en
`gentle-shell`, el panel de MCP los muestra conectados.

## Paso 6 — Borrar los directorios `.pi/` de cada proyecto

Un `.pi/` de proyecto es la **configuración de proyecto** de Pi (overrides de
modelo/agente por proyecto, servidores MCP, skills, extensiones, persona). Pi
la lee desde el directorio de trabajo, así que sigue funcionando bajo Gentle
Shell: borrarla es una limpieza deliberada, no una reparación.

```sh
# verlos primero
find ~/Documentos -maxdepth 6 -type d -name ".pi" -not -path "*/node_modules/*"
```

Borrá los que git no trackea:

```sh
find ~/Documentos -maxdepth 6 -type d -name ".pi" -not -path "*/node_modules/*" -print0 |
while IFS= read -r -d $'\0' d; do
  repo="${d%/.pi}"
  if git -C "$repo" ls-files --error-unmatch .pi >/dev/null 2>&1; then
    printf 'trackeado — borralo en ese repo: %s\n' "$d"
  else
    rm -rf "$d"
    printf 'borrado: %s\n' "$d"
  fi
done
```

Los trackeados necesitan un commit en su propio repo — un comando cada uno:

```sh
cd ~/Documentos/Workspace/NextJs/JulsGYM           && git rm -r .pi && git commit -m "chore: drop pi project config"
cd ~/Documentos/Workspace/Astro/rol-data           && git rm -r .pi && git commit -m "chore: drop pi project config"
cd ~/Documentos/Workspace/dotfile                  && git rm -r .pi && git commit -m "chore: drop pi project config"
cd ~/Documentos/Workspace/Facultad/TP-especial-SO  && git rm -r .pi && git commit -m "chore: drop pi project config"
cd "$HOME/Documentos/Facultad/Fundamento de Lenguajes Formales" && git rm -r .pi && git commit -m "chore: drop pi project config"
```

> Leé cada uno antes de borrarlo: `dotfile` y `TP-especial-SO` tienen tus
> overrides de MiniMax M2.7 por agente, `JulsGYM` un servidor MCP de proyecto
> y `rol-data` una extensión de proyecto. Si querés conservar alguno, no
> corras su comando.

## Paso 7 — Verificar

```sh
# el runtime y su home
gentle-shell --version

# el home tiene los paquetes y el config home tiene los perfiles
ls ~/.gentle-shell/agent/settings.json
ls ~/.gentle-shell/config/gentle-ai/profiles.json 2>/dev/null || ls ~/.gentle-shell/gentle-ai/profiles.json

# Pi realmente no está
command -v pi || echo "pi: no está"
ls ~/.pi 2>/dev/null || echo "~/.pi: no está"

# el store de memoria sobrevivió
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

Los pasos 1 y 6 son los únicos destructivos, y son justamente el objetivo de
una instalación limpia. Si la instalación nueva se porta mal, Pi está a un
comando de distancia:

```sh
pnpm add -g @earendil-works/pi-coding-agent
```

El store de Engram, los skills y el estado de Gentle AI nunca se tocaron.

## Troubleshooting

- **`gentle-shell: No pi runtime could be found`** — una instalación
  empaquetada trae su propio Pi; si instalaste la standalone, Pi tiene que
  estar en el PATH.
- **`gentle-shell install` no hace nada** — el home nunca fue provisionado:
  corré `gentle-shell setup`.
- **El agente usa el modelo equivocado** — `gentle-ai/profiles.json` no
  aterrizó en el config home; volvé a correr el paso 4.
- **Faltan las tools de memoria** — mirá la nota de Engram al principio de
  este archivo: el store está bien, lo que falla es el servidor.
- **`purge-pi-opencode-gentle.sh` borra `~/.agents` y
  `~/.local/bin/engram`** — eliminaría todos los skills de agente y la
  capacidad de servir un store de Engram con schema más nuevo. Sacá esas
  rutas del script antes de correrlo.
