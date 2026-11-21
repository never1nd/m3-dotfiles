#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PKGS=1
INSTALL_GAMING=0
CLEAN_NOCTALIA=1
KEEP_DISPLAY=1
TARGET_PROFILE="violet"
DRY_RUN=0
APPS_MODE="ask"

usage() {
    cat <<'EOF'
Material Design 3 Expressive (CachyOS + Niri) Installer

Использование:
  ./install.sh [опции]

Опции:
  --gaming           Дополнительно установить игровой стек CachyOS (Proton, UMU, GameMode, MangoHud, Gamescope)
  --keep-noctalia    Не удалять Noctalia (по умолчанию Noctalia удаляется автоматически)
  --no-packages      Пропустить установку пакетов pacman (только развернуть конфиги и темы)
  --overwrite-display Перезаписать ~/.config/niri/cfg/display.kdl конфигом из репо (осторожно на ноутбуках!)
  --profile NAME     Стартовый профиль: violet | blue | forest | peach (по умолчанию: violet)
  --all-apps         Автоматически установить все приложения из apps.json без вопроса
  --no-apps          Пропустить вопрос об установке доп. приложений
  --dry-run          Показать шаги без внесения изменений
  -h, --help         Показать справку
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --gaming) INSTALL_GAMING=1 ;;
        --clean-noctalia) CLEAN_NOCTALIA=1 ;;
        --keep-noctalia) CLEAN_NOCTALIA=0 ;;
        --no-packages) INSTALL_PKGS=0 ;;
        --overwrite-display) KEEP_DISPLAY=0 ;;
        --profile) TARGET_PROFILE="${2:-violet}"; shift ;;
        --all-apps) APPS_MODE="all" ;;
        --no-apps) APPS_MODE="skip" ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Неизвестная опция: $1"; usage; exit 1 ;;
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

echo "============================================================"
echo "  Material Design 3 Expressive Desktop Installer (CachyOS)"
echo "  Target HOME: $HOME  |  Profile: $TARGET_PROFILE"
echo "============================================================"

if [[ "$DRY_RUN" -eq 0 ]]; then
    sudo -v
fi

# 1. Remove Noctalia & legacy shell clutter by default (use --keep-noctalia to skip)
if [[ "$CLEAN_NOCTALIA" -eq 1 ]]; then
    echo "==> [1/8] Removing Noctalia & legacy clutter if installed..."
    run pkill -x waybar 2>/dev/null || true
    run pkill -x swaync 2>/dev/null || true
    for pkg in cachyos-niri-noctalia noctalia-shell noctalia noctalia-qs; do
        if pacman -Qi "$pkg" >/dev/null 2>&1; then
            run sudo pacman -Rns --noconfirm "$pkg" || sudo pacman -Rdd --noconfirm "$pkg" || true
        fi
    done
    run rm -rf "$HOME/.config/noctalia" "$HOME/.cache/noctalia" "$HOME/.local/share/noctalia" "$HOME/.config/quickshell/noctalia"*
fi

# 2. Core packages
if [[ "$INSTALL_PKGS" -eq 1 ]]; then
    echo "==> [2/8] Installing Material Design 3 Expressive stack via pacman..."
    CORE_PKGS=(
        niri quickshell matugen awww
        rofi swayosd hyprlock hypridle wlsunset
        kitty alacritty fish btop fastfetch
        cliphist wl-clipboard grim slurp ffmpeg
        ddcutil brightnessctl polkit-gnome
        adw-gtk-theme qt5ct qt6ct
        loupe celluloid mpv gnome-text-editor
        ttf-jetbrains-mono-nerd ttf-material-symbols-variable
        python-pillow gpu-screen-recorder
    )
    run sudo pacman -S --needed --noconfirm "${CORE_PKGS[@]}"

    if [[ "$INSTALL_GAMING" -eq 1 ]]; then
        echo "==> Installing CachyOS Gaming stack..."
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
    fi
fi

# 3. Fonts, Bibata-Modern-Ice cursor & Tela-circle icon themes (purple, nord, orange, green)
echo "==> [3/8] Installing Roboto Flex font, Bibata-Modern-Ice cursor & Tela-circle icons..."
run mkdir -p "$HOME/.local/share/fonts"
if [[ -f "$REPO_DIR/fonts/RobotoFlex-Variable.ttf" ]]; then
    run cp -f "$REPO_DIR/fonts/RobotoFlex-Variable.ttf" "$HOME/.local/share/fonts/"
