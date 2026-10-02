#!/usr/bin/env python3
"""Línea superior del prompt con un degradado continuo crema -> rojo -> rojo oscuro.

Imprime: usuario ❯ rama de git ❯ carpeta, cada carácter en un tono distinto.
La duración del comando la dibuja el módulo cmd_duration de starship.
"""
import os, subprocess

STOPS = [(236, 232, 225), (255, 70, 85), (189, 57, 68)]


def mix(t):
    t = max(0.0, min(1.0, t)) * (len(STOPS) - 1)
    i = min(int(t), len(STOPS) - 2)
    a, b = STOPS[i], STOPS[i + 1]
    return tuple(round(a[k] + (b[k] - a[k]) * (t - i)) for k in range(3))


def git_branch(cwd):
    """rama (o commit) y si hay cambios sin commitear"""
    try:
        run = lambda *a: subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True, timeout=0.4).stdout.strip()
        br = run("branch", "--show-current") or run("rev-parse", "--short", "HEAD")
        return br, bool(br and run("status", "--porcelain"))
    except Exception:
        return "", False


cwd = os.getcwd()
home = os.path.expanduser("~")
path = "~" + cwd[len(home):] if cwd == home or cwd.startswith(home + "/") else cwd
parts = path.split("/")
if len(parts) > 3:
    path = "…/" + "/".join(parts[-3:])

segs = [f" {os.environ.get('USER', '').upper()}"]
br, dirty = git_branch(cwd)
if br:
    segs.append(f"\U000f02a2 {br}" + (" " if dirty else ""))
segs.append(f" {path}")

shell = os.environ.get("STARSHIP_SHELL", "")
wrap = {"zsh": ("%{", "%}"), "bash": ("\001", "\002")}.get(shell, ("", ""))
esc = lambda c, bold=True: f"{wrap[0]}\033[{'1;' if bold else ''}38;2;{c[0]};{c[1]};{c[2]}m{wrap[1]}"
RESET = f"{wrap[0]}\033[0m{wrap[1]}"


def pgrad(text):
    n = max(len(text) - 1, 1)
    return "".join(ch if ch == " " else esc(mix(i / n)) + ch for i, ch in enumerate(text)) + RESET


sep = f" {esc((255, 70, 85))}◆{RESET} "
print(sep.join(pgrad(t) for t in segs), end="")
