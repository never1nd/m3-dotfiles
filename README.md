# Material Design 3 Expressive Dotfiles (Niri + Quickshell)

Универсальная портативная сборка **Niri + Quickshell** в стиле **Material Design 3 Expressive** — работает на **`x86_64`** (Intel/AMD) и **`ARM64 / aarch64`** (Apple Silicon Asahi, Snapdragon, ARM-ноутбуки), на дискретных и встроенных GPU (**NVIDIA, AMD, Intel, ARM SoC**).

### Что внутри
- **Оболочка Quickshell (100% без привязки к архитектуре):** навбар, единый док, Центр управления Android 16 PC, 10 попапов, 6-вкладочные настройки, нативные уведомления (`NotificationsOverlay.qml` вместо `swaync`), виджет музыки с волной и текстом, настольный терминал (автовыравнивание под любую ширину экрана).
- **4 полных профиля (`Ctrl + Alt + 1..4`):** **Фиолетовый**, **Синий**, **Зеленый** (светлый), **Оранжевый** — обои, портрет терминала, палитра, иконки `Tela-circle-*`, тема AyuGram, подсветка `gnome-text-editor` и экран входа **SDDM Qt6**.
- **Адаптация под железо:** яркость автоматически работает через `brightnessctl` на ноутбуке и `ddcutil` на внешнем мониторе; мониторинг GPU (`m3-sysmon-json`) поддерживает NVIDIA (`nvidia-smi`), AMD/Intel (`/sys/class/drm`) и ARM SoC; `display.kdl` не затирает настройки чужого экрана.

---

## Команды развёртывания под разные системы и архитектуры

### 1. CachyOS / Arch Linux (`x86_64` — ПК или ноутбук)
Полная автоматическая установка одной командой (включая удаление Noctalia и интерактивный выбор приложений):
```bash
sudo pacman -S --needed github-cli
gh auth login
gh repo clone never1nd/m3-dotfiles ~/m3-dotfiles
cd ~/m3-dotfiles
./install.sh
```
Сразу с игровым стеком (`Proton-CachyOS`, `UMU`, `GameMode`, `MangoHud`, `Gamescope`):
```bash
./install.sh --gaming
```

### 2. Arch Linux ARM / Asahi Alarm (`aarch64` — ARM-ноутбук)
```bash
sudo pacman -S --needed git github-cli
gh auth login
gh repo clone never1nd/m3-dotfiles ~/m3-dotfiles
cd ~/m3-dotfiles
./install.sh
```
*На `aarch64` установщик автоматически пропустит x86-only пакеты, поставит совместимые ARM-пакеты из `pacman`/`paru` и отфильтрует список приложений в `install-apps.sh` под ARM64. Если `niri`/`quickshell`/`matugen`/`awww` отсутствуют в репах ARM, доустанови их через `paru` или `cargo install matugen`.*

### 3. Fedora / Fedora Asahi Remix (`x86_64` и `aarch64` — включая Apple Silicon M1/M2/M3)
```bash
sudo dnf install -y gh git
sudo dnf copr enable -y yalter/niri
sudo dnf copr enable -y errornointernet/quickshell
gh auth login
gh repo clone never1nd/m3-dotfiles ~/m3-dotfiles
cd ~/m3-dotfiles
./install.sh
```
*Для `matugen` и `awww` на Fedora: `cargo install matugen` (или бинарник с GitHub Releases) и `sudo dnf install -y quickshell awww cliphist` (если подключён COPR).*

### 4. Ubuntu / Debian (`x86_64` и `aarch64`)
```bash
sudo apt update && sudo apt install -y gh git
gh auth login
gh repo clone never1nd/m3-dotfiles ~/m3-dotfiles
cd ~/m3-dotfiles
./install.sh
```
*Затем при необходимости поставь свежие `niri`, `quickshell`, `matugen`, `awww` и `cliphist` из GitHub Releases / `cargo` и выполни `~/.local/bin/m3-profile violet`.*

### 5. Любой другой Linux (NixOS, Void, Gentoo, Alpine и т.д. — только конфиги и темы)
Установи `niri`, `quickshell`, `matugen`, `awww`, `kitty`, `rofi`, `fastfetch`, `fish`, `grim`, `slurp`, `wl-clipboard`, `cliphist`, `brightnessctl` средствами своего дистрибутива, а затем разверни конфиги без трогания пакетного менеджера:
```bash
./install.sh --no-packages --no-apps
```

---

## Интерактивная установка приложений (`apps.json` / `install-apps.sh`)
В конце `./install.sh` откроется меню с чекбоксами (`↑/↓`, `Пробел`, `A` все, `N` снять, `Enter` старт). На ARM64 автоматически скрываются x86-only пакеты (`Steam`, `Proton`, `Hydra`, `Termius`, `KeqDroid`).

Отдельный запуск в любой момент:
```bash
./install-apps.sh
```

## Как обновлять бэкап после новых правок
```bash
cd ~/m3-dotfiles && ./sync.sh && git add -A && git commit -m "Update M3 setup" && git push
```
