#!/bin/bash

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
            VER=$VERSION_ID
        # ubuntu
        elif type lsb_release >/dev/null 2>&1; then
            OS=$(lsb_release -si)
            VER=$(lsb_release -sr)
        # debian
        elif [ -f /etc/lsb-release ]; then
            . /etc/lsb-release
            OS=$DISTRIB_ID
            VER=$DISTRIB_RELEASE
        # debian
        elif [ -f /etc/debian_version ]; then
            OS=Debian
            VER=$(cat /etc/debian_version)
        # redhat
        elif [ -f /etc/redhat-release ]; then
            OS=RedHat
            VER=$(cat /etc/redhat-release)
        # unknown
        else
            OS=$(uname -s)
            VER=$(uname -r)
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
        VER=$(sw_vers -productVersion)
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        OS="Windows"
        VER="Cygwin"
    elif [[ "$OSTYPE" == "msys" ]]; then
        OS="Windows"
        VER="MSYS"
    elif [[ "$OSTYPE" == "win32" ]]; then
        OS="Windows"
        VER="Win32"
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        OS="FreeBSD"
        VER=$(uname -r)
    else
        OS="Unknown"
        VER="Unknown"
    fi
    
    echo "Обнаружена ОС: $OS $VER"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_deps_ubuntu() {
    echo "Установка зависимостей"
    
    if command_exists sudo; then
        sudo apt-get update
    else
        apt-get update
    fi
    
    local packages="curl wget gnupg2 software-properties-common apt-transport-https ca-certificates"
    
    if command_exists sudo; then
        sudo apt-get install -y $packages
    else
        apt-get install -y $packages
    fi
}

install_deps_redhat() {
    echo "Установка зависимостей"
    
    if command_exists dnf; then
        PKG_MANAGER="dnf"
    elif command_exists yum; then
        PKG_MANAGER="yum"
    else
        echo "Не найден пакетный менеджер"
        exit 1
    fi
    
    local packages="curl wget gnupg2 ca-certificates"
    
    if command_exists sudo; then
        sudo $PKG_MANAGER install -y $packages
    else
        $PKG_MANAGER install -y $packages
    fi
}

install_macos() {
    if command_exists brew; then
        echo "Используем Homebrew для установки..."
        brew install yandex-cloud-cli
        return 0
    fi
    
    echo "Homebrew не найден, устанавливаем вручную..."
    
    ARCH=$(uname -m)

    if [[ "$ARCH" == "arm64" ]]; then
        DOWNLOAD_URL="https://storage.yandexcloud.net/yandexcloud-yc/release/0.149.0/darwin/arm64/yc"
    else
        DOWNLOAD_URL="https://storage.yandexcloud.net/yandexcloud-yc/release/0.149.0/darwin/amd64/yc"
    fi
    
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    
    echo "Скачивание yc CLI..."
    curl -sSL "$DOWNLOAD_URL" -o "$INSTALL_DIR/yc"
    chmod +x "$INSTALL_DIR/yc"
    
    add_to_path "$INSTALL_DIR"
}

install_ubuntu() {
    install_deps_ubuntu
    
    curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
    
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc"
    fi
}

install_redhat() {
    install_deps_redhat
    
    curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
    
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc"
    fi
}
install_windows() {
    if [[ $(uname -m) == "x86_64" ]]; then
        ARCH="amd64"
    else
        ARCH="386"
    fi
    
    DOWNLOAD_URL="https://storage.yandexcloud.net/yandexcloud-yc/release/0.149.0/windows/$ARCH/yc.exe"
    
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    
    echo "Скачивание yc CLI..."
    if command_exists curl; then
        curl -sSL "$DOWNLOAD_URL" -o "$INSTALL_DIR/yc.exe"
    elif command_exists wget; then
        wget -q "$DOWNLOAD_URL" -O "$INSTALL_DIR/yc.exe"
    else
        echo "Не найден curl или wget для скачивания"
        exit 1
    fi
    
    chmod +x "$INSTALL_DIR/yc.exe"
    
    add_to_path "$INSTALL_DIR"
}

add_to_path() {
    local dir="$1"
    local shell_rc=""
    
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.profile"
    fi
    
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        echo "Добавление $dir в PATH..."
        echo "export PATH=\"$dir:\$PATH\"" >> "$shell_rc"
        export PATH="$dir:$PATH"
        echo "Путь добавлен в $shell_rc"
    else
        echo "Путь $dir уже есть в PATH"
    fi
}

verify_installation() {
    echo "Проверка установки..."
    
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
    fi
    if [ -f "$HOME/.zshrc" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
    fi
    
    if command_exists yc; then
        local version=$(yc version 2>/dev/null || echo "unknown")
        echo "Yandex Cloud CLI установлен"
        echo "Версия: $version"
        return 0
    else
        echo "Установка не удалась или yc не найден в PATH"
        echo "Попробуйте перезапустить терминал или выполнить:"
        echo "  source ~/.bashrc"
        echo "  # или"
        echo "  source ~/.zshrc"
        return 1
    fi
}

main() {
    echo "Yandex Cloud CLI Installer"
    
    detect_os
    
    if command_exists yc; then
        local version=$(yc version 2>/dev/null || echo "unknown")
        echo "Yandex Cloud CLI уже установлен (версия: $version)"
        read -p "Хотите переустановить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Установка отменена"
            exit 0
        fi
    fi

    echo "Установка Yandex Cloud CLI"
    
    case "$OS" in
        "Ubuntu"|"Debian"*|"Linux Mint")
            install_ubuntu
            ;;
        "Red Hat"*|"CentOS"*|"Fedora"*|"Rocky"*|"AlmaLinux"*)
            install_redhat
            ;;
        "macOS")
            install_macos
            ;;
        "Windows")
            install_windows
            ;;
        *)
            echo "Неизвестная ОС: $OS"
            echo "Попытка универсальной установки..."
            
            if command_exists curl; then
                curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
            else
                echo "Не удалось определить способ установки для вашей ОС"
                echo "Попробуйте установить вручную:"
                echo "  https://cloud.yandex.ru/docs/cli/quickstart"
                exit 1
            fi
            ;;
    esac
    
    echo ""
    verify_installation
}

main "$@" 
