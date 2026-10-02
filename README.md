# ryoku-valorant-setup

Tema **estilo Valorant** para Ryoku (Arch Linux · Hyprland · Quickshell): paleta azul noche + rojo + crema, tipografías condensadas, esquinas cortadas y un solo instalador interactivo que respalda todo lo que reemplaza.

> Ryoku theme inspired by the Valorant client UI: navy/red/cream palette, Bebas Neue + Barlow type, sharp corners, animated red↔teal window border, custom lockscreen and a looping video wallpaper. One interactive installer with backups and restore. Unofficial fan theme, not affiliated with Riot Games.

## Vista previa

| Lockscreen (`Super + L`) | Instalador |
|---|---|
| ![Lockscreen](docs/img/lockscreen.jpg) | ![Instalador](docs/img/installer.png) |

![Wallpaper](docs/img/wallpaper.jpg)

## Instalación

```bash
git clone <este-repo> ryoku-valorant-setup
cd ryoku-valorant-setup
./install.sh
```

Sin argumentos abre un menú con flechas: **Instalar**, **Simular** (no escribe nada), **Restaurar** y **Salir**. Requiere Ryoku ya instalado y abierto al menos una vez, y `python3`.

| Componente | Qué hace |
|---|---|
| `border` | Borde rojo↔cian que gira, esquinas rectas, huecos finos (`~/.config/hypr/user.lua`) |
| `lock` | Lockscreen «Agent»: reloj en Bebas Neue, tarjeta de login con esquinas cortadas, botones oblicuos, barrido rojo al desbloquear |
| `fonts` | Bebas Neue (parecida a Tungsten) y Barlow (parecida a DIN), solo en `~/.local/share/fonts` |
| `term` | kitty con paleta Valorant fija, fish, starship (degradado crema→rojo), fastfetch con la V |
| `wall` | Video animado en `~/videowalls` + imágenes en `~/Pictures/Wallpapers`; deja el video como fondo |
| `settings` | Fusiona solo las claves del tema en `shell.json`, `desktop.json` y `brand.json` (fuente, esquinas, borde, marca). No sustituye los archivos enteros |

Flags para scripts: `--yes`, `--only border,lock`, `--all`, `--dry-run`, `--list`, `--restore [dir]`.

## Deshacer

Cada instalación guarda en `~/.local/state/ryoku-valorant-backup/<fecha>/` lo que reemplazó y la lista de lo que creó.

```bash
./install.sh --restore
```

El restore no devuelve el wallpaper anterior (cámbialo con `Super + W`). Para volver solo al lockscreen anterior: `ryoku-hub lock set <tema>`.

## Paleta

| | |
|---|---|
| Fondo | `#0f1923` |
| Panel | `#17222e` |
| Rojo | `#ff4655` · oscuro `#bd3944` |
| Crema | `#ece8e1` |
| Cian | `#3dd6c6` |
| Apagado | `#768079` |

El borde, la terminal y el lockscreen usan esta paleta fija. Los colores del shell (Hub, barra) los sigue calculando Ryoku desde el wallpaper, así que con el video de Omen tiran a azul/violeta.

## Créditos y licencias

- Fuentes [Bebas Neue](https://github.com/dharmatype/Bebas-Neue) y [Barlow](https://github.com/jpt/barlow): SIL Open Font License (ver `files/.local/share/fonts/valorant/OFL-*.txt`).
- La V del emblema es un dibujo propio inspirado en el logo del juego.
- El video y las imágenes de fondo son arte del juego (© Riot Games) aportados por la usuaria para uso personal. **No publiques este repo si no tienes derecho a redistribuirlos**; quita `files/videowalls/` y los `valorant-*.png` antes de hacerlo.
