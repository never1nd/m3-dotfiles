#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_JSON="$REPO_DIR/apps.json"
MODE="ask"     # ask | all | list
LIST_IDS=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) MODE="all" ;;
        --apps) MODE="list"; LIST_IDS="${2:-}"; shift ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            echo "Использование: ./install-apps.sh [--all] [--apps id1,id2] [--dry-run]"
            exit 0
            ;;
        *) echo "Неизвестная опция: $1"; exit 1 ;;
    esac
    shift
done

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

if [[ "$MODE" == "ask" ]]; then
    echo ""
    if [[ -t 0 ]]; then
        read -r -p "Хотите установить ваши приложения (Zen, AyuGram, VSCodium, Vesktop, Steam и др.)? [y/N]: " ans
        case "${ans,,}" in
            y|yes|д|да) ;;
            *) echo "==> Установка доп. приложений пропущена (можно запустить позже: ./install-apps.sh)."; exit 0 ;;
        esac
    else
        echo "==> Неинтерактивный терминал — пропуск выбора приложений (используйте --all-apps или ./install-apps.sh)."
        exit 0
    fi
fi

# Interactive curses checkbox picker (fallback to numbered prompt if curses unavailable)
SELECTED="$(python3 - "$APPS_JSON" "$MODE" "$LIST_IDS" <<'PYEOF'
import json, sys, os

import platform
arch = os.environ.get("M3_FORCE_ARCH") or platform.machine()
if arch == "arm64":
    arch = "aarch64"
raw_apps = json.load(open(sys.argv[1], encoding="utf-8"))
apps = [a for a in raw_apps if arch in a.get("arch", ["x86_64"])]
mode = sys.argv[2]
list_ids = [x.strip() for x in sys.argv[3].split(",") if x.strip()]

if mode == "all":
    print(" ".join(a["id"] for a in apps))
    sys.exit(0)
if mode == "list":
    valid = {a["id"] for a in apps}
    print(" ".join(i for i in list_ids if i in valid))
    sys.exit(0)

checked = [bool(a.get("default", False)) for a in apps]

def fallback_menu():
    print("\nДоступные приложения:")
    for idx, a in enumerate(apps, 1):
        mark = "x" if checked[idx - 1] else " "
        print(f"  {idx:2d}. [{mark}] {a['name']:<22s} — {a['desc']}")
    print("\nВведите номера для переключения (например: 1 3 7), 'all' (все), 'none' (ничего) или Enter для установки отмеченных:")
    while True:
        sys.stderr.write("> ")
        sys.stderr.flush()
        line = sys.stdin.readline()
        if not line or line.strip() == "":
            break
        s = line.strip().lower()
        if s in ("q", "quit", "exit"):
            return []
        if s == "all":
            checked[:] = [True] * len(apps)
        elif s == "none":
            checked[:] = [False] * len(apps)
        else:
            for tok in s.replace(",", " ").split():
                if tok.isdigit():
                    n = int(tok)
                    if 1 <= n <= len(apps):
                        checked[n - 1] = not checked[n - 1]
        for idx, a in enumerate(apps, 1):
            mark = "x" if checked[idx - 1] else " "
            sys.stderr.write(f"  {idx:2d}. [{mark}] {a['name']}\n")
    return [a["id"] for a, ok in zip(apps, checked) if ok]

