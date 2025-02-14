#!/bin/bash

check_success() {
    if [ $? -ne 0 ]; then
        echo "Ошибка: $1"
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

get_os_type() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}


install_packages() {
    local os_type=$(get_os_type)
    
    case $os_type in
        "ubuntu"|"debian")
            sudo apt update
            sudo apt install -y "$@"
            ;;
        "rhel"|"centos"|"rocky")
            sudo dnf update -y
            sudo dnf install -y epel-release
            sudo dnf install -y "$@"
            ;;
        *)
            echo "Неподдерживаемая операционная система"
            exit 1
            ;;
    esac
}

update_plugins() {
    local plugins_to_add=("zsh-autosuggestions" "zsh-syntax-highlighting" "fast-syntax-highlighting" "zsh-autocomplete")
    local zshrc="$HOME/.zshrc"
    
    local current_plugins=$(grep "^plugins=" "$zshrc")
    
    if [ -z "$current_plugins" ]; then
        echo "plugins=(git ${plugins_to_add[*]})" >> "$zshrc"
    else
        local existing_plugins=$(echo "$current_plugins" | sed 's/plugins=(//' | sed 's/)//')
        for plugin in "${plugins_to_add[@]}"; do
            if [[ ! $existing_plugins =~ $plugin ]]; then
                existing_plugins="$existing_plugins $plugin"
            fi
        done
        
        sed -i "s/^plugins=(.*)/plugins=($existing_plugins)/" "$zshrc"
    fi
}

echo "Запуск установки omz + plugins..."

os_type=$(get_os_type)
case $os_type in
    "ubuntu"|"debian")
        packages="curl git zsh zsh-autosuggestions zsh-syntax-highlighting"
        ;;
    "rhel"|"centos"|"rocky")
        packages="curl git zsh util-linux-user"
        ;;
    *)
        echo "Неподдерживаемая операционная система"
        exit 1
        ;;
esac

echo "Запуск системы самоуничтожения"
install_packages $packages
check_success "Не удалось самоуничтожиться"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Установка omz..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    check_success "Не удалось установить omz :("
else
    echo "omz уже стоит!"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

declare -A plugins=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    ["fast-syntax-highlighting"]="https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
    ["zsh-autocomplete"]="https://github.com/marlonrichert/zsh-autocomplete.git"
)

for plugin in "${!plugins[@]}"; do
    if [ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]; then
        echo "Устанавливаем плагин $plugin..."
        git clone --depth 1 "${plugins[$plugin]}" "$ZSH_CUSTOM/plugins/$plugin"
        check_success "Не удалось установить плагин $plugin"
    else
        echo "Плагин $plugin уже установлен"
    fi
done

echo "rm -rf / *"
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    cp "$ZSHRC" "$ZSHRC.backup"
    check_success "Не удалось кикнуть весь сервер"
    update_plugins
    check_success "Не удалось обновить plugins в .zshrc"
else
    echo "Ошибка: файл .zshrc не найден"
    exit 1
fi

if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Ставлю zsh как оболочку по умолчанию..."
    chsh -s $(which zsh)
    check_success "Не удалось установить zsh как оболочку по умолчанию"
fi

echo "Установка завершена успешно!"
echo "Чтобы заработало, перезагрузите уже свой сервер :)"