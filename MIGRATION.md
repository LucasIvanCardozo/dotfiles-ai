# MIGRATION.md — reinstalación limpia de Gentle Shell

Qué hace este documento: **borra la instalación actual de Gentle Shell y la
vuelve a poner desde cero**, dejando este repo (`dotfiles-ai`) como única
fuente de verdad. Es el camino que se usa cuando el runtime se rompe, cuando
se quiere empezar de cero, o simplemente para comprobar que la instalación
es reproducible.

> La migración desde Pi ya está hecha: este documento ya no la describe.

## Qué se borra y qué no

| Ruta | Qué es | Qué pasa |
|---|---|---|
| `~/.gentle-shell/` | el runtime (con su Node, npm, pnpm y Engram), el home, los settings, los perfiles | **se borra** |
| `~/.agents/skills/` | los skills que instala el bundle | **se borra** (los reinstala `bootstrap.sh`) |
| `~/.engram/` | tu memoria | **se conserva**: no se toca en ningún paso |
| `~/.gentle-ai/` | el estado del CLI de Gentle AI | **se conserva** |
| `~/.local/bin/gentle-ai` | el CLI de Gentle AI | **se conserva** |
| `~/.local/opt/pen/`, `~/.config/Pen/` | la app de pen.dev | **se conservan** (son por máquina) |
| `~/Documentos/Workspace/dotfiles-ai` | este repo | **se conserva**: es la fuente de verdad |

---

## Paso 1 — Desinstalar Gentle Shell

El launcher trae su propio desinstalador, que sabe qué es suyo:

```sh
# 1. el plan primero: leelo antes de confirmar nada
gentle-shell self-uninstall --dry-run

# 2. desinstalar, incluyendo el home compartido
gentle-shell self-uninstall --yes --include-shared
```

Qué hace:

- **PATH**: saca el launcher del PATH (`~/.local/bin/gentle-shell`, que es un
  symlink a `~/.gentle-shell/bin/gentle-shell`).
- **El runtime**: borra `bin/`, `current`, `versions/`, `runtime/` (el Node,
  npm, pnpm, Go y Engram empaquetados), `pnpm/`, `npm/`, `gentle-ai/`,
  `config/` (los perfiles), `tmp/` y el receipt del PATH.
- **El home compartido** (`--include-shared`): borra `~/.gentle-shell/agent`
  (sign-ins, historial de chats, settings, extensions, `mcp.json`) y
  `config.json`.

**No toca**: `~/.pi/agent`, `~/.pi/gentle-ai`, `~/.gentle-ai` ni `~/.engram`.

Verificación:

```sh
ls ~/.gentle-shell 2>/dev/null || echo "el runtime ya no está"
command -v gentle-shell || echo "el launcher ya no está en el PATH"
```

## Paso 2 — Limpiar lo que dejó el bundle

```sh
# los skills que instala el bundle (los de upstream, los 5 locales y el
# snapshot de docs de Next.js)
rm -rf ~/.agents/skills

# por si quedó algo del runtime
rm -rf ~/.gentle-shell
```

> `~/.agents/skills` es del bundle: `bootstrap.sh` los vuelve a instalar
> idénticos. Si tenés algún skill a mano ahí que no venga del bundle, ese no
> vuelve — copialo antes de borrar.

## Paso 3 — Reinstalar Gentle Shell

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

## Paso 4 — Provisionar el home

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

## Paso 5 — Instalar el bundle

```sh
cd ~/Documentos/Workspace/dotfiles-ai
git pull          # el bundle es la fuente de verdad
./bootstrap.sh
```

Qué instala, todo dentro del home nuevo:

| Qué | Dónde |
|---|---|
| `pi-antigravity` (tu provider), `diagram-design`, `pi-codegraph-enhanced` | `~/.gentle-shell/agent/npm/` |
| los 22 skills de agente de upstream + los 5 locales | `~/.agents/skills/` |
| el CLI `agent-browser` | tu npm global |
| `gentle-ai/profiles.json` (Full-Code / Chill-Code / Boludear) | el config home de Gentle Shell |
| los servidores MCP declarados (`pencil`) | `<agent home>/mcp.json` |
| las reglas de web-design horneadas y el snapshot de docs de Next.js | `~/.agents/skills/` |

*Resultado esperado:* un `✓` por cada ítem y después `✓ Done. Open
gentle-shell to use it.`

> El bundle no maneja los providers con sus claves: eso vive en
> `~/.gentle-shell/agent/models.json`, que es estado local de la máquina. En
> esta máquina no existe (usás la sign-in de Antigravity), pero en otra puede
> existir: si lo tenías, guardalo **antes** del paso 1.

## Paso 6 — Loguearte (el home quedó limpio)

Como el home se borró completo, no quedó ni sign-in ni credenciales:

```sh
gentle-shell
# dentro de la sesión: /login  → elegí el provider Antigravity e iniciá sesión
```

## Paso 7 — Verificar

```sh
# el runtime y su home
gentle-shell --version

# el home tiene los paquetes y el config home tiene los perfiles
ls ~/.gentle-shell/agent/settings.json
ls ~/.gentle-shell/config/gentle-ai/profiles.json 2>/dev/null || ls ~/.gentle-shell/gentle-ai/profiles.json

# el bundle instaló los MCP declarados
gentle-shell mcp list

# Pi realmente no está
command -v pi || echo "pi: no está"
ls ~/.pi 2>/dev/null || echo "~/.pi: no está"

# la memoria sigue ahí, intacta
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

## Notas

- **La memoria no se toca.** `~/.engram` queda como estaba en los pasos 1 y 2:
  el core de Engram del shell abre `~/.engram` por defecto y sigue sirviendo
  tus registros. No hace falta migrar nada.
- **No dejes dos Engram sobre el mismo store.** Si tenés el 3.6.0 standalone
  archivado en `~/.local/lib/engram-3.6.0/engram` (fuera del PATH), dejalo
  ahí: es más nuevo que el core empaquetado y sirve de red de seguridad, pero
  en el PATH levantaría un segundo servidor sobre el mismo `engram.db`.
- **Los `.pi/` de proyecto no se tocan.** Son configuración por proyecto y Pi
  la sigue leyendo bajo Gentle Shell. Si en algún momento querés limpiarlos,
  borralos a mano y conservando el `mcp.json` de cada proyecto (el `motion`
  de `JulsGYM` lo necesita).

## Troubleshooting

- **`gentle-shell self-uninstall` no borra nada** — el plan nombra el motivo:
  o el prefix no es el real (no lo acceses por un symlink), o el receipt del
  PATH no coincide con la línea que tenés en el rc (esa línea editada a mano
  se conserva y el mensaje la nombra). Borrala a mano como indica el plan.
- **`gentle-shell: No pi runtime could be found`** — una instalación
  empaquetada trae su propio Pi; si instalaste la standalone, Pi tiene que
  estar en el PATH.
- **`gentle-shell install` no hace nada** — el home nunca fue provisionado:
  corré `gentle-shell setup` (paso 4).
- **La memoria dice "disabled" en cada arranque** — no definas `ENGRAM_BIN`,
  `ENGRAM_URL` ni `ENGRAM_DATA_DIR` a mano: una selección explícita desactiva
  la memoria empaquetada.
- **`purge-pi-opencode-gentle.sh` borra `~/.agents` y `~/.local/bin/engram`** —
  ese script no es parte de esta reinstalación y eliminaría todos los skills
  de agente. No lo corras.