if not (sys.stdin.isatty() and sys.stdout.isatty()):
    # Open /dev/tty if stdout is captured by $(...)!
    try:
        import curses
        tty_in = open("/dev/tty", "r")
        tty_out = open("/dev/tty", "w")
        os.dup2(tty_in.fileno(), 0)
        saved_stdout = os.dup(1)
        os.dup2(tty_out.fileno(), 1)

        def tui(stdscr):
            curses.curs_set(0)
            stdscr.keypad(True)
            pos = 0
            while True:
                stdscr.erase()
                h, w = stdscr.getmaxyx()
                title = "Выберите приложения для установки (M3 Expressive)"
                stdscr.addnstr(0, 1, title, max(1, w - 2), curses.A_BOLD)
                hint = "↑/↓ перемещение · Пробел отметить · A все · N снять · Enter установить · Q отмена"
                stdscr.addnstr(1, 1, hint, max(1, w - 2), curses.A_DIM)
                for i, a in enumerate(apps):
                    row = 3 + i
                    if row >= h - 2:
                        break
                    box = "[x]" if checked[i] else "[ ]"
                    tag = f"[{a['method']}]"
                    line = f" {box} {a['name']:<22s} {a['desc']}  {tag}"
                    attr = curses.A_REVERSE | curses.A_BOLD if i == pos else curses.A_NORMAL
                    stdscr.addnstr(row, 1, line, max(1, w - 2), attr)
                cnt = sum(checked)
                stdscr.addnstr(min(h - 1, 4 + len(apps)), 1, f"Выбрано: {cnt} из {len(apps)}", max(1, w - 2), curses.A_BOLD)
                stdscr.refresh()
                ch = stdscr.getch()
                if ch in (curses.KEY_UP, ord("k")):
                    pos = (pos - 1) % len(apps)
                elif ch in (curses.KEY_DOWN, ord("j")):
                    pos = (pos + 1) % len(apps)
                elif ch == ord(" "):
                    checked[pos] = not checked[pos]
                elif ch in (ord("a"), ord("A")):
                    checked[:] = [True] * len(apps)
                elif ch in (ord("n"), ord("N")):
                    checked[:] = [False] * len(apps)
                elif ch in (10, 13, curses.KEY_ENTER):
                    return [a["id"] for a, ok in zip(apps, checked) if ok]
                elif ch in (27, ord("q"), ord("Q")):
                    return []

        res = curses.wrapper(tui)
        os.dup2(saved_stdout, 1)
        os.close(saved_stdout)
        print(" ".join(res))
    except Exception:
        print(" ".join(fallback_menu()))
else:
    print(" ".join(fallback_menu()))
PYEOF
)"

if [[ -z "$SELECTED" ]]; then
    echo "==> Приложения не выбраны."
    exit 0
fi

echo "==> Выбрано для установки: $SELECTED"

# 1. Batch-install all selected pacman packages at once!
PACMAN_PKGS=()
for id in $SELECTED; do
    case "$id" in
        zen-browser)  PACMAN_PKGS+=(zen-browser-bin) ;;
        ayugram)      PACMAN_PKGS+=(ayugram-desktop) ;;
        vscodium)     PACMAN_PKGS+=(vscodium) ;;
        vesktop)      PACMAN_PKGS+=(vesktop-bin) ;;
        pear-desktop) PACMAN_PKGS+=(pear-desktop) ;;
        steam)        PACMAN_PKGS+=(steam) ;;
        waifu2x)      PACMAN_PKGS+=(waifu2x-ncnn-vulkan) ;;
    esac
done

if [[ "${#PACMAN_PKGS[@]}" -gt 0 ]]; then
    if [[ "${M3_FORCE_DISTRO:-}" != "fedora" && "${M3_FORCE_DISTRO:-}" != "debian" ]] && command -v pacman >/dev/null 2>&1; then
        echo "==> Установка через pacman: ${PACMAN_PKGS[*]}"
        AVAIL=(); MISSING=()
        for p in "${PACMAN_PKGS[@]}"; do
            if [[ "$DRY_RUN" -eq 1 ]] || pacman -Si "$p" >/dev/null 2>&1; then AVAIL+=("$p"); else MISSING+=("$p"); fi
        done
        [[ "${#AVAIL[@]}" -gt 0 ]] && run sudo pacman -S --needed --noconfirm "${AVAIL[@]}"
        if [[ "${#MISSING[@]}" -gt 0 ]]; then
            echo "  [INFO] Нет в pacman ($ARCH): ${MISSING[*]}"
            if command -v paru >/dev/null 2>&1; then run paru -S --needed --noconfirm "${MISSING[@]}" || true; fi
        fi
    else
        # Non-Arch distros (Fedora / Debian / Ubuntu / ARM64): install cross-arch Flatpak equivalents!
        FP_APPS=()
        for id in $SELECTED; do
            case "$id" in
                zen-browser)  FP_APPS+=(app.zen_browser.zen) ;;
                ayugram)      FP_APPS+=(com.ayugram.desktop) ;;
                vscodium)     FP_APPS+=(com.vscodium.codium) ;;
                vesktop)      FP_APPS+=(dev.vencord.Vesktop) ;;
                pear-desktop) FP_APPS+=(com.github.th_ch.youtube_music) ;;
                steam)        FP_APPS+=(com.valvesoftware.Steam) ;;
            esac
        done
        if [[ "${#FP_APPS[@]}" -gt 0 ]]; then
            echo "==> Установка кросс-архитектурных Flatpak-приложений (Flathub): ${FP_APPS[*]}"
            run flatpak install -y flathub "${FP_APPS[@]}" || true
        fi
    fi