fi
run fc-cache -f || true

if [[ ! -d "/usr/share/icons/Bibata-Modern-Ice" && ! -d "$HOME/.local/share/icons/Bibata-Modern-Ice" ]]; then
    if [[ "$DRY_RUN" -eq 0 ]]; then
        tmp_cur="$(mktemp -d)"
        curl -fsSL "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz" -o "$tmp_cur/bibata.tar.xz" \
            && sudo tar -xf "$tmp_cur/bibata.tar.xz" -C /usr/share/icons/ || true
        rm -rf "$tmp_cur"
    else
        echo "[dry-run] download Bibata-Modern-Ice -> /usr/share/icons/"
    fi
fi

MISSING_TELA=()
for color in purple nord orange green; do
    [[ -d "/usr/share/icons/Tela-circle-${color}-dark" ]] || MISSING_TELA+=("$color")
done
if [[ "${#MISSING_TELA[@]}" -gt 0 ]]; then
    if [[ "$DRY_RUN" -eq 0 ]]; then
        tmp_ic="$(mktemp -d)"
        git clone --depth 1 https://github.com/vinceliuice/Tela-circle-icon-theme.git "$tmp_ic/tela"
        (cd "$tmp_ic/tela" && sudo ./install.sh -d /usr/share/icons "${MISSING_TELA[@]}")
        rm -rf "$tmp_ic"
    else
        echo "[dry-run] install Tela-circle (${MISSING_TELA[*]})"
    fi
fi

