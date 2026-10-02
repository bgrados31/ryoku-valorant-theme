#!/usr/bin/env bash
# Ryoku · Valorant — interactive installer. Run it with no arguments for the menu,
# or see --help for the scriptable flags.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BACKUP_ROOT="$HOME/.local/state/ryoku-valorant-backup"
VERSION="1.0"

# ── components ───────────────────────────────────────────────────────────────
ORDER=(border lock fonts term wall settings)
declare -A LABEL DESC DEFAULT
LABEL[border]="Borde animado";             DESC[border]="rojo↔cian que gira, esquinas rectas y huecos finos";                 DEFAULT[border]=1
LABEL[lock]="Lockscreen Agente";           DESC[lock]="reloj Bebas Neue, tarjeta de login con esquinas cortadas, barrido rojo"; DEFAULT[lock]=1
LABEL[fonts]="Fuentes";                    DESC[fonts]="Bebas Neue (como Tungsten) y Barlow (como DIN), solo para tu usuario"; DEFAULT[fonts]=1
LABEL[term]="Terminal y prompt";           DESC[term]="kitty con paleta fija, fish, starship rojo, fastfetch con la V";       DEFAULT[term]=1
LABEL[wall]="Wallpaper animado y marca";   DESC[wall]="video en ~/videowalls + imágenes; deja el video como fondo";            DEFAULT[wall]=1
LABEL[settings]="Ajustes del shell";       DESC[settings]="fuente Barlow, esquinas rectas, marca V (fusiona claves; reinicia el shell)"; DEFAULT[settings]=1
declare -A SEL
for k in "${ORDER[@]}"; do SEL[$k]=${DEFAULT[$k]}; done

# ── colours ──────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  if [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* ]]; then
    RED=$'\e[38;2;255;70;85m'; CREAM=$'\e[38;2;236;232;225m'; TEAL=$'\e[38;2;61;214;198m'; DIM=$'\e[38;2;118;128;121m'; OK=$'\e[38;2;61;214;198m'
    G1=$'\e[38;2;255;120;130m'; G2=$'\e[38;2;255;100;112m'; G3=$'\e[38;2;255;85;98m'; G4=$'\e[38;2;240;75;88m'; G5=$'\e[38;2;215;66;78m'; G6=$'\e[38;2;189;57;68m'
  else
    RED=$'\e[38;5;203m'; CREAM=$'\e[38;5;255m'; TEAL=$'\e[38;5;80m'; DIM=$'\e[38;5;243m'; OK=$'\e[38;5;80m'
    G1=$'\e[38;5;210m'; G2=$'\e[38;5;209m'; G3=$'\e[38;5;203m'; G4=$'\e[38;5;203m'; G5=$'\e[38;5;167m'; G6=$'\e[38;5;167m'
  fi
  BOLD=$'\e[1m'; RST=$'\e[0m'
else
  RED=''; CREAM=''; TEAL=''; DIM=''; OK=''; G1=''; G2=''; G3=''; G4=''; G5=''; G6=''; BOLD=''; RST=''
fi
cursor_hide() { [ -t 1 ] && printf '\e[?25l' || true; }
cursor_show() { [ -t 1 ] && printf '\e[?25h' || true; }
trap 'cursor_show' EXIT
trap 'cursor_show; echo; echo "${RED}Cancelado.${RST}"; exit 130' INT

# ── flags ────────────────────────────────────────────────────────────────────
DRY=0; YES=0; ONLY=""; DO_RESTORE=0; RESTORE_DIR=""; DO_LIST=0
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

Componentes: ${ORDER[*]}
EOF
}
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY=1 ;;
    --yes|-y) YES=1 ;;
    --all) YES=1; for k in "${ORDER[@]}"; do SEL[$k]=1; done ;;
    --only) shift; ONLY=${1:-}; YES=1 ;;
    --list) DO_LIST=1 ;;
    --restore) DO_RESTORE=1; if [ -n "${2:-}" ] && [[ $2 != --* ]]; then RESTORE_DIR=$2; shift; fi ;;
    -h|--help) usage; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done