fi

# 2. Post-setup & custom installers
for id in $SELECTED; do
    case "$id" in
        ayugram)
            echo "==> Настройка шрифта Roboto Flex + портала для AyuGram (/usr/local/bin/AyuGram)..."
            if [[ "$DRY_RUN" -eq 0 ]]; then
                sudo tee /usr/local/bin/AyuGram >/dev/null <<EOF
#!/usr/bin/env bash
export QT_QPA_PLATFORMTHEME="xdgdesktopportal"
export FONTCONFIG_FILE="$HOME/.config/fontconfig/ayugram-fonts.conf"
exec /usr/bin/AyuGram "\$@"
EOF
                sudo chmod 755 /usr/local/bin/AyuGram
            else
                echo "[dry-run] create /usr/local/bin/AyuGram wrapper"
            fi
            ;;

        gaming-stack)
            echo "==> Установка игрового стека CachyOS (Proton, UMU, GameMode, MangoHud, Gamescope)..."
            run sudo pacman -S --needed --noconfirm \
                cachyos-gaming-meta gamemode lib32-gamemode \
                mangohud lib32-mangohud gamescope \
                lib32-libpulse game-devices-udev
            if getent group gamemode >/dev/null; then
                run sudo usermod -aG gamemode "$USER"
            fi
            run systemctl --user enable --now gamemoded.service || true
            run mkdir -p "$HOME/.local/share/Steam/compatibilitytools.d" "$HOME/.steam/root/compatibilitytools.d" "$HOME/Games/Prefixes" "$HOME/Games/Downloads"
            if [[ -d /usr/share/steam/compatibilitytools.d/proton-cachyos-slr ]]; then
                run ln -sfn /usr/share/steam/compatibilitytools.d/proton-cachyos-slr "$HOME/.local/share/Steam/compatibilitytools.d/proton-cachyos-slr"
                run ln -sfn /usr/share/steam/compatibilitytools.d/proton-cachyos-slr "$HOME/.steam/root/compatibilitytools.d/proton-cachyos-slr"
            fi
            ;;

        hydralauncher)
            echo "==> Установка Hydra Launcher (последний AppImage с GitHub)..."
            if [[ "$DRY_RUN" -eq 0 ]]; then
                mkdir -p "$HOME/.local/opt/hydralauncher" "$HOME/.local/share/applications"
                URL="$(curl -fsSL https://api.github.com/repos/hydralauncher/hydra/releases/latest | python3 -c 'import sys,json; a=[x["browser_download_url"] for x in json.load(sys.stdin).get("assets",[]) if x["name"].endswith(".AppImage")]; print(a[0] if a else "")')"
                if [[ -n "$URL" ]]; then
                    curl -fL "$URL" -o "$HOME/.local/opt/hydralauncher/hydralauncher.AppImage"
                    chmod +x "$HOME/.local/opt/hydralauncher/hydralauncher.AppImage"
                    cat > "$HOME/.local/share/applications/hydralauncher.desktop" <<EOF
