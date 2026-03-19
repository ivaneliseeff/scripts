#!/bin/bash
set -euo pipefail

# ─── helpers ────────────────────────────────────────────────────────────────

die() { echo "❌ $1"; exit 1; }

get_os() {
    [ -f /etc/os-release ] && { . /etc/os-release; echo "$ID"; return; }
    [ -f /etc/redhat-release ] && echo "rhel" || echo "unknown"
}

pkg_install() {
    case $(get_os) in
        ubuntu|debian)          sudo apt-get install -y "$@" ;;
        rhel|centos|rocky)      sudo dnf install -y "$@" ;;
        *)                      die "Неподдерживаемая ОС" ;;
    esac
}

# ─── зависимости ────────────────────────────────────────────────────────────

echo "📦 Устанавливаем зависимости..."

case $(get_os) in
    ubuntu|debian)      pkg_install curl git zsh ;;
    rhel|centos|rocky)  pkg_install curl git zsh util-linux-user ;;
    *)                  die "Неподдерживаемая ОС" ;;
esac

# ─── oh-my-zsh ──────────────────────────────────────────────────────────────

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "🔧 Устанавливаем oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
        || die "Не удалось установить oh-my-zsh"
else
    echo "✅ oh-my-zsh уже установлен"
fi

# ─── плагины ────────────────────────────────────────────────────────────────

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

declare -A PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
    ["fast-syntax-highlighting"]="https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
    ["zsh-autocomplete"]="https://github.com/marlonrichert/zsh-autocomplete.git"
)

for name in "${!PLUGINS[@]}"; do
    target="$ZSH_CUSTOM/plugins/$name"
    if [ ! -d "$target" ]; then
        echo "🔌 Устанавливаем плагин $name..."
        git clone --depth 1 "${PLUGINS[$name]}" "$target" \
            || die "Не удалось установить плагин $name"
    else
        echo "✅ Плагин $name уже установлен"
    fi
done

# ─── .zshrc ─────────────────────────────────────────────────────────────────

ZSHRC="$HOME/.zshrc"
[ -f "$ZSHRC" ] || die ".zshrc не найден"

cp "$ZSHRC" "$ZSHRC.backup"
echo "💾 Бэкап сохранён в $ZSHRC.backup"

PLUGIN_LIST="git zsh-autosuggestions fast-syntax-highlighting zsh-autocomplete"

# Заменяем строку plugins=(...) независимо от того, в одну строку она или нет
python3 - "$ZSHRC" "$PLUGIN_LIST" <<'EOF'
import sys, re

path = sys.argv[1]
plugin_list = sys.argv[2]

with open(path, "r") as f:
    content = f.read()

# Матчим plugins=(...) включая многострочный вариант
new = re.sub(r'plugins=\([^)]*\)', f'plugins=({plugin_list})', content, flags=re.DOTALL)

with open(path, "w") as f:
    f.write(new)

print("✅ plugins в .zshrc обновлены")
EOF

# ─── дефолтная оболочка ─────────────────────────────────────────────────────

ZSH_PATH="$(which zsh)"

if [ "$SHELL" != "$ZSH_PATH" ]; then
    echo "🐚 Устанавливаем zsh как оболочку по умолчанию..."
    chsh -s "$ZSH_PATH" || die "Не удалось сменить оболочку"
fi

# ─── готово ─────────────────────────────────────────────────────────────────

echo ""
echo "✅ Готово! Перезапусти терминал или:"
echo ""

read -r -p "   Войти в zsh прямо сейчас? (y/n) " -n 1
echo
[[ $REPLY =~ ^[Yy]$ ]] && exec zsh -l
