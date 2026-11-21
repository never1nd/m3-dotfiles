#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

echo "==> Syncing live M3 Expressive CachyOS + Niri desktop into $REPO_DIR ..."

rm -rf "$REPO_DIR/config" "$REPO_DIR/bin" "$REPO_DIR/wallpapers" "$REPO_DIR/fonts" "$REPO_DIR/sddm" "$REPO_DIR/zen"
mkdir -p "$REPO_DIR/config" "$REPO_DIR/bin" "$REPO_DIR/wallpapers" "$REPO_DIR/fonts" "$REPO_DIR/sddm" "$REPO_DIR/zen"

# 1. Config directories (all M3 Expressive components — zero private tokens/caches!)
CONFIG_DIRS=(
    quickshell
    niri
    m3-profiles
    kitty
    alacritty
    rofi
    hypr
    swayosd
    btop
    fastfetch
    gtk-3.0
    gtk-4.0
    qt5ct
    qt6ct
    fontconfig
    mpv
    MangoHud
    matugen
)

for d in "${CONFIG_DIRS[@]}"; do
    if [[ -d "$HOME_DIR/.config/$d" ]]; then
        cp -a "$HOME_DIR/.config/$d" "$REPO_DIR/config/$d"
    fi
done

# Fish config only (not fish_variables history)
if [[ -f "$HOME_DIR/.config/fish/config.fish" ]]; then
    mkdir -p "$REPO_DIR/config/fish"
    cp -a "$HOME_DIR/.config/fish/config.fish" "$REPO_DIR/config/fish/config.fish"
fi

# Clean any ephemeral caches inside copied configs
find "$REPO_DIR/config" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# 2. All custom M3 helper scripts from ~/.local/bin
for f in "$HOME_DIR/.local/bin"/m3-* "$HOME_DIR/.local/bin/launcher-toggle"; do
    [[ -f "$f" ]] && cp -a "$f" "$REPO_DIR/bin/"
done

# 3. Wallpapers (all 4 profiles)
if [[ -d "$HOME_DIR/Изображения/Wallpapers" ]]; then
    cp -a "$HOME_DIR/Изображения/Wallpapers/." "$REPO_DIR/wallpapers/"
fi

# 4. Bundled Roboto Flex variable font
if [[ -f "$HOME_DIR/.local/share/fonts/RobotoFlex-Variable.ttf" ]]; then
    cp -a "$HOME_DIR/.local/share/fonts/RobotoFlex-Variable.ttf" "$REPO_DIR/fonts/"
fi

# 5. Zen Browser M3 userChrome.css (CSS only — zero cookies/history/passwords!)
ZEN_CHROME="$(find "$HOME_DIR/.config/zen" -maxdepth 2 -type d -name chrome 2>/dev/null | head -n 1 || true)"
if [[ -n "$ZEN_CHROME" ]]; then
    for cf in userChrome.css m3-colors.css; do
        [[ -f "$ZEN_CHROME/$cf" ]] && cp -a "$ZEN_CHROME/$cf" "$REPO_DIR/zen/$cf"
    done
fi

# 6. Custom SDDM Material Design 3 Expressive Qt6 theme (code + metadata, background/avatar synced by m3-profile)
if [[ -d "/usr/share/sddm/themes/m3-expressive" ]]; then
    cp -a /usr/share/sddm/themes/m3-expressive/Main.qml "$REPO_DIR/sddm/"
    cp -a /usr/share/sddm/themes/m3-expressive/metadata.desktop "$REPO_DIR/sddm/"
    [[ -f /usr/share/sddm/themes/m3-expressive/theme.conf ]] && cp -a /usr/share/sddm/themes/m3-expressive/theme.conf "$REPO_DIR/sddm/"
fi

# 7. Portability: replace current user's $HOME path with __HOME__ placeholder across all text files!
python3 - "$REPO_DIR" "$HOME_DIR" <<'PYEOF'
import pathlib, sys

repo = pathlib.Path(sys.argv[1])
home_str = sys.argv[2]
text_exts = {
    ".qml", ".kdl", ".json", ".jsonc", ".conf", ".css", ".rasi", ".ini",
    ".toml", ".theme", ".fish", ".xml", ".txt", ".desktop", ".sh", ".py", ".qss", ""
}
count = 0
for sub in ("config", "bin", "sddm", "zen"):
    base = repo / sub
    if not base.exists():
        continue
    for p in base.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix.lower() not in text_exts:
            continue
        try:
            raw = p.read_bytes()
            if b"\x00" in raw:
                continue
            txt = raw.decode("utf-8")
        except Exception:
            continue
        if home_str in txt:
            p.write_text(txt.replace(home_str, "__HOME__"), encoding="utf-8")
            count += 1
print(f"    Sanitized {home_str} -> __HOME__ in {count} text files.")
PYEOF

echo "==> Sync complete! Repo size: $(du -sh "$REPO_DIR" | awk '{print $1}')"