[Desktop Entry]
Name=Hydra Launcher
Comment=Game Launcher
Exec=$HOME/.local/opt/hydralauncher/hydralauncher.AppImage --ozone-platform-hint=auto %U
Icon=hydralauncher
Terminal=false
Type=Application
Categories=Game;
StartupWMClass=Hydra
MimeType=x-scheme-handler/hydralauncher;
EOF
                else
                    echo "  [WARN] Не удалось получить URL релиза Hydra Launcher с GitHub."
                fi
            else
                echo "[dry-run] download Hydra Launcher AppImage -> ~/.local/opt/hydralauncher/"
            fi
            ;;

        nuvio)
            echo "==> Установка Nuvio (последний AppImage с GitHub)..."
            if [[ "$DRY_RUN" -eq 0 ]]; then
                mkdir -p "$HOME/.local/opt/nuvio" "$HOME/.local/share/applications"
                URL="$(curl -fsSL https://api.github.com/repos/tapframe/NuvioStreaming/releases | python3 -c 'import sys,json; urls=[a["browser_download_url"] for r in json.load(sys.stdin) for a in r.get("assets",[]) if a["name"].endswith(".AppImage")]; print(urls[0] if urls else "")' 2>/dev/null || true)"
                if [[ -n "$URL" ]]; then
                    curl -fL "$URL" -o "$HOME/.local/opt/nuvio/nuvio.AppImage"
                    chmod +x "$HOME/.local/opt/nuvio/nuvio.AppImage"
                    cat > "$HOME/.local/share/applications/nuvio.desktop" <<EOF
[Desktop Entry]
Name=Nuvio
Comment=Media Streaming App
Exec=env _JAVA_AWT_WM_NONREPARENTING=1 $HOME/.local/opt/nuvio/nuvio.AppImage %U
Icon=nuvio
Terminal=false
Type=Application
Categories=AudioVideo;Video;
StartupWMClass=com-nuvio-app-MainKt
EOF
                else
                    echo "  [WARN] Не удалось найти AppImage Nuvio в релизах GitHub — установите вручную."
                fi
            else
                echo "[dry-run] download Nuvio AppImage -> ~/.local/opt/nuvio/"
            fi
            ;;

        termius)
            echo "==> Установка Termius (.deb -> /opt/Termius)..."
            if [[ "$DRY_RUN" -eq 0 ]]; then
                tmp_t="$(mktemp -d)"
                curl -fL "https://autoupdate.termius.com/linux/Termius.deb" -o "$tmp_t/Termius.deb"
                (cd "$tmp_t" && ar x Termius.deb && tar -xf data.tar.* -C "$tmp_t")
                sudo rm -rf /opt/Termius
                sudo cp -a "$tmp_t/opt/Termius" /opt/Termius
                sudo ln -sfn /opt/Termius/termius-app /usr/local/bin/termius
                if [[ -f "$tmp_t/usr/share/applications/termius-app.desktop" ]]; then
                    sudo install -m 644 "$tmp_t/usr/share/applications/termius-app.desktop" /usr/share/applications/termius-app.desktop
                fi
                rm -rf "$tmp_t"
            else
                echo "[dry-run] install Termius -> /opt/Termius & /usr/local/bin/termius"
            fi
            ;;

        keqdroid)
            echo "==> Установка KeqDroid (AUR keqdroid-bin)..."
            if [[ "$DRY_RUN" -eq 0 ]]; then
                if command -v paru >/dev/null 2>&1; then
                    paru -S --needed --noconfirm keqdroid-bin || true
                elif command -v yay >/dev/null 2>&1; then
                    yay -S --needed --noconfirm keqdroid-bin || true
                else
                    tmp_k="$(mktemp -d)"
                    git clone --depth 1 https://aur.archlinux.org/keqdroid-bin.git "$tmp_k/keqdroid-bin"
                    (cd "$tmp_k/keqdroid-bin" && makepkg -si --noconfirm) || true
                    rm -rf "$tmp_k"
                fi
            else
                echo "[dry-run] install keqdroid-bin from AUR"
            fi
            ;;
    esac
done

echo "==> Установка выбранных приложений завершена!"
