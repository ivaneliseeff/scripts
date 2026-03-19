#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/zsh-setup.log"
> "$LOG_FILE"

# ─── helpers ────────────────────────────────────────────────────────────────

die() { echo "❌ $1"; exit 1; }

get_os() {
    [ -f /etc/os-release ] && { . /etc/os-release; echo "$ID"; return; }
    [ -f /etc/redhat-release ] && echo "rhel" || echo "unknown"
}

# Спиннер: run_silent "Сообщение" команда [аргументы...]
run_silent() {
    local msg="$1"; shift
    printf "  %s..." "$msg"

    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    "$@" >> "$LOG_FILE" 2>&1 &
    local pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  %s... %s" "$msg" "${spin:$((i % ${#spin})):1}"
        i=$((i + 1))
        sleep 0.1
    done

    wait "$pid" && printf "\r  ✅ %s   \n" "$msg" \
                || { printf "\r  ❌ %s (см. %s)\n" "$msg" "$LOG_FILE"; exit 1; }
}

pkg_install() {
    case $(get_os) in
        ubuntu|debian)      sudo apt-get install -y "$@" ;;
        rhel|centos|rocky)  sudo dnf install -y "$@" ;;
        *)                  die "Неподдерживаемая ОС" ;;
    esac
}

# ─── зависимости ────────────────────────────────────────────────────────────

echo "📦 Зависимости"
case $(get_os) in
    ubuntu|debian)      run_silent "curl git zsh" pkg_install curl git zsh ;;
    rhel|centos|rocky)  run_silent "curl git zsh" pkg_install curl git zsh util-linux-user ;;
    *)                  die "Неподдерживаемая ОС" ;;
esac

# ─── oh-my-zsh ──────────────────────────────────────────────────────────────

echo ""
echo "🔧 oh-my-zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    run_silent "Установка" \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "  ✅ Уже установлен"
fi

# ─── плагины ────────────────────────────────────────────────────────────────

echo ""
echo "🔌 Плагины"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

declare -A PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
    ["fast-syntax-highlighting"]="https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
    ["zsh-autocomplete"]="https://github.com/marlonrichert/zsh-autocomplete.git"
)

for name in "${!PLUGINS[@]}"; do
    target="$ZSH_CUSTOM/plugins/$name"
    if [ ! -d "$target" ]; then
        run_silent "$name" git clone --depth 1 "${PLUGINS[$name]}" "$target"
    else
        echo "  ✅ $name уже установлен"
    fi
done

# ─── .zshrc ─────────────────────────────────────────────────────────────────

echo ""
echo "⚙️  .zshrc"

ZSHRC="$HOME/.zshrc"
[ -f "$ZSHRC" ] || die ".zshrc не найден"

cp "$ZSHRC" "$ZSHRC.backup"

PLUGIN_LIST="git zsh-autosuggestions fast-syntax-highlighting zsh-autocomplete"

python3 - "$ZSHRC" "$PLUGIN_LIST" <<'EOF'
import sys, re
path, plugin_list = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
new = re.sub(r'plugins=\([^)]*\)', f'plugins=({plugin_list})', content, flags=re.DOTALL)
with open(path, "w") as f:
    f.write(new)
EOF

echo "  ✅ plugins обновлены"

# ─── дефолтная оболочка ─────────────────────────────────────────────────────

ZSH_PATH="$(which zsh)"
if [ "$SHELL" != "$ZSH_PATH" ]; then
    run_silent "Смена оболочки на zsh" sudo usermod -s "$ZSH_PATH" "$USER"
fi

# ─── готово ─────────────────────────────────────────────────────────────────

echo ""
echo "✅ Готово!"
echo ""

read -r -p "   Войти в zsh прямо сейчас? (y/n) " -n 1
echo
[[ $REPLY =~ ^[Yy]$ ]] && exec zsh -l
