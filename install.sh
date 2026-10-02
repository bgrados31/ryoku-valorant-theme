#!/usr/bin/env bash
# Ryoku · Valorant — interactive installer. Run it with no arguments for the menu,
# or see --help for the scriptable flags.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BACKUP_ROOT="$HOME/.local/state/ryoku-valorant-backup"
VERSION="1.1"

# ── components ───────────────────────────────────────────────────────────────
ORDER=(border lock fonts palette term wall settings)
declare -A LABEL DESC DEFAULT
LABEL[border]="Borde animado";             DESC[border]="rojo, crema y granate que gira; esquinas rectas y huecos finos";     DEFAULT[border]=1
LABEL[lock]="Lockscreen Agente";           DESC[lock]="fondo de video animado, reloj Bebas Neue, tarjeta de login con esquinas cortadas"; DEFAULT[lock]=1
LABEL[fonts]="Fuentes";                    DESC[fonts]="Bebas Neue (como Tungsten) y Barlow (como DIN), solo para tu usuario"; DEFAULT[fonts]=1
LABEL[term]="Terminal y prompt";           DESC[term]="kitty con paleta fija, fish, starship rojo, fastfetch con la V";       DEFAULT[term]=1
LABEL[wall]="Wallpaper animado y marca";   DESC[wall]="video en ~/videowalls + imágenes; deja el video como fondo";            DEFAULT[wall]=1
LABEL[palette]="Paleta del shell";         DESC[palette]="tema de colores fijo «Valorant» para barra, Hub, lanzador y apps (adiós al azul)"; DEFAULT[palette]=1
LABEL[settings]="Ajustes del shell";       DESC[settings]="fuente Barlow, reloj rojo y crema, fechas en español, lanzador y visualizador rojos, marca V (recarga el shell)"; DEFAULT[settings]=1
declare -A SEL
for k in "${ORDER[@]}"; do SEL[$k]=${DEFAULT[$k]}; done

# ── colours ──────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  if [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* ]]; then
    RED=$'\e[38;2;255;70;85m'; CREAM=$'\e[38;2;236;232;225m'; DIM=$'\e[38;2;138;143;140m'; OK=$'\e[38;2;236;232;225m'
    G1=$'\e[38;2;255;120;130m'; G2=$'\e[38;2;255;100;112m'; G3=$'\e[38;2;255;85;98m'; G4=$'\e[38;2;240;75;88m'; G5=$'\e[38;2;215;66;78m'; G6=$'\e[38;2;189;57;68m'
  else
    RED=$'\e[38;5;203m'; CREAM=$'\e[38;5;255m'; DIM=$'\e[38;5;245m'; OK=$'\e[38;5;255m'
    G1=$'\e[38;5;210m'; G2=$'\e[38;5;209m'; G3=$'\e[38;5;203m'; G4=$'\e[38;5;203m'; G5=$'\e[38;5;167m'; G6=$'\e[38;5;167m'
  fi
  BOLD=$'\e[1m'; RST=$'\e[0m'
else
  RED=''; CREAM=''; DIM=''; OK=''; G1=''; G2=''; G3=''; G4=''; G5=''; G6=''; BOLD=''; RST=''
fi
cursor_hide() { [ -t 1 ] && printf '\e[?25l' || true; }
cursor_show() { [ -t 1 ] && printf '\e[?25h' || true; }
trap 'cursor_show' EXIT
trap 'cursor_show; echo; echo "${RED}Cancelado.${RST}"; exit 130' INT

# ── flags ────────────────────────────────────────────────────────────────────
DRY=0; YES=0; ONLY=""; DO_RESTORE=0; RESTORE_DIR=""; DO_LIST=0; UNINSTALL=0
usage() {
  cat <<EOF
Ryoku · Valorant installer v$VERSION

  ./install.sh                 menú interactivo
  ./install.sh --yes           instala los componentes por defecto sin preguntar
  ./install.sh --only a,b      solo esos componentes (sin menú)
  ./install.sh --all           todos, incluido «settings»
  ./install.sh --dry-run       simula: no escribe nada
  ./install.sh --list          lista los componentes
  ./install.sh --restore [dir] vuelve a un respaldo (el último si no das dir)
  ./install.sh --uninstall     deshace todas las instalaciones, de la más nueva a la
                               más antigua: deja el escritorio como estaba antes del tema

Componentes: ${ORDER[*]}
EOF
}
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY=1 ;;
    --yes|-y) YES=1 ;;
    --all) YES=1; for k in "${ORDER[@]}"; do SEL[$k]=1; done ;;
    --only) if [ $# -lt 2 ] || [[ $2 == --* ]]; then echo "falta la lista de componentes de --only (usa --list)" >&2; exit 1; fi
            shift; ONLY=$1; YES=1 ;;
    --only=*) ONLY=${1#--only=}; YES=1 ;;
    --list) DO_LIST=1 ;;
    --restore) DO_RESTORE=1; if [ -n "${2:-}" ] && [[ $2 != --* ]]; then RESTORE_DIR=$2; shift; fi ;;
    --uninstall) DO_RESTORE=1; UNINSTALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done