# 4. Deploy configs, scripts, wallpapers & substitute __HOME__ -> $HOME
echo "==> [4/8] Deploying configs, Quickshell, Niri, profiles, scripts & wallpapers..."
if [[ "$DRY_RUN" -eq 0 ]]; then
    BACKUP_DIR="$HOME/.config-backup-m3-$(date +%Y%m%d-%H%M%S)"
    EXISTING_DISPLAY=""
    if [[ "$KEEP_DISPLAY" -eq 1 && -f "$HOME/.config/niri/cfg/display.kdl" ]]; then
        EXISTING_DISPLAY="$(cat "$HOME/.config/niri/cfg/display.kdl")"
    fi

    mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/Изображения/Wallpapers" "$BACKUP_DIR"

    for d in "$REPO_DIR/config"/*; do
        name="$(basename "$d")"
        if [[ "$name" == "fish" ]]; then
            mkdir -p "$HOME/.config/fish"
            cp -a "$d/config.fish" "$HOME/.config/fish/config.fish"
            continue
        fi
        if [[ -d "$HOME/.config/$name" ]]; then
            cp -a "$HOME/.config/$name" "$BACKUP_DIR/$name" 2>/dev/null || true
        fi
        rm -rf "$HOME/.config/$name"
        cp -a "$d" "$HOME/.config/$name"
    done

    # Smart display.kdl preservation for laptops / different monitors!
    if [[ "$KEEP_DISPLAY" -eq 1 ]]; then
        if [[ -n "$EXISTING_DISPLAY" ]]; then
            printf '%s\n' "$EXISTING_DISPLAY" > "$HOME/.config/niri/cfg/display.kdl"
        else
            cat > "$HOME/.config/niri/cfg/display.kdl" <<'EOF'
// Auto-detected display configuration (edit with `niri msg outputs` if needed)
EOF
        fi
    fi

    # Deploy helper scripts
    cp -a "$REPO_DIR/bin/." "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin"/m3-* "$HOME/.local/bin/launcher-toggle" 2>/dev/null || true

    # Deploy wallpapers
    cp -a "$REPO_DIR/wallpapers/." "$HOME/Изображения/Wallpapers/"

    # Deploy Zen Browser userChrome.css if Zen profile exists
    if [[ -d "$HOME/.config/zen" ]]; then
        for prof in "$HOME/.config/zen"/*; do
            if [[ -f "$prof/prefs.js" ]]; then
                mkdir -p "$prof/chrome"
                [[ -f "$REPO_DIR/zen/userChrome.css" ]] && cp -a "$REPO_DIR/zen/userChrome.css" "$prof/chrome/"
                [[ -f "$REPO_DIR/zen/m3-colors.css" ]] && cp -a "$REPO_DIR/zen/m3-colors.css" "$prof/chrome/"
            fi
        done
    fi

    # Substitute __HOME__ -> target user's $HOME across all deployed text files
    python3 - "$HOME" <<'PYEOF'
import pathlib, sys
home = pathlib.Path(sys.argv[1])
home_str = str(home)
targets = [
    home / ".config/quickshell",
    home / ".config/niri",
    home / ".config/m3-profiles",
    home / ".config/fastfetch",
    home / ".config/kitty",
    home / ".config/alacritty",
    home / ".config/rofi",
    home / ".config/hypr",
    home / ".config/swayosd",
    home / ".config/btop",
    home / ".config/gtk-3.0",
    home / ".config/gtk-4.0",
    home / ".config/qt5ct",
    home / ".config/qt6ct",
    home / ".config/fontconfig",
    home / ".config/mpv",
    home / ".config/MangoHud",
    home / ".local/bin",
]
n = 0
for base in targets:
    if not base.exists():
        continue
    for p in base.rglob("*"):
        if not p.is_file():
            continue
        try:
            raw = p.read_bytes()
            if b"\x00" in raw or b"__HOME__" not in raw:
                continue
            txt = raw.decode("utf-8")
            p.write_text(txt.replace("__HOME__", home_str), encoding="utf-8")
            n += 1
        except Exception:
            pass
print(f"    Patched __HOME__ -> {home_str} in {n} files (backup in {home_str}/.config-backup-m3-*)")
PYEOF
else
    echo "[dry-run] deploy configs, scripts, wallpapers & patch __HOME__ -> $HOME"
fi

# 5. Hardware DDC/CI brightness udev rules (harmless on laptops, enables desktop monitor brightness!)
echo "==> [5/8] Setting up DDC/CI i2c-dev rules (desktop monitors) & video/i2c groups..."
if [[ "$DRY_RUN" -eq 0 ]]; then
    echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
    sudo tee /etc/udev/rules.d/45-ddcutil-i2c.rules >/dev/null <<'EOF'
SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"
EOF
    sudo groupadd -f i2c
    sudo usermod -aG i2c,video "$USER" || true
    sudo modprobe i2c-dev 2>/dev/null || true
    sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=i2c-dev || true
else
    echo "[dry-run] configure /etc/modules-load.d/i2c-dev.conf + udev rule"
fi

# 6. SDDM Material Design 3 Expressive Qt6 login theme
echo "==> [6/8] Installing Material Design 3 Expressive SDDM Qt6 theme..."
if [[ "$DRY_RUN" -eq 0 && -f "$REPO_DIR/sddm/Main.qml" ]]; then
    sudo mkdir -p /usr/share/sddm/themes/m3-expressive /etc/sddm.conf.d
    sudo install -m 644 "$REPO_DIR/sddm/Main.qml" /usr/share/sddm/themes/m3-expressive/Main.qml
    sudo install -m 644 "$REPO_DIR/sddm/metadata.desktop" /usr/share/sddm/themes/m3-expressive/metadata.desktop
    sudo touch /usr/share/sddm/themes/m3-expressive/theme.conf /usr/share/sddm/themes/m3-expressive/background.jpg /usr/share/sddm/themes/m3-expressive/avatar.png
    sudo chown "$USER:$USER" /usr/share/sddm/themes/m3-expressive/theme.conf /usr/share/sddm/themes/m3-expressive/background.jpg /usr/share/sddm/themes/m3-expressive/avatar.png
    sudo chmod 644 /usr/share/sddm/themes/m3-expressive/theme.conf /usr/share/sddm/themes/m3-expressive/background.jpg /usr/share/sddm/themes/m3-expressive/avatar.png
    sudo tee /etc/sddm.conf.d/10-m3-expressive.conf >/dev/null <<'EOF'
[Theme]
Current=m3-expressive
CursorTheme=Bibata-Modern-Ice
CursorSize=24
Font=Roboto Flex,10,-1,5,400,0,0,0,0,0
EOF
else
    echo "[dry-run] install /usr/share/sddm/themes/m3-expressive + /etc/sddm.conf.d/10-m3-expressive.conf"
fi

# 7. Default MIME associations, gsettings (TextEditor, Celluloid) & mask swaync
echo "==> [7/8] Configuring XDG-MIME defaults, gsettings & native Quickshell notifications..."
if [[ "$DRY_RUN" -eq 0 ]]; then
    systemctl --user stop swaync.service 2>/dev/null || true
    systemctl --user mask swaync.service 2>/dev/null || true

    xdg-mime default org.gnome.Loupe.desktop \
        image/png image/jpeg image/jpg image/webp image/gif image/svg+xml \
        image/bmp image/tiff image/avif image/jxl image/heif image/heic image/x-icon || true
    xdg-mime default io.github.celluloid_player.Celluloid.desktop \
        video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo \
        video/x-flv video/mpeg video/ogg video/mp2t video/3gpp video/x-ms-wmv || true
    xdg-mime default org.gnome.TextEditor.desktop \
        text/plain text/markdown text/x-markdown text/x-readme text/x-log \
        application/json application/x-yaml text/yaml text/x-toml application/toml \
        text/xml text/csv text/x-ini text/x-shellscript || true

    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.TextEditor style-scheme 'm3-expressive' || true
        gsettings set org.gnome.TextEditor style-variant 'follow' || true
        gsettings set org.gnome.TextEditor recolor-window true || true
        gsettings set org.gnome.TextEditor use-system-font false || true
        gsettings set org.gnome.TextEditor custom-font 'JetBrainsMono Nerd Font 11' || true
        gsettings set org.gnome.TextEditor line-height 1.35 || true
        gsettings set org.gnome.TextEditor highlight-current-line true || true
        gsettings set org.gnome.TextEditor show-line-numbers true || true
        gsettings set org.gnome.TextEditor wrap-text true || true
        gsettings set org.gnome.TextEditor restore-session false || true
        gsettings set org.gnome.TextEditor spellcheck false || true

        gsettings set io.github.celluloid-player.Celluloid csd-enable true || true
        gsettings set io.github.celluloid-player.Celluloid always-use-floating-controls true || true
        gsettings set io.github.celluloid-player.Celluloid always-show-title-buttons false || true
        gsettings set io.github.celluloid-player.Celluloid mpris-enable true || true
        gsettings set io.github.celluloid-player.Celluloid inhibit-idle true || true
        gsettings set io.github.celluloid-player.Celluloid mpv-config-enable true || true
        gsettings set io.github.celluloid-player.Celluloid mpv-config-file "file://$HOME/.config/mpv/mpv.conf" || true
    fi
else
    echo "[dry-run] set xdg-mime, gsettings, mask swaync.service"
fi

# 8. Apply initial M3 Expressive profile (syncs Quickshell, Niri, GTK/Qt, Kitty, SDDM, AyuGram, TextEditor!)
echo "==> [8/8] Applying profile '$TARGET_PROFILE'..."
if [[ "$DRY_RUN" -eq 0 ]]; then
    "$HOME/.local/bin/m3-profile" "$TARGET_PROFILE" --silent --no-wallpaper || true
    if command -v niri >/dev/null 2>&1 && [[ -n "${NIRI_SOCKET:-}" ]]; then
        niri msg action load-config-file 2>/dev/null || true
    fi
else
    echo "[dry-run] m3-profile $TARGET_PROFILE"
fi

# 9. Optional interactive selection of user desktop apps (apps.json)
if [[ "$APPS_MODE" != "skip" && -x "$REPO_DIR/install-apps.sh" ]]; then
    APP_ARGS=()
    [[ "$APPS_MODE" == "all" ]] && APP_ARGS+=(--all)
    [[ "$DRY_RUN" -eq 1 ]] && APP_ARGS+=(--dry-run)
    "$REPO_DIR/install-apps.sh" "${APP_ARGS[@]}"
fi

echo ""
echo "============================================================"
echo "  Готово! Перезайди в сессию Niri (или перезагрузи ПК),"
echo "  чтобы применились группы (i2c/gamemode), SDDM и оболочка."
echo "  Профили: Ctrl+Alt+1..4 (Фиолетовый / Синий / Зеленый / Оранжевый)"
echo "============================================================"
