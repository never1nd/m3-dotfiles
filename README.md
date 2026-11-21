# Material Design 3 Expressive Dotfiles (CachyOS + Niri)

Полная портативная сборка окружения **CachyOS + Niri** в стиле **Material Design 3 Expressive**:
- Нативная оболочка **Quickshell** (навбар, единый док, Центр управления Android 16 PC, 10 попапов, 6-вкладочные настройки, нативные уведомления без `swaync`, виджет музыки с волной и синхронным текстом, виджет терминала).
- **4 полных профиля** (`Ctrl + Alt + 1..4` или меню «Кастомизация»): **Фиолетовый**, **Синий**, **Зеленый** (светлый), **Оранжевый** — каждый со своими обоями, портретом в терминале, палитрой, иконками `Tela-circle-*`, темой AyuGram и экраном входа SDDM.
- Плавные анимации **Niri** без бекджампа, умная навигация (`m3-nav-lr`), курсор `Bibata-Modern-Ice`, вариативный шрифт `Roboto Flex` + `Material Symbols Rounded`.
- Адаптация **GTK3/4, Qt5/6, Kitty, Alacritty, Rofi, SwayOSD, Hyprlock, btop, Zen Browser, mpv/Celluloid, Loupe, gnome-text-editor** (с живой подсветкой M3) и **SDDM Qt6**.
- Умная поддержка ноутбуков и ПК: яркость автоматически работает через `brightnessctl` на ноутбуке и через `ddcutil` (DDC/CI) на внешнем мониторе; `display.kdl` не затирает экран другого ПК.

---

## Развернуть на новом ПК / ноутбуке (CachyOS + Niri)

```bash
git clone <URL_ТВОЕГО_РЕПОЗИТОРИЯ> ~/m3-dotfiles
cd ~/m3-dotfiles
./install.sh
```

Полезные флаги:
- `./install.sh --gaming` — сразу поставить и игровой стек CachyOS (`proton-cachyos-slr`, `umu-launcher`, `gamemode`, `mangohud`, `gamescope`, `lib32-libpulse`, `game-devices-udev`).
- По умолчанию `./install.sh` **сам удаляет Noctalia** (`cachyos-niri-noctalia`, `noctalia-shell`, `noctalia`, её конфиги и кэши) и отключает `swaync`. Если нужно оставить Noctalia, добавь флаг `--keep-noctalia`.
- `./install.sh --profile blue` — сразу активировать нужный профиль (`violet` / `blue` / `forest` / `peach`).
- `./install.sh --dry-run` — посмотреть план установки без изменений.

---

## Как обновлять бэкап после новых правок на этом ПК

```bash
cd ~/m3-dotfiles
./sync.sh
git add -A
git commit -m "Update M3 Expressive setup"
git push
```

Личные данные, токены, куки, пароли, история чатов и SSH-ключи в репозиторий **не попадают**.

---

## Интерактивная установка приложений (`apps.json` / `install-apps.sh`)

В конце `./install.sh` установщик спросит: **«Хотите установить ваши приложения?»** и откроет интерактивное меню с чекбоксами (`↑/↓` выбор, `Пробел` отметить, `A` выбрать все, `N` снять все, `Enter` начать установку).

Список вынесен в `apps.json` (12 приложений):
`Zen Browser`, `AyuGram Desktop`, `VSCodium`, `Vesktop`, `Pear Desktop`, `Steam`, `Игровой стек CachyOS`, `Hydra Launcher`, `Nuvio`, `Termius`, `KeqDroid`, `waifu2x-ncnn-vulkan`.

Можно также запускать выбор приложений отдельно в любой момент:
```bash
./install-apps.sh
```