if [ -n "$ONLY" ]; then
  for k in "${ORDER[@]}"; do SEL[$k]=0; done
  IFS=, read -ra want <<<"$ONLY"
  n_want=0
  for w in "${want[@]}"; do
    w=${w//[[:space:]]/}
    [ -n "$w" ] || continue
    [[ -n ${LABEL[$w]:-} ]] || { echo "componente desconocido: $w (usa --list)" >&2; exit 1; }
    SEL[$w]=1; n_want=$((n_want + 1))
  done
  [ "$n_want" -gt 0 ] || { echo "--only necesita al menos un componente (usa --list)" >&2; exit 1; }
fi
if [ "$DO_LIST" = 1 ]; then for k in "${ORDER[@]}"; do printf '%-9s %s\n' "$k" "${LABEL[$k]} — ${DESC[$k]}"; done; exit 0; fi

INTERACTIVE=0
if [ -t 0 ] && [ -t 1 ] && [ "$YES" = 0 ]; then INTERACTIVE=1; fi

# ── ui helpers ───────────────────────────────────────────────────────────────
banner() {
  if [ "$INTERACTIVE" = 1 ]; then printf '\e[2J\e[H'; fi
  echo
  printf '%s\n' "${G1}  ██╗   ██╗ █████╗ ██╗      ██████╗ ██████╗  █████╗ ███╗   ██╗████████╗${RST}" \
                "${G2}  ██║   ██║██╔══██╗██║     ██╔═══██╗██╔══██╗██╔══██╗████╗  ██║╚══██╔══╝${RST}" \
                "${G3}  ██║   ██║███████║██║     ██║   ██║██████╔╝███████║██╔██╗ ██║   ██║   ${RST}" \
                "${G4}  ╚██╗ ██╔╝██╔══██║██║     ██║   ██║██╔══██╗██╔══██║██║╚██╗██║   ██║   ${RST}" \
                "${G5}   ╚████╔╝ ██║  ██║███████╗╚██████╔╝██║  ██║██║  ██║██║ ╚████║   ██║   ${RST}" \
                "${G6}    ╚═══╝  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ${RST}"
  echo
  printf '  %s◆ AGENT SETUP%s  %sRyoku · tema estilo Valorant%s  %sv%s%s\n' "$RED$BOLD" "$RST" "$CREAM$BOLD" "$RST" "$DIM" "$VERSION" "$RST"
  if [ "$DRY" = 1 ]; then printf '  %s● modo simulación: no se escribirá nada%s\n' "$RED" "$RST"; fi
  echo
}
rule() { printf '  %s%s%s\n' "$DIM" "──────────────────────────────────────────────────────" "$RST"; }
ok()   { printf '  %s✔%s %s\n' "$OK" "$RST" "$*"; }
warn() { printf '  %s!%s %s\n' "$RED" "$RST" "$*"; }
info() { printf '  %s◆%s %s\n' "$RED" "$RST" "$*"; }
bar() { # bar <done> <total>
  local d=$1 t=$2 w=24 f i out=""
  f=$(( t == 0 ? w : d * w / t ))
  for ((i = 0; i < w; i++)); do if ((i < f)); then out+="█"; else out+="░"; fi; done
  printf '%s%s%s' "$RED" "$out" "$RST"
}
read_key() { # sets KEY to up|down|space|enter|a|n|q|other
  local k rest=""
  IFS= read -rsn1 k || { KEY=q; return 0; }
  case $k in
    $'\e') read -rsn2 -t 0.05 rest || true
           case $rest in '[A') KEY=up ;; '[B') KEY=down ;; *) KEY=other ;; esac ;;
    ' ') KEY=space ;;
    '') KEY=enter ;;
    k) KEY=up ;; j) KEY=down ;;
    a|A) KEY=a ;; n|N) KEY=n ;; q|Q) KEY=q ;;
    *) KEY=other ;;
  esac
}

# menu <title> <"label|description"...> ; sets CHOICE (0-based) or -1 on quit
menu() {
  local title=$1; shift
  local items=("$@") cur=0 n=$# i drawn=0 lab des
  cursor_hide
  while true; do
    if ((drawn)); then printf '\e[%dA' "$drawn"; fi
    drawn=0
    printf '\e[2K  %s%s%s\n' "$BOLD$CREAM" "$title" "$RST"; drawn=$((drawn + 1))
    for ((i = 0; i < n; i++)); do
      lab=${items[$i]%%|*}; des=${items[$i]#*|}
      if ((i == cur)); then printf '\e[2K  %s◆ %s%s\n' "$RED$BOLD" "$lab" "$RST"
      else printf '\e[2K    %s\n' "$lab"; fi
      printf '\e[2K      %s%s%s\n' "$DIM" "$des" "$RST"
      drawn=$((drawn + 2))
    done
    printf '\e[2K  %s↑/↓ mover · enter elegir · q salir%s\n' "$DIM" "$RST"; drawn=$((drawn + 1))
    read_key
    case $KEY in
      up) cur=$(( (cur + n - 1) % n )) ;;
      down) cur=$(( (cur + 1) % n )) ;;
      enter) CHOICE=$cur; cursor_show; return 0 ;;
      q) CHOICE=-1; cursor_show; return 0 ;;
    esac
  done
}