if [ -n "$ONLY" ]; then
  for k in "${ORDER[@]}"; do SEL[$k]=0; done
  IFS=, read -ra want <<<"$ONLY"
  for w in "${want[@]}"; do
    [[ -n ${LABEL[$w]:-} ]] || { echo "componente desconocido: $w (usa --list)" >&2; exit 1; }
    SEL[$w]=1
  done
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
  if [ "$DRY" = 1 ]; then printf '  %s● modo simulación: no se escribirá nada%s\n' "$TEAL" "$RST"; fi
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
BACKUP=""; N_NEW=0; N_CHG=0; N_SAME=0
begin_backup() { if [ -z "$BACKUP" ]; then BACKUP="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"; fi; }
install_file() { # install_file <src> <dst>
  local src=$1 dst=$2 rel=${2#"$HOME"/}
  if [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then N_SAME=$((N_SAME + 1)); return 0; fi
    begin_backup
    if [ "$DRY" = 0 ]; then mkdir -p "$BACKUP/$(dirname "$rel")"; cp -a "$dst" "$BACKUP/$rel"; fi
    N_CHG=$((N_CHG + 1))
  else
    begin_backup
    if [ "$DRY" = 0 ]; then mkdir -p "$BACKUP"; printf '%s\n' "$rel" >>"$BACKUP/.created"; fi
    N_NEW=$((N_NEW + 1))
  fi
  if [ "$DRY" = 0 ]; then mkdir -p "$(dirname "$dst")"; cp -a "$src" "$dst"; fi
}
files_of() { # relative file paths for a manifest entry (file or directory)
  if [ -d "$HERE/files/$1" ]; then (cd "$HERE/files" && find "$1" -type f | sort); else echo "$1"; fi
}
merge_patch() { # merge_patch <settings/x.patch.json>: deep-merge its keys into ~/.config/ryoku/x.json
  local patch=$1 name dst tmp
  name=$(basename "$patch" .patch.json); dst="$HOME/.config/ryoku/$name.json"
  [ -f "$dst" ] || { warn "no existe $dst (¿primer arranque de Ryoku?): se omite"; return 0; }
  tmp=$(mktemp)
  if python3 - "$patch" "$dst" "$HOME" >"$tmp" <<'PY'
import json, sys
patch, dst, home = sys.argv[1], sys.argv[2], sys.argv[3]
def sub(v):
    if isinstance(v, str): return v.replace("@HOME@", home)
    if isinstance(v, dict): return {k: sub(x) for k, x in v.items()}
    return v
def merge(a, b):
    for k, v in b.items():
        if isinstance(v, dict) and isinstance(a.get(k), dict): merge(a[k], v)
        else: a[k] = v
    return a
print(json.dumps(merge(json.load(open(dst)), sub(json.load(open(patch)))), indent=2, ensure_ascii=False))
PY
  then install_file "$tmp" "$dst"; else warn "no pude fusionar $name.json: se deja como estaba"; fi
  rm -f "$tmp"
}
install_component() { # install_component <id>
  local id=$1 f g p total done_=0 tmp
  local -a all=()
  if [ "$id" = settings ]; then
    for f in "$HERE"/settings/*.patch.json; do all+=("$f"); done
  else
    while read -r g p; do
      if [ "$g" = "$id" ]; then while read -r f; do all+=("$f"); done < <(files_of "$p"); fi
    done < <(awk '!/^[[:space:]]*(#|$)/' "$HERE/MANIFEST")
  fi
  total=${#all[@]}
  N_NEW=0; N_CHG=0; N_SAME=0
  for f in "${all[@]}"; do
    if [ "$id" = settings ]; then
      merge_patch "$f"
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
  if [ -d "$BACKUP" ] && [ "$DRY" = 0 ]; then info "respaldo y registro de lo instalado: ${TEAL}$BACKUP${RST}"; fi
  if [ "$DRY" = 1 ]; then info "simulación terminada: no se escribió nada."; fi
  echo; printf '  %sRevisa a mano%s\n' "$BOLD$CREAM" "$RST"
  if has lock; then info "Lockscreen: Hub → Lockscreen (${DIM}ryoku-shell hub open lockscreen${RST}) y pruébalo con Super+L"; fi
  if has border; then info "Borde: abre una ventana; si no gira, ${DIM}hyprctl reload${RST}"; fi
  if has wall; then info "Wallpaper: Super+W para cambiarlo; el video está en ~/videowalls"; fi
  if has settings; then info "Si la fuente o las esquinas no cambian: cierra sesión y vuelve a entrar"; fi
  info "Deshacer: ${DIM}./install.sh --restore${RST}"
  echo
}

PICKED=""
do_install() {
  local k
  PICKED=""
  for k in "${ORDER[@]}"; do if [ "${SEL[$k]}" = 1 ]; then PICKED+="$k "; fi; done
  if [ -z "$PICKED" ]; then warn "no elegiste nada."; return 0; fi
  echo; rule
  printf '  %sInstalando%s %s\n\n' "$BOLD$CREAM" "$RST" "${DIM}(lo que ya existe y es distinto se respalda)${RST}"
  # the shell daemon is the only writer of shell.json: stop it before merging so it cannot overwrite us on exit
  if has settings; then run_apply "cerrando el shell para escribir sus ajustes" ryoku-shell quit; echo; fi
  for k in $PICKED; do install_component "$k"; done
  echo; rule; printf '  %sAplicando cambios%s\n\n' "$BOLD$CREAM" "$RST"
  if has fonts; then run_apply "actualizando la caché de fuentes" fc-cache -f "$HOME/.local/share/fonts"; fi
  if has border || has settings; then run_apply "recargando Hyprland" hyprctl reload; fi
  run_apply "recargando el shell de Ryoku" ryoku reload
  if has wall; then run_apply "poniendo el video como wallpaper" ryogami wallpaper set "$HOME/videowalls/valorant-agentes.mp4"; fi
  summary
}

do_restore() {
  local dir=$RESTORE_DIR d n f
  if [ -z "$dir" ]; then
    local -a dirs=()
    while read -r d; do [ -n "$d" ] && dirs+=("$d"); done < <(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | sort -r | sed 's|/$||' || true)
    if [ ${#dirs[@]} -eq 0 ]; then warn "no hay respaldos en $BACKUP_ROOT"; return 0; fi
    if [ "$INTERACTIVE" = 1 ]; then
      local items=()
      for d in "${dirs[@]}"; do
        n=$(find "$d" -type f ! -name .created | wc -l)
        items+=("$(basename "$d")|$n archivos reemplazados · $( [ -f "$d/.created" ] && wc -l <"$d/.created" || echo 0 ) creados")
      done
      menu "Elige el respaldo a restaurar" "${items[@]}"
      if [ "$CHOICE" -lt 0 ]; then return 0; fi
      dir=${dirs[$CHOICE]}
    else dir=${dirs[0]}; fi
  fi
  if [ ! -d "$dir" ]; then warn "no existe $dir"; return 1; fi
  confirm "¿Restaurar $(basename "$dir")? Recupera lo reemplazado y borra lo creado." || return 0
  while read -r f; do
    if [ "$DRY" = 1 ]; then info "restauraría $f ${DIM}(simulado)${RST}"; continue; fi
    mkdir -p "$(dirname "$HOME/$f")"; cp -a "$dir/$f" "$HOME/$f"
  done < <(cd "$dir" && find . -type f ! -name .created | sed 's|^\./||')
  if [ -f "$dir/.created" ]; then
    while read -r f; do
      [ -n "$f" ] || continue
      if [ "$DRY" = 1 ]; then info "borraría $f ${DIM}(simulado)${RST}"; continue; fi
      rm -f "$HOME/$f"
    done <"$dir/.created"
  fi
  ok "restaurado desde $(basename "$dir")"
  run_apply "recargando Hyprland" hyprctl reload
  run_apply "recargando el shell de Ryoku" ryoku reload
}

# ── main ─────────────────────────────────────────────────────────────────────
banner
if [ "$DO_RESTORE" = 1 ]; then do_restore; exit 0; fi

if [ "$INTERACTIVE" = 1 ]; then
  menu "¿Qué quieres hacer?" \
    "Instalar|elige los componentes y aplícalos" \
    "Simular|muestra qué haría, sin escribir nada" \
    "Restaurar|vuelve a un respaldo anterior" \
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
    *) echo; info "hasta luego." ;;
  esac
else
  preflight; echo
  do_install
fi
