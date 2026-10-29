#!/usr/bin/env bash
# =============================================================================
#  QUICKSHELL MATERIAL YOU AUTO-UPDATER
#  GitHub: https://github.com/StopNope/quickshell-hyprland
# =============================================================================
set -e

REPO_URL="https://github.com/StopNope/quickshell-hyprland.git"

C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_CYAN="\033[36m"
C_RED="\033[31m"

log()  { echo -e "${C_CYAN}==>${C_RESET} ${C_BOLD}$*${C_RESET}"; }
ok()   { echo -e "${C_GREEN}[✓]${C_RESET} $*"; }
warn() { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
err()  { echo -e "${C_RED}[✗]${C_RESET} $*" >&2; }

notify() {
    local title="$1"
    local msg="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Quickshell Updater" -i "system-software-update" "$title" "$msg" 2>/dev/null || true
    fi
    if [[ -p "${XDG_RUNTIME_DIR:-/tmp}/qs.pipe" ]]; then
        echo "show_osd:update:󰚰:${title}:100" > "${XDG_RUNTIME_DIR:-/tmp}/qs.pipe" 2>/dev/null || true
    fi
}

# 1. Поиск локального репозитория quickshell
REPO_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -d "${SCRIPT_DIR}/.git" ]]; then
    REPO_DIR="${SCRIPT_DIR}"
elif [[ -d "$HOME/quickshell-hyprland/.git" ]]; then
    REPO_DIR="$HOME/quickshell-hyprland"
elif [[ -d "$HOME/.quickshell-repo/.git" ]]; then
    REPO_DIR="$HOME/.quickshell-repo"
else
    REPO_DIR="$HOME/.quickshell-repo"
    log "Клонирование репозитория в ${REPO_DIR}..."
    git clone "${REPO_URL}" "${REPO_DIR}"
fi

cd "${REPO_DIR}"
log "Проверка обновлений в репозитории (${REPO_DIR})..."
git fetch origin main --quiet

LOCAL_HASH=$(git rev-parse HEAD 2>/dev/null || echo "local")
REMOTE_HASH=$(git rev-parse origin/main 2>/dev/null || echo "remote")

FORCE_UPDATE=0
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
    FORCE_UPDATE=1
fi

if [[ "$LOCAL_HASH" == "$REMOTE_HASH" && $FORCE_UPDATE -eq 0 ]]; then
    ok "У вас уже установлена самая последняя версия Quickshell!"
    notify "Quickshell" "Конфигурация актуальна (обновлений нет)"
    exit 0
fi

log "Загрузка новых обновлений из GitHub..."
git pull origin main --quiet
ok "Репозиторий успешно обновлен!"

# 2. Обновление шрифтов
if [[ -d "${REPO_DIR}/.config/quickshell/fonts" ]]; then
    log "Синхронизация шрифтов..."
    mkdir -p "$HOME/.local/share/fonts/quickshell"
    cp -u "${REPO_DIR}/.config/quickshell/fonts/"* "$HOME/.local/share/fonts/quickshell/" 2>/dev/null || true
    fc-cache -f "$HOME/.local/share/fonts/quickshell" >/dev/null 2>&1 || true
    ok "Шрифты обновлены."
fi

# 3. Обновление Quickshell (с сохранением пользовательского config.json)
log "Обновление модулей и скриптов Quickshell..."
mkdir -p "$HOME/.config/quickshell"

# Сохраняем пользовательский config.json
if [[ -f "$HOME/.config/quickshell/config.json" ]]; then
    cp "$HOME/.config/quickshell/config.json" "$HOME/.config/quickshell/config.json.user_bak"
fi

# Копируем модули, скрипты и корневые файлы
cp -rf "${REPO_DIR}/.config/quickshell/modules" "$HOME/.config/quickshell/"
cp -rf "${REPO_DIR}/.config/quickshell/scripts" "$HOME/.config/quickshell/"
cp -f "${REPO_DIR}/.config/quickshell/shell.qml" "$HOME/.config/quickshell/"
cp -f "${REPO_DIR}/.config/quickshell/"*.py "$HOME/.config/quickshell/" 2>/dev/null || true
cp -f "${REPO_DIR}/.config/quickshell/"*.sh "$HOME/.config/quickshell/" 2>/dev/null || true

# Если у пользователя не было config.json, ставим дефолтный из репозитория
if [[ ! -f "$HOME/.config/quickshell/config.json" && -f "${REPO_DIR}/.config/quickshell/config.json" ]]; then
    cp "${REPO_DIR}/.config/quickshell/config.json" "$HOME/.config/quickshell/config.json"
fi

# Права на исполнение скриптов
chmod +x "$HOME/.config/quickshell/scripts/"*.py 2>/dev/null || true
chmod +x "$HOME/.config/quickshell/scripts/"*.sh 2>/dev/null || true
chmod +x "$HOME/.config/quickshell/"*.py 2>/dev/null || true
chmod +x "$HOME/.config/quickshell/"*.sh 2>/dev/null || true

# Копируем вспомогательный скрипт скриншотов
mkdir -p "$HOME/.local/bin"
if [[ -f "${REPO_DIR}/.local/bin/screenshot.sh" ]]; then
    cp -f "${REPO_DIR}/.local/bin/screenshot.sh" "$HOME/.local/bin/screenshot.sh"
    chmod +x "$HOME/.local/bin/screenshot.sh"
fi

# 4. Обновление интеграции кейбиндов в Hyprland
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$HYPR_LUA" && -f "${REPO_DIR}/install.sh" ]]; then
    log "Проверка блока интеграции в hyprland.lua..."
    bash "${REPO_DIR}/install.sh" --hypr-only || true
fi

# 5. Перезапуск Quickshell
log "Перезапуск Quickshell с новыми модулями..."
killall quickshell 2>/dev/null || true
sleep 1
nohup quickshell -d -p "$HOME/.config/quickshell" >/dev/null 2>&1 &
sleep 1

ok "Обновление успешно завершено!"
notify "Quickshell" "Конфигурация успешно обновлена из GitHub!"