checklist() { # toggles SEL[]; returns 1 if the user quit
  local cur=0 n=${#ORDER[@]} i drawn=0 k box
  cursor_hide
  while true; do
    if ((drawn)); then printf '\e[%dA' "$drawn"; fi
    drawn=0
    printf '\e[2K  %sElige qué instalar%s\n' "$BOLD$CREAM" "$RST"; drawn=$((drawn + 1))
    for ((i = 0; i < n; i++)); do
      k=${ORDER[$i]}
      if [ "${SEL[$k]}" = 1 ]; then box="${OK}[✔]${RST}"; else box="${DIM}[ ]${RST}"; fi
      if ((i == cur)); then printf '\e[2K  %s◆%s %s %s%s%s\n' "$RED$BOLD" "$RST" "$box" "$BOLD" "${LABEL[$k]}" "$RST"
      else printf '\e[2K    %s %s\n' "$box" "${LABEL[$k]}"; fi
      printf '\e[2K        %s%s%s\n' "$DIM" "${DESC[$k]}" "$RST"
      drawn=$((drawn + 2))
    done
    printf '\e[2K  %s↑/↓ mover · espacio marcar · a todo · n nada · enter continuar · q salir%s\n' "$DIM" "$RST"; drawn=$((drawn + 1))
    read_key
    case $KEY in
      up) cur=$(( (cur + n - 1) % n )) ;;
      down) cur=$(( (cur + 1) % n )) ;;
      space) k=${ORDER[$cur]}; SEL[$k]=$(( 1 - SEL[$k] )) ;;
      a) for k in "${ORDER[@]}"; do SEL[$k]=1; done ;;
      n) for k in "${ORDER[@]}"; do SEL[$k]=0; done ;;
      enter) cursor_show; return 0 ;;
      q) cursor_show; return 1 ;;
    esac
  done
}

confirm() { # confirm <question> -> 0 yes
  if [ "$INTERACTIVE" != 1 ]; then return 0; fi
  local a=""
  printf '  %s%s%s %s[S/n]%s ' "$BOLD$CREAM" "$1" "$RST" "$DIM" "$RST"
  IFS= read -rsn1 a || a=n
  echo
  [[ -z $a || $a =~ ^[sSyY]$ ]]
}

