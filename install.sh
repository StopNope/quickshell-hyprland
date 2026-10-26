#!/usr/bin/env bash
# =============================================================================
#  QUICKSHELL MATERIAL YOU (PIXEL STYLE) FOR HYPRLAND
#  Installer & Configurator
#  GitHub: https://github.com/StopNope/quickshell-hyprland
# =============================================================================
set -e

REPO_URL="https://github.com/StopNope/quickshell-hyprland.git"
INSTALL_DIR="${HOME}/.config/quickshell"

C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_CYAN="\033[36m"
C_RED="\033[31m"
C_MAGENTA="\033[35m"

log()  { echo -e "${C_CYAN}==>${C_RESET} ${C_BOLD}$*${C_RESET}"; }
ok()   { echo -e "${C_GREEN}[✓]${C_RESET} $*"; }
warn() { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
err()  { echo -e "${C_RED}[✗]${C_RESET} $*" >&2; }

print_banner() {
    echo -e "${C_CYAN}"
    echo "  ╔════════════════════════════════════════════════════════════════════╗"
    echo "  ║                                                                    ║"
    echo "  ║         QUICKSHELL + HYPRLAND MATERIAL YOU (PIXEL STYLE)           ║"
    echo "  ║               Автоматический установщик и конфигуратор             ║"
    echo "  ║                  GitHub: StopNope/quickshell-hyprland              ║"
    echo "  ║                                                                    ║"
    echo "  ╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${C_RESET}"
}

# Функция интеграции кейбиндов и слоев в hyprland.lua
inject_hyprland_integration() {
    local hypr_dir="$HOME/.config/hypr"
    local hypr_lua="$hypr_dir/hyprland.lua"
    mkdir -p "$hypr_dir"

    log "Настройка интеграции Quickshell в hyprland.lua..."

    if [[ ! -f "$hypr_lua" ]]; then
        warn "Файл ${hypr_lua} не найден. Создаем базовый hyprland.lua..."
        touch "$hypr_lua"
    else
        # Создаем резервную копию
        local bak_file="${hypr_lua}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$hypr_lua" "$bak_file"
        ok "Создана резервная копия: $(basename "$bak_file")"
    fi

    # Читаем содержимое без старого блока quickshell-integration
    local clean_content
    clean_content=$(python3 - <<EOF
with open("$hypr_lua", "r", encoding="utf-8") as f:
    text = f.read()

start_marker = "-- >>> quickshell-integration (auto-installed) START"
end_marker = "-- <<< quickshell-integration (auto-installed) END"

if start_marker in text and end_marker in text:
    p1 = text.find(start_marker)
    p2 = text.find(end_marker) + len(end_marker)
    text = text[:p1].rstrip() + "\n" + text[p2:].lstrip()

print(text.strip())
EOF
)

    # Формируем полный блок интеграции Quickshell
    cat << 'EOF' > /tmp/qs_hypr_block.lua

-- >>> quickshell-integration (auto-installed) START
-- =============================================================================
-- 1. АВТОСТАРТ QUICKSHELL
-- =============================================================================
hl.exec_cmd("killall quickshell; quickshell -d -p " .. (os.getenv("HOME") or "") .. "/.config/quickshell")

-- =============================================================================
-- 2. ПРАВИЛА СЛОЕВ (QUICKSHELL BLUR & DOCK)
-- =============================================================================
hl.layer_rule({ match = { namespace = "quickshell" }, blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "quickshell-dock" }, no_anim = true })
hl.layer_rule({ match = { namespace = "lockscreen" }, blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true, ignore_alpha = 0.1 })

-- =============================================================================
-- 3. КЕЙБИНДЫ УПРАВЛЕНИЯ QUICKSHELL (PIXEL / MATERIAL YOU)
-- =============================================================================
local qs_mod = "SUPER"

-- Настройки (Super + G)
hl.bind(qs_mod .. " + G", hl.dsp.exec_cmd('echo "toggle_settings" > "$XDG_RUNTIME_DIR/qs.pipe"'))

-- Боковая шторка быстрых настроек (Super + U)
hl.bind(qs_mod .. " + U", hl.dsp.exec_cmd('echo "toggle_side" > "$XDG_RUNTIME_DIR/qs.pipe"'))

-- Экран блокировки (Super + L)
hl.bind(qs_mod .. " + L", hl.dsp.exec_cmd('echo "lock" > "$XDG_RUNTIME_DIR/qs.pipe"'))

-- Меню подключений WiFi (Super + N), Bluetooth (Super + B), Ethernet (Super + E)
hl.bind(qs_mod .. " + N", hl.dsp.exec_cmd('echo "toggle_menu:wifi" > "$XDG_RUNTIME_DIR/qs.pipe"'))
hl.bind(qs_mod .. " + B", hl.dsp.exec_cmd('echo "toggle_menu:bt" > "$XDG_RUNTIME_DIR/qs.pipe"'))
hl.bind(qs_mod .. " + E", hl.dsp.exec_cmd('echo "toggle_menu:eth" > "$XDG_RUNTIME_DIR/qs.pipe"'))

-- Меню поиска и лаунчер приложений (Super + R / Super + Space)
hl.bind(qs_mod .. " + R", hl.dsp.exec_cmd('echo "toggle_launcher" > "$XDG_RUNTIME_DIR/qs.pipe"'))
hl.bind(qs_mod .. " + SPACE", hl.dsp.exec_cmd('echo "toggle_launcher" > "$XDG_RUNTIME_DIR/qs.pipe"'))

-- Менеджер буфера обмена (Super + V)
hl.bind(qs_mod .. " + V", hl.dsp.exec_cmd('echo "toggle_clipboard" > "$XDG_RUNTIME_DIR/qs.pipe"'))

-- Переключатель окон Windows 11 Alt+Tab (Alt + Tab / Alt + Shift + Tab / release Alt)
hl.bind("ALT + TAB", hl.dsp.exec_cmd('echo "switcher_next" > "$XDG_RUNTIME_DIR/qs.pipe"'))
hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd('echo "switcher_prev" > "$XDG_RUNTIME_DIR/qs.pipe"'))
hl.bind("ALT_L", hl.dsp.exec_cmd('echo "switcher_commit" > "$XDG_RUNTIME_DIR/qs.pipe"'), { release = true })
hl.bind("ALT_R", hl.dsp.exec_cmd('echo "switcher_commit" > "$XDG_RUNTIME_DIR/qs.pipe"'), { release = true })