# ── core ─────────────────────────────────────────────────────────────────────
# One backup folder per run: <fecha>-<ms>-<azar>, so two runs in the same second never share one.
# Inside it: the replaced files at their $HOME-relative path, plus bookkeeping:
#   .created       files the run created (restore deletes them)
#   .created_dirs  folders the run created (restore removes them when empty)
#   .keys.json     for merged JSON settings: the key paths the run changed (restore puts back only those)
#   .meta/         values a copied file cannot give back: previous palette, wallpaper, lockscreen
# A backup that has been restored moves to $BACKUP_ROOT/.undone/, so it is never replayed.
BACKUP=""; N_NEW=0; N_CHG=0; N_SAME=0
begin_backup() {
  [ -z "$BACKUP" ] || return 0
  local stamp; stamp=$(date +%Y%m%d-%H%M%S-%3N)
  if [ "$DRY" = 1 ]; then BACKUP="$BACKUP_ROOT/$stamp-simulado"; return 0; fi
  mkdir -p "$BACKUP_ROOT"
  BACKUP=$(mktemp -d "$BACKUP_ROOT/$stamp-XXXX")
}
backup_has() { [ -e "$BACKUP/$1" ] || [ -L "$BACKUP/$1" ]; }
save_original() { # save_original <abs path>: copy the current content into the backup, once per run
  local dst=$1 rel=${1#"$HOME"/}
  begin_backup
  if [ "$DRY" = 1 ] || backup_has "$rel"; then return 0; fi
  mkdir -p "$BACKUP/$(dirname "$rel")"
  # -L: a dotfile symlink (stow, chezmoi) is backed up as the content it points to; restore writes it back through the link
  cp -aL "$dst" "$BACKUP/$rel"
}
install_file() { # install_file <src> <dst>  -> returns 0, and sets LAST_CHANGED=1 when it wrote
  local src=$1 dst=$2 rel=${2#"$HOME"/}
  LAST_CHANGED=0
  if [ -L "$dst" ] && [ ! -e "$dst" ]; then
    warn "$rel es un enlace roto: se omite"; return 0
  fi
  if [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then N_SAME=$((N_SAME + 1)); return 0; fi
    save_original "$dst"
    N_CHG=$((N_CHG + 1))
  else
    begin_backup
    if [ "$DRY" = 0 ]; then
      printf '%s\n' "$rel" >>"$BACKUP/.created"
      local up; up=$(dirname "$dst")   # remember folders we create, so --restore can remove them again
      while [ ! -d "$up" ]; do printf '%s\n' "${up#"$HOME"/}" >>"$BACKUP/.created_dirs"; up=$(dirname "$up"); done
    fi
    N_NEW=$((N_NEW + 1))
  fi
  if [ "$DRY" = 0 ]; then
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ]; then cat "$src" >"$dst"; else cp -a "$src" "$dst"; fi   # through a symlink, keep the link
  fi
  LAST_CHANGED=1
}
files_of() { # relative file paths for a manifest entry (file or directory)
  if [ -d "$HERE/files/$1" ]; then (cd "$HERE/files" && find "$1" -type f | sort); else echo "$1"; fi
}

# jsontool <cmd> ...: the JSON work, in one small Python program
#   merge   <patch> <dst> <home> <out> <keys-out>   exit 0 merged, 3 nothing to change, 1 bad JSON
#   addkeys <keys.json> <rel> <keys-file>           record changed key paths for <rel>
#   unmerge <current> <backup> <keys.json> <rel> <out>  put back only the recorded key paths
#                                                   (4: none recorded for <rel>, 5: result equals the backup)
#   get     <file> <dotted.path>                    print a string value ("" if missing)
JSONTOOL=$(cat <<'PY'
import json, sys
def load(p):
    with open(p, encoding="utf-8") as f: return json.load(f)
def dump(o, p):
    with open(p, "w", encoding="utf-8") as f: f.write(json.dumps(o, indent=2, ensure_ascii=False) + "\n")
def sub(v, home):
    if isinstance(v, str): return v.replace("@HOME@", home)
    if isinstance(v, dict): return {k: sub(x, home) for k, x in v.items()}
    return v
def merge(a, b, prefix, keys):
    # keys gets every leaf path the patch sets, so a restore can put back exactly those
    for k, v in b.items():
        if isinstance(v, dict) and (k not in a or isinstance(a[k], dict)):
            a.setdefault(k, {}); merge(a[k], v, prefix + [k], keys)
        else:
            keys.append(prefix + [k]); a[k] = v
MISSING = object()
def walk(o, path):
    for k in path:
        if not isinstance(o, dict) or k not in o: return MISSING
        o = o[k]
    return o
def main():
    cmd, a = sys.argv[1], sys.argv[2:]
    if cmd == "merge":
        patch, dst, home, out, kout = a
        cur = load(dst)
        if not isinstance(cur, dict): raise SystemExit(1)
        before = json.dumps(cur, sort_keys=True)
        keys = []
        merge(cur, sub(load(patch), home), [], keys)
        json.dump(keys, open(kout, "w"))
        if json.dumps(cur, sort_keys=True) == before: raise SystemExit(3)
        dump(cur, out)
    elif cmd == "addkeys":
        kfile, rel, new = a
        try: d = load(kfile)
        except Exception: d = {}
        have = d.setdefault(rel, [])
        for k in load(new):
            if k not in have: have.append(k)
        dump(d, kfile)
    elif cmd == "unmerge":
        curp, bakp, kfile, rel, out = a
        recorded = load(kfile)
        if rel not in recorded: raise SystemExit(4)
        cur, bak = load(curp), load(bakp)
        if not isinstance(cur, dict) or not isinstance(bak, dict): raise SystemExit(1)
        for path in recorded[rel]:
            old = walk(bak, path)
            node = cur
            for k in path[:-1]:
                if not isinstance(node.get(k), dict):
                    if old is MISSING: node = None; break
                    node[k] = {}
                node = node[k]
            if node is None: continue
            if old is not MISSING: node[path[-1]] = old; continue
            node.pop(path[-1], None)
            for i in range(len(path) - 1, 0, -1):   # drop parents the install created, once they are empty
                pre = path[:i]
                if walk(bak, pre) is MISSING and walk(cur, pre) == {}: walk(cur, pre[:-1]).pop(pre[-1])
                else: break
        if cur == bak: raise SystemExit(5)   # same as the backup: let the caller copy its exact bytes
        dump(cur, out)
    elif cmd == "get":
        v = walk(load(a[0]), a[1].split("."))
        print(v if isinstance(v, str) else "")
try: main()
except SystemExit: raise
except Exception: raise SystemExit(1)
PY
)
jsontool() { python3 -c "$JSONTOOL" "$@" 2>/dev/null; }

record_keys() { # record_keys <abs json path> <keys-file>: remember which keys this run changed in it
  [ "$DRY" = 0 ] || return 0
  begin_backup
  jsontool addkeys "$BACKUP/.keys.json" "${1#"$HOME"/}" "$2" || true
}
merge_patch() { # merge_patch <settings/x.patch.json>: deep-merge its keys into ~/.config/ryoku/x.json
  local patch=$1 name dst tmp keys rc=0
  name=$(basename "$patch" .patch.json); dst="$HOME/.config/ryoku/$name.json"
  [ -f "$dst" ] || { warn "no existe $dst (¿primer arranque de Ryoku?): se omite"; return 0; }
  tmp=$(mktemp); keys=$(mktemp)
  jsontool merge "$patch" "$dst" "$HOME" "$tmp" "$keys" || rc=$?
  case $rc in
    0) chmod --reference="$dst" "$tmp" 2>/dev/null || true
       install_file "$tmp" "$dst"
       if [ "$LAST_CHANGED" = 1 ]; then record_keys "$dst" "$keys"; fi ;;
    3) N_SAME=$((N_SAME + 1)) ;;   # every key already has the theme's value: nothing to write or back up
    *) warn "no pude leer $name.json (JSON no válido): se deja como estaba" ;;
  esac
  rm -f "$tmp" "$keys"
}
# patches that belong to another component instead of «settings»
declare -A PATCH_OWNER=([ryogami]=palette)
install_component() { # install_component <id>
  local id=$1 f g p n total done_=0
  local -a all=()
  if [ "$id" = settings ]; then
    for f in "$HERE"/settings/*.patch.json; do
      n=$(basename "$f" .patch.json)
      [ -z "${PATCH_OWNER[$n]:-}" ] && all+=("patch:$f")
    done
  else
    while read -r g p; do
      if [ "$g" = "$id" ]; then while read -r f; do all+=("$f"); done < <(files_of "$p"); fi
    done < <(awk '!/^[[:space:]]*(#|$)/' "$HERE/MANIFEST")
    for n in "${!PATCH_OWNER[@]}"; do
      if [ "${PATCH_OWNER[$n]}" = "$id" ] && [ -f "$HERE/settings/$n.patch.json" ]; then all+=("patch:$HERE/settings/$n.patch.json"); fi
    done
  fi
  total=${#all[@]}
  N_NEW=0; N_CHG=0; N_SAME=0
  for f in "${all[@]}"; do
    if [[ $f == patch:* ]]; then
      merge_patch "${f#patch:}"
    else
      install_file "$HERE/files/$f" "$HOME/$f"
    fi
    done_=$((done_ + 1))
    if [ "$INTERACTIVE" = 1 ]; then
      printf '\r\e[2K  %s %s %d/%d' "$(bar "$done_" "$total")" "${LABEL[$id]}" "$done_" "$total"; sleep 0.03
    fi
  done
  if [ "$INTERACTIVE" = 1 ]; then printf '\r\e[2K'; fi
  ok "$(printf '%-26s' "${LABEL[$id]}") ${DIM}${N_NEW} nuevos · ${N_CHG} reemplazados · ${N_SAME} ya iguales${RST}"
}
run_apply() { # run_apply <description> <cmd...>
  local d=$1; shift
  if [ "$DRY" = 1 ]; then info "$d ${DIM}(simulado)${RST}"; return 0; fi
  if "$@" >/dev/null 2>&1; then ok "$d"; else warn "$d ${DIM}— falló; cierra sesión y vuelve a entrar${RST}"; fi
}
has() { [[ " $PICKED " == *" $1 "* ]]; }

# ── apply helpers (each one is a command for run_apply) ─────────────────────
THEME_ID="valorant"
retry() { # retry <cmd...>: the shell daemon may be restarting (systemd brings it back in ~2 s), so try for ~10 s
  local i
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    "$@" && return 0
    sleep 0.5
  done
  return 1
}
wm_reload() { # Ryoku's own reload path first; plain hyprctl only as a fallback
  ryoku wm act config.reload || hyprctl reload
}
shell_reload() { retry ryoku reload; }
shell_theme() { retry ryoku-shell theme "$1"; }
desktop_regen() { # re-save desktop.json through the Hub so Hyprland's generated settings.lua follows it
  local f="$HOME/.config/ryoku/desktop.json" mode rc=0
  [ -f "$f" ] || return 0
  mode=$(stat -L -c %a "$f")
  ryoku-hub desktop save "$(cat "$f")" || rc=$?
  chmod "$mode" "$f" 2>/dev/null || true   # the Hub saves with 0644; keep the user's mode (often 0600)
  return "$rc"
}
current_theme() { # theme.theme in shell.json ("" if unknown)
  [ -f "$HOME/.config/ryoku/shell.json" ] || return 0
  jsontool get "$HOME/.config/ryoku/shell.json" theme.theme || true
}
meta_save() { # meta_save <key> <value>: remembers a pre-install value in the backup (only the first time)
  [ -n "$2" ] || return 0
  begin_backup
  if [ "$DRY" = 1 ]; then info "recordaría $1 = $2 ${DIM}(simulado)${RST}"; return 0; fi
  mkdir -p "$BACKUP/.meta"
  [ -f "$BACKUP/.meta/$1" ] || printf '%s\n' "$2" >"$BACKUP/.meta/$1"
}
ours() { # ours <abs path>: is this a file the theme itself ships (so not a «previous» value)?
  local g p
  while read -r g p; do
    if [ "$1" = "$HOME/$p" ] || [[ $1 == "$HOME/$p/"* ]]; then return 0; fi
  done < <(awk '!/^[[:space:]]*(#|$)/' "$HERE/MANIFEST")
  return 1
}
backup_files() { # backup_files <dir>: the backed-up files (relative), without the bookkeeping
  (cd "$1" && find . \( -path ./.meta -prune \) -o \( \( -type f -o -type l \) ! -name .created ! -name .created_dirs ! -name .keys.json -print \) | sed 's|^\./||')
}
backup_dirs() { # the backups not yet restored, newest first (dot-folders such as .undone are skipped)
  local d; local -a all=()
  for d in "$BACKUP_ROOT"/*/; do [ -d "$d" ] && all+=("${d%/}"); done
  for ((d = ${#all[@]} - 1; d >= 0; d--)); do printf '%s\n' "${all[$d]}"; done
}

preflight() {
  if ! command -v ryoku >/dev/null; then warn "Ryoku no está instalado en este equipo: instálalo primero."; exit 1; fi
  ok "Ryoku $(ryoku version 2>/dev/null | head -1 || true)"
  [ -d /usr/share/ryoku ] || warn "falta /usr/share/ryoku: no parece una instalación estándar de Ryoku"
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then ok "sesión Wayland activa"; else warn "fuera de la sesión Hyprland: las recargas pueden fallar"; fi
  local b missing=0
  for b in hyprctl kitty fish starship fastfetch python3; do
    if ! command -v "$b" >/dev/null; then warn "no encontré $b (se copia su config igualmente)"; missing=1; fi
  done
  if [ "$missing" = 0 ]; then ok "kitty · fish · starship · fastfetch · python3 presentes"; fi
  if [ ! -f "$HOME/.config/ryoku/shell.json" ]; then warn "aún no existe ~/.config/ryoku/shell.json: abre Ryoku una vez antes de aplicar «Ajustes del shell»"; fi
  return 0
}

summary() {
  echo; rule
  printf '  %s◆ Listo, agente%s\n\n' "$BOLD$OK" "$RST"
  if [ "$DRY" = 0 ] && [ -n "$BACKUP" ] && [ -d "$BACKUP" ]; then info "respaldo y registro de lo instalado: ${CREAM}$BACKUP${RST}"
  elif [ "$DRY" = 0 ]; then info "nada que respaldar: todo estaba ya instalado"; fi
  if [ "$DRY" = 1 ]; then info "simulación terminada: no se escribió nada."; fi
  echo; printf '  %sRevisa a mano%s\n' "$BOLD$CREAM" "$RST"
  if has lock; then
    info "Lockscreen: pruébalo con Super+L (el fondo es un video en bucle)"
    info "Pantalla de inicio de sesión: Hub → Lockscreen → aplicar también al greeter ${DIM}(ryoku-shell hub open lockscreen; pide contraseña)${RST}"
  fi
  if has border; then info "Borde: abre una ventana; si no gira, cierra sesión y vuelve a entrar. Sus colores los fija ~/.config/hypr/user.lua, que gana a Hub → Window Manager"; fi
  if has palette; then info "Colores: tema fijo «Valorant». Para volver a seguir el wallpaper: Super+W → ajustes → Theme → Palette behaviour"; fi
  if has settings; then
    info "Reloj del escritorio: clic derecho en el reloj → Customize ${DIM}(o ryoku-shell hub open widgets, que abre el editor de widgets del escritorio)${RST}"
    info "Fechas en español: Hub → General → Regional formats ${DIM}(queda en es_ES; ryoku-shell hub open global)${RST}"
    info "Si la fuente o las esquinas no cambian: cierra sesión y vuelve a entrar"
  fi
  if has wall; then info "Wallpaper: Super+W para cambiarlo; el video está en ~/videowalls"; fi
  info "Deshacer: ${DIM}./install.sh --restore${RST} (último respaldo) o ${DIM}--uninstall${RST} (todo)"
  echo
}

PICKED=""
do_install() {
  local k prev_theme="" v
  PICKED=""
  for k in "${ORDER[@]}"; do if [ "${SEL[$k]}" = 1 ]; then PICKED+="$k "; fi; done
  if [ -z "$PICKED" ]; then warn "no elegiste nada."; return 0; fi
  echo; rule
  printf '  %sInstalando%s %s\n\n' "$BOLD$CREAM" "$RST" "${DIM}(lo que ya existe y es distinto se respalda)${RST}"
  # remember what --restore cannot get back from a copied file: the applied colour scheme and the wallpaper.
  # A value that already is the theme's own (a re-run) is not a «previous» value, so it is not recorded.
  if has palette; then prev_theme=$(current_theme); [ "$prev_theme" = "$THEME_ID" ] || meta_save theme "$prev_theme"; fi
  if has wall && [ -f "$HOME/.local/state/ryoku-wallpaper" ]; then
    v=$(head -1 "$HOME/.local/state/ryoku-wallpaper"); ours "$v" || meta_save wallpaper "$v"
  fi
  if has lock && [ -f "$HOME/.config/qylock/theme" ]; then
    v=$(head -1 "$HOME/.config/qylock/theme"); [ "$v" = "$(head -1 "$HERE/files/.config/qylock/theme")" ] || meta_save lock "$v"
  fi
  # No need to stop the shell: its daemon re-reads shell.json when the file's mtime changes.
  for k in $PICKED; do install_component "$k"; done
  # `ryoku-shell theme` makes the daemon rewrite theme.theme in shell.json: keep the pre-theme value for --restore
  if has palette && [ -f "$HOME/.config/ryoku/shell.json" ] && [ "$prev_theme" != "$THEME_ID" ]; then
    save_original "$HOME/.config/ryoku/shell.json"
    if [ "$DRY" = 0 ]; then
      k=$(mktemp); printf '[["theme","theme"]]' >"$k"; record_keys "$HOME/.config/ryoku/shell.json" "$k"; rm -f "$k"
    fi
  fi
  # a run that replaced, created and remembered nothing leaves no backup behind (it would hide the real one)
  if [ "$DRY" = 0 ] && [ -n "$BACKUP" ] && [ -d "$BACKUP" ] && [ -z "$(ls -A "$BACKUP")" ]; then rmdir "$BACKUP"; BACKUP=""; fi
  echo; rule; printf '  %sAplicando cambios%s\n\n' "$BOLD$CREAM" "$RST"
  if has fonts; then run_apply "actualizando la caché de fuentes" fc-cache -f "$HOME/.local/share/fonts"; fi
  if has settings; then run_apply "regenerando la config de ventanas desde desktop.json" desktop_regen; fi
  if has border || has settings; then run_apply "recargando Hyprland" wm_reload; fi
  run_apply "recargando el shell de Ryoku" shell_reload
  if has wall; then run_apply "poniendo el video como wallpaper" ryogami wallpaper set "$HOME/videowalls/valorant-agentes.mp4"; fi
  # last, so no wallpaper apply can repaint over it (ryogami's theme.policy is now «fixed»)
  if has palette; then run_apply "aplicando la paleta «Valorant» al shell" shell_theme "$THEME_ID"; fi
  summary
}

restore_file() { # restore_file <backup dir> <rel>: JSON with recorded keys gets only those keys back; anything else the whole file
  local dir=$1 f=$2 dst="$HOME/$2" tmp
  if [ -f "$dir/.keys.json" ] && [ -f "$dst" ] && [[ $f == *.json ]]; then
    tmp=$(mktemp)
    local rc=0; jsontool unmerge "$dst" "$dir/$f" "$dir/.keys.json" "$f" "$tmp" || rc=$?
    if [ "$rc" = 5 ]; then cp "$dir/$f" "$tmp"; rc=0; fi   # nothing else changed: byte-exact original
    if [ "$rc" = 0 ] && [ -s "$tmp" ]; then
      cat "$tmp" >"$dst"; rm -f "$tmp"; return 0   # cat keeps the file's mode, owner and any symlink
    fi
    rm -f "$tmp"
  fi
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then cat "$dir/$f" >"$dst"; else cp -a "$dir/$f" "$dst"; fi
}
restore_one() { # restore_one <dir>: copies back what it replaced and deletes what it created
  local dir=$1 f up
  while read -r f; do
    [ -n "$f" ] || continue
    if [ "$DRY" = 1 ]; then info "restauraría $f ${DIM}(simulado)${RST}"; continue; fi
    restore_file "$dir" "$f"
  done < <(backup_files "$dir")
  if [ -f "$dir/.created" ]; then
    while read -r f; do
      [ -n "$f" ] || continue
      if [ "$DRY" = 1 ]; then info "borraría $f ${DIM}(simulado)${RST}"; continue; fi
      rm -f "$HOME/$f"
      if [ ! -f "$dir/.created_dirs" ]; then # backups from v1.0 have no folder list: remove now-empty parents
        up=$(dirname "$HOME/$f")
        while [ "$up" != "$HOME" ] && [[ $up == "$HOME"/* ]] && rmdir "$up" 2>/dev/null; do up=$(dirname "$up"); done
      fi
    done <"$dir/.created"
  fi
  if [ -f "$dir/.created_dirs" ] && [ "$DRY" = 0 ]; then # deepest first; a folder that is not empty stays
    sort -ru "$dir/.created_dirs" | while read -r f; do [ -n "$f" ] && rmdir "$HOME/$f" 2>/dev/null || true; done
  fi
  if [ "$DRY" = 1 ]; then return 0; fi
  # retire it, so a later --restore/--uninstall never replays it over newer changes
  if [[ $dir != "$BACKUP_ROOT/.undone/"* ]]; then
    mkdir -p "$BACKUP_ROOT/.undone"
    local to="$BACKUP_ROOT/.undone/$(basename "$dir")"
    [ ! -e "$to" ] || to=$(mktemp -u "$to-XXXX")
    mv "$dir" "$to"
  fi
  ok "restaurado desde $(basename "$dir")"
}

do_restore() {
  local dir=$RESTORE_DIR d n prev_theme="" prev_wall="" prev_lock="" touches_desktop=0 snap
  local -a dirs=() todo=()
  if [ -z "$dir" ]; then
    while IFS= read -r d; do [ -n "$d" ] && dirs+=("$d"); done < <(backup_dirs)
    if [ ${#dirs[@]} -eq 0 ]; then warn "no hay respaldos pendientes en $BACKUP_ROOT"; return 0; fi
    if [ "$UNINSTALL" = 1 ]; then
      todo=("${dirs[@]}")
    elif [ "$INTERACTIVE" = 1 ]; then
      local items=()
      for d in "${dirs[@]}"; do
        n=$(backup_files "$d" | wc -l)
        items+=("$(basename "$d")|$n archivos reemplazados · $( [ -f "$d/.created" ] && wc -l <"$d/.created" || echo 0 ) creados")
      done
      menu "Elige el respaldo a restaurar" "${items[@]}"
      if [ "$CHOICE" -lt 0 ]; then return 0; fi
      todo=("${dirs[$CHOICE]}")
    else todo=("${dirs[0]}"); fi
  else
    dir=${dir%/}
    if [ ! -d "$dir" ]; then warn "no existe $dir"; return 1; fi
    todo=("$dir")
  fi
  if [ "$UNINSTALL" = 1 ]; then
    confirm "¿Desinstalar? Se deshacen ${#todo[@]} respaldos, del más nuevo al más antiguo." || return 0
  else
    confirm "¿Restaurar $(basename "${todo[0]}")? Recupera lo reemplazado y borra lo creado." || return 0
  fi
  # newest → oldest: the oldest backup's remembered values win, because they are the state before the theme
  for d in "${todo[@]}"; do
    [ -f "$d/.meta/theme" ] && prev_theme=$(head -1 "$d/.meta/theme")
    [ -f "$d/.meta/wallpaper" ] && prev_wall=$(head -1 "$d/.meta/wallpaper")
    [ -f "$d/.meta/lock" ] && prev_lock=$(head -1 "$d/.meta/lock")
    if [ -f "$d/.config/ryoku/desktop.json" ]; then touches_desktop=1; fi
  done
  # a v1.0 backup may remember the theme's own video as «previous»: that file is about to be deleted
  if [ -n "$prev_wall" ] && ours "$prev_wall"; then prev_wall=""; fi
  # leave the Valorant scheme while its files still exist (the shell refuses a theme it cannot find).
  if [ -n "$prev_theme" ]; then run_apply "volviendo a la paleta «$prev_theme»" shell_theme "$prev_theme"; fi
  # no need to stop the shell: its daemon reloads shell.json by itself when the file changes
  for d in "${todo[@]}"; do restore_one "$d"; done
  if [ "$touches_desktop" = 1 ]; then
    if [ "$DRY" = 1 ]; then info "regenerando la config de ventanas desde desktop.json ${DIM}(simulado)${RST}"
    elif [ -f "$HOME/.config/ryoku/desktop.json" ]; then
      # the Hub re-save regenerates settings.lua; then put back the exact restored bytes
      snap=$(mktemp); cp -a "$HOME/.config/ryoku/desktop.json" "$snap"
      run_apply "regenerando la config de ventanas desde desktop.json" desktop_regen
      cat "$snap" >"$HOME/.config/ryoku/desktop.json"; rm -f "$snap"
    fi
  fi
  run_apply "recargando Hyprland" wm_reload
  run_apply "recargando el shell de Ryoku" shell_reload
  if [ -n "$prev_wall" ]; then
    if [ "$DRY" = 1 ] || [ -e "$prev_wall" ]; then run_apply "devolviendo el wallpaper ${prev_wall##*/}" ryogami wallpaper set "$prev_wall"
    else warn "el wallpaper anterior ya no existe ($prev_wall): elige otro con Super+W"; fi
  elif [ "$DRY" = 0 ] && [ -f "$HOME/.local/state/ryoku-wallpaper" ]; then
    local cur; cur=$(head -1 "$HOME/.local/state/ryoku-wallpaper")
    if [ -n "$cur" ] && ours "$cur" && [ ! -e "$cur" ]; then
      warn "el wallpaper era el video del tema, que se acaba de borrar: elige otro con Super+W"
    fi
  fi
  if [ -n "$prev_lock" ]; then info "lockscreen de la sesión: ${CREAM}$( [ -f "$HOME/.config/qylock/theme" ] && head -1 "$HOME/.config/qylock/theme" || echo "el de Ryoku por defecto")${RST}"; fi
  info "La pantalla de inicio de sesión (greeter) no se toca: cámbiala en Hub → Lockscreen si la habías aplicado."
}

# ── main ─────────────────────────────────────────────────────────────────────
banner
if [ "$DO_RESTORE" = 1 ]; then do_restore; exit 0; fi

if [ "$INTERACTIVE" = 1 ]; then
  menu "¿Qué quieres hacer?" \
    "Instalar|elige los componentes y aplícalos" \
    "Simular|muestra qué haría, sin escribir nada" \
    "Restaurar|vuelve a un respaldo anterior" \
    "Desinstalar|deshace todas las instalaciones y deja el escritorio como antes" \
    "Salir|"
  case $CHOICE in
    0|1)
      if [ "$CHOICE" = 1 ]; then DRY=1; fi
      banner
      checklist || { echo; info "hasta luego."; exit 0; }
      echo; preflight; echo
      confirm "¿Continuar?" || { info "cancelado."; exit 0; }
      do_install ;;
    2) banner; do_restore ;;
    3) UNINSTALL=1; banner; do_restore ;;
    *) echo; info "hasta luego." ;;
  esac
else
  preflight; echo
  do_install
fi