-- Интерактивный скриншот Material You (Super + Shift + S / Print)
hl.bind(qs_mod .. " + SHIFT + S", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/screenshot.sh"))
hl.bind("Print", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/screenshot.sh"))

-- =============================================================================
-- 4. БЕСКОНЕЧНЫЙ РАБОЧИЙ СТОЛ (VXWM SPATIAL MODE PER WORKSPACE)
-- =============================================================================
-- Переключение бесконечного режима на активном воркспейсе (Super + D)
hl.bind(qs_mod .. " + D", hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py toggle"))

-- Ограничение окна монитором (Super + Shift + D)
hl.bind(qs_mod .. " + SHIFT + D", hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py toggle_clamp"))

-- Панорамирование холста (Super + Ctrl + Стрелки)
hl.bind(qs_mod .. " + CTRL + left",  hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py pan 250 0"),  { repeating = true })
hl.bind(qs_mod .. " + CTRL + right", hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py pan -250 0"), { repeating = true })
hl.bind(qs_mod .. " + CTRL + up",    hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py pan 0 200"),   { repeating = true })
hl.bind(qs_mod .. " + CTRL + down",  hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py pan 0 -200"),  { repeating = true })

-- Панорамирование колесиком мыши (Super + Wheel / Super + Shift + Wheel)
hl.bind(qs_mod .. " + mouse_up",   hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py pan 0 160"))
hl.bind(qs_mod .. " + mouse_down", hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py pan 0 -160"))
hl.bind(qs_mod .. " + SHIFT + mouse_up",   hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py pan 180 0"))
hl.bind(qs_mod .. " + SHIFT + mouse_down", hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py pan -180 0"))

-- Масштабирование холста (Super + = / Super + - / Super + 0)
hl.bind(qs_mod .. " + equal",       hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py zoom_in"))
hl.bind(qs_mod .. " + minus",       hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py zoom_out"))
hl.bind(qs_mod .. " + 0",           hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py zoom_reset"))
hl.bind(qs_mod .. " + ALT + mouse_up",   hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py zoom_in"))
hl.bind(qs_mod .. " + ALT + mouse_down", hl.dsp.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/quickshell/scripts/vxwm_controller.py zoom_out"))
-- <<< quickshell-integration (auto-installed) END
EOF

    echo "$clean_content" > "$hypr_lua"
    cat /tmp/qs_hypr_block.lua >> "$hypr_lua"
    rm -f /tmp/qs_hypr_block.lua
    ok "Блок интеграции Quickshell успешно внедрен в конец hyprland.lua!"
}

# Если вызвано с флагом --hypr-only (для скрипта updater)
if [[ "${1:-}" == "--hypr-only" ]]; then
    inject_hyprland_integration
    exit 0
fi

print_banner

# 1. Определение директории репозитория
SCRIPT_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR=""

if [[ -d "${SCRIPT_SOURCE}/.config/quickshell" ]]; then
    SOURCE_DIR="${SCRIPT_SOURCE}"
else
    CLONE_DIR="${HOME}/.quickshell-repo"
    log "Клонирование репозитория StopNope/quickshell-hyprland..."
    mkdir -p "${CLONE_DIR}"
    if [[ ! -d "${CLONE_DIR}/.git" ]]; then
        git clone "${REPO_URL}" "${CLONE_DIR}"
    else
        git -C "${CLONE_DIR}" pull origin main
    fi
    SOURCE_DIR="${CLONE_DIR}"
fi

# 2. Проверка зависимостей
log "Проверка установленных системных компонентов..."
MISSING_PKGS=()

for cmd in hyprland python3 jq grim slurp wl-copy; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_PKGS+=("$cmd")
    fi
done

if ! command -v quickshell >/dev/null 2>&1; then
    warn "Quickshell не обнаружен в PATH! Убедитесь, что Quickshell установлен (https://quickshell.outfoxxed.me)."
fi

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    warn "Рекомендуемые утилиты не найдены: ${MISSING_PKGS[*]}"
    echo -e "  Установите их через ваш пакетный менеджер (pacman, dnf, apt, emerge)."
fi

# 3. Установка шрифтов
if [[ -d "${SOURCE_DIR}/.config/quickshell/fonts" ]]; then
    log "Установка шрифтов в ~/.local/share/fonts/quickshell..."
    mkdir -p "$HOME/.local/share/fonts/quickshell"
    cp -r "${SOURCE_DIR}/.config/quickshell/fonts/"* "$HOME/.local/share/fonts/quickshell/"
    fc-cache -f "$HOME/.local/share/fonts/quickshell" >/dev/null 2>&1 || true
    ok "Шрифты установлены и кэшированы."
fi

# 4. Установка дефолтных обоев
if [[ -d "${SOURCE_DIR}/wallpaper" ]]; then
    log "Проверка наличия обоев..."
    mkdir -p "$HOME/wallpaper"
    if [[ ! -f "$HOME/wallpaper/default.jpg" ]]; then
        cp -n "${SOURCE_DIR}/wallpaper/"* "$HOME/wallpaper/" 2>/dev/null || true
        ok "Минималистичные обои установлены в ~/wallpaper."
    fi
fi

# 5. Установка конфигурации Quickshell
log "Установка Quickshell в ~/.config/quickshell..."
mkdir -p "$HOME/.config"

if [[ -d "$HOME/.config/quickshell" ]]; then
    if [[ -f "$HOME/.config/quickshell/config.json" ]]; then
        cp "$HOME/.config/quickshell/config.json" /tmp/qs_config_user.json 2>/dev/null || true
    fi
    BACKUP_QS="$HOME/.config/quickshell.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HOME/.config/quickshell" "$BACKUP_QS"
    ok "Старая папка quickshell сохранена в: $(basename "$BACKUP_QS")"
fi

mkdir -p "$HOME/.config/quickshell"
cp -r "${SOURCE_DIR}/.config/quickshell/"* "$HOME/.config/quickshell/"

# Если у пользователя был сохраненный config.json, возвращаем его
if [[ -f /tmp/qs_config_user.json ]]; then
    mv /tmp/qs_config_user.json "$HOME/.config/quickshell/config.json"
    ok "Пользовательские настройки и темы (config.json) бережно сохранены."
fi

# Права на исполнение скриптов Quickshell
chmod +x "$HOME/.config/quickshell/scripts/"*.py 2>/dev/null || true
chmod +x "$HOME/.config/quickshell/scripts/"*.sh 2>/dev/null || true
chmod +x "$HOME/.config/quickshell/"*.py 2>/dev/null || true
chmod +x "$HOME/.config/quickshell/"*.sh 2>/dev/null || true

# 6. Установка скрипта скриншотов
mkdir -p "$HOME/.local/bin"
if [[ -f "${SOURCE_DIR}/.local/bin/screenshot.sh" ]]; then
    cp -f "${SOURCE_DIR}/.local/bin/screenshot.sh" "$HOME/.local/bin/screenshot.sh"
    chmod +x "$HOME/.local/bin/screenshot.sh"
    ok "Скрипт скриншотов установлен в ~/.local/bin/screenshot.sh."
fi

# 6.1 Установка шейдеров Hyprland (ночной свет)
if [[ -d "${SOURCE_DIR}/.config/hypr/shaders" ]]; then
    mkdir -p "$HOME/.config/hypr/shaders"
    cp -r "${SOURCE_DIR}/.config/hypr/shaders/"* "$HOME/.config/hypr/shaders/" 2>/dev/null || true
    ok "Шейдеры экрана Hyprland (ночной свет) установлены в ~/.config/hypr/shaders."
fi

# 7. Установка скрипта автообновления
log "Настройка утилиты автообновления..."
cp -f "${SOURCE_DIR}/update.sh" "$HOME/.config/quickshell/scripts/updater.sh"
chmod +x "$HOME/.config/quickshell/scripts/updater.sh"
ln -sf "$HOME/.config/quickshell/scripts/updater.sh" "$HOME/.local/bin/quickshell-update"
ok "Утилита обновления доступна по команде: quickshell-update"

# 8. Внедрение интеграции в hyprland.lua
inject_hyprland_integration

# 9. Перезапуск Quickshell
log "Запуск Quickshell..."
killall quickshell 2>/dev/null || true
sleep 1
nohup quickshell -d -p "$HOME/.config/quickshell" >/dev/null 2>&1 &
sleep 1

echo -e "\n${C_GREEN}${C_BOLD}════════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}  УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!  ${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}════════════════════════════════════════════════════════════════════${C_RESET}\n"

echo -e "Горячие клавиши для управления Quickshell:"
echo -e "  • ${C_CYAN}Super + G${C_RESET}       — Настройки системы, бара, дока и виджетов"
echo -e "  • ${C_CYAN}Super + U${C_RESET}       — Боковая шторка быстрых переключателей (SidePanel)"
echo -e "  • ${C_CYAN}Super + L${C_RESET}       — Экран блокировки Material You"
echo -e "  • ${C_CYAN}Super + R / Space${C_RESET}— Поиск и лаунчер приложений"
echo -e "  • ${C_CYAN}Super + V${C_RESET}       — Менеджер буфера обмена"
echo -e "  • ${C_CYAN}Alt + Tab${C_RESET}       — Переключатель окон Windows 11 с превью"
echo -e "  • ${C_CYAN}Super + Shift + S${C_RESET}— Инструмент скриншотов с редактором"
echo -e "  • ${C_CYAN}Super + D${C_RESET}       — Бесконечный рабочий стол (пространственный режим)"
echo -e "  • ${C_CYAN}Super + Ctrl + Стрелки${C_RESET} — Перемещение по бесконечному холсту"
echo -e "\nДля обновления конфигурации в будущем просто выполните: ${C_YELLOW}quickshell-update${C_RESET}\n"
