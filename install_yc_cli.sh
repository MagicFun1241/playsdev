#!/bin/bash

# Yandex Cloud CLI Installer
# Универсальный скрипт установки для Linux, macOS и Windows (WSL/Git Bash)
# Автоматически определяет операционную систему и устанавливает соответствующую версию

set -e  # Выход при любой ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для цветного вывода
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Функция для определения операционной системы
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
            VER=$VERSION_ID
        elif type lsb_release >/dev/null 2>&1; then
            OS=$(lsb_release -si)
            VER=$(lsb_release -sr)
        elif [ -f /etc/lsb-release ]; then
            . /etc/lsb-release
            OS=$DISTRIB_ID
            VER=$DISTRIB_RELEASE
        elif [ -f /etc/debian_version ]; then
            OS=Debian
            VER=$(cat /etc/debian_version)
        elif [ -f /etc/redhat-release ]; then
            OS=RedHat
            VER=$(cat /etc/redhat-release)
        else
            OS=$(uname -s)
            VER=$(uname -r)
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        OS="macOS"
        VER=$(sw_vers -productVersion)
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        # POSIX compatibility layer and Linux environment emulation for Windows
        OS="Windows"
        VER="Cygwin"
    elif [[ "$OSTYPE" == "msys" ]]; then
        # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
        OS="Windows"
        VER="MSYS"
    elif [[ "$OSTYPE" == "win32" ]]; then
        # I'm not sure this can happen.
        OS="Windows"
        VER="Win32"
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        # FreeBSD
        OS="FreeBSD"
        VER=$(uname -r)
    else
        # Unknown.
        OS="Unknown"
        VER="Unknown"
    fi
    
    print_info "Обнаружена ОС: $OS $VER"
}

# Функция проверки наличия команды
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Функция для установки зависимостей на Ubuntu/Debian
install_deps_ubuntu() {
    print_info "Установка зависимостей для Ubuntu/Debian..."
    
    # Обновляем список пакетов
    if command_exists sudo; then
        sudo apt-get update
    else
        apt-get update
    fi
    
    # Устанавливаем необходимые пакеты
    local packages="curl wget gnupg2 software-properties-common apt-transport-https ca-certificates"
    
    if command_exists sudo; then
        sudo apt-get install -y $packages
    else
        apt-get install -y $packages
    fi
}

# Функция для установки зависимостей на RedHat/CentOS/Fedora
install_deps_redhat() {
    print_info "Установка зависимостей для RedHat/CentOS/Fedora..."
    
    # Определяем пакетный менеджер
    if command_exists dnf; then
        PKG_MANAGER="dnf"
    elif command_exists yum; then
        PKG_MANAGER="yum"
    else
        print_error "Не найден пакетный менеджер (yum/dnf)"
        exit 1
    fi
    
    # Устанавливаем необходимые пакеты
    local packages="curl wget gnupg2 ca-certificates"
    
    if command_exists sudo; then
        sudo $PKG_MANAGER install -y $packages
    else
        $PKG_MANAGER install -y $packages
    fi
}

# Функция для установки на macOS
install_macos() {
    print_info "Установка Yandex Cloud CLI на macOS..."
    
    # Проверяем наличие Homebrew
    if command_exists brew; then
        print_info "Используем Homebrew для установки..."
        brew install yandex-cloud-cli
        return 0
    fi
    
    # Если Homebrew нет, устанавливаем вручную
    print_info "Homebrew не найден, устанавливаем вручную..."
    
    # Определяем архитектуру
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        DOWNLOAD_URL="https://storage.yandexcloud.net/yandexcloud-yc/release/0.112.0/darwin/arm64/yc"
    else
        DOWNLOAD_URL="https://storage.yandexcloud.net/yandexcloud-yc/release/0.112.0/darwin/amd64/yc"
    fi
    
    # Создаем директорию для установки
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    
    # Скачиваем и устанавливаем
    print_info "Скачивание yc CLI..."
    curl -sSL "$DOWNLOAD_URL" -o "$INSTALL_DIR/yc"
    chmod +x "$INSTALL_DIR/yc"
    
    # Добавляем в PATH
    add_to_path "$INSTALL_DIR"
}

# Функция для установки на Ubuntu/Debian
install_ubuntu() {
    print_info "Установка Yandex Cloud CLI на Ubuntu/Debian..."
    
    # Устанавливаем зависимости
    install_deps_ubuntu
    
    # Добавляем репозиторий Yandex Cloud
    curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
    
    # Перезагружаем профиль
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc"
    fi
}

# Функция для установки на RedHat/CentOS/Fedora
install_redhat() {
    print_info "Установка Yandex Cloud CLI на RedHat/CentOS/Fedora..."
    
    # Устанавливаем зависимости
    install_deps_redhat
    
    # Используем универсальный установщик
    curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
    
    # Перезагружаем профиль
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc"
    fi
}

# Функция для установки на Windows (WSL/Git Bash/MSYS)
install_windows() {
    print_info "Установка Yandex Cloud CLI на Windows..."
    
    # Определяем архитектуру
    if [[ $(uname -m) == "x86_64" ]]; then
        ARCH="amd64"
    else
        ARCH="386"
    fi
    
    # URL для скачивания
    DOWNLOAD_URL="https://storage.yandexcloud.net/yandexcloud-yc/release/0.112.0/windows/$ARCH/yc.exe"
    
    # Создаем директорию для установки
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    
    # Скачиваем и устанавливаем
    print_info "Скачивание yc CLI..."
    if command_exists curl; then
        curl -sSL "$DOWNLOAD_URL" -o "$INSTALL_DIR/yc.exe"
    elif command_exists wget; then
        wget -q "$DOWNLOAD_URL" -O "$INSTALL_DIR/yc.exe"
    else
        print_error "Не найден curl или wget для скачивания"
        exit 1
    fi
    
    chmod +x "$INSTALL_DIR/yc.exe"
    
    # Добавляем в PATH
    add_to_path "$INSTALL_DIR"
}

# Функция для добавления директории в PATH
add_to_path() {
    local dir="$1"
    local shell_rc=""
    
    # Определяем файл конфигурации shell
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.profile"
    fi
    
    # Проверяем, есть ли уже путь в PATH
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        print_info "Добавление $dir в PATH..."
        echo "export PATH=\"$dir:\$PATH\"" >> "$shell_rc"
        export PATH="$dir:$PATH"
        print_success "Путь добавлен в $shell_rc"
    else
        print_info "Путь $dir уже есть в PATH"
    fi
}

# Функция для проверки установки
verify_installation() {
    print_info "Проверка установки..."
    
    # Обновляем PATH для текущей сессии
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
    fi
    if [ -f "$HOME/.zshrc" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
    fi
    
    # Проверяем команду yc
    if command_exists yc; then
        local version=$(yc version 2>/dev/null || echo "unknown")
        print_success "Yandex Cloud CLI установлен успешно!"
        print_info "Версия: $version"
        
        print_info "Для начала работы выполните:"
        echo "  yc init"
        echo ""
        print_info "Или установите токен и folder-id:"
        echo "  export YC_TOKEN=your_token"
        echo "  export YC_FOLDER_ID=your_folder_id"
        
        return 0
    else
        print_error "Установка не удалась или yc не найден в PATH"
        print_warning "Попробуйте перезапустить терминал или выполнить:"
        echo "  source ~/.bashrc"
        echo "  # или"
        echo "  source ~/.zshrc"
        return 1
    fi
}

# Главная функция
main() {
    echo "🌩️  Yandex Cloud CLI Installer"
    echo "=================================="
    echo ""
    
    # Определяем ОС
    detect_os
    
    # Проверяем, не установлен ли уже yc
    if command_exists yc; then
        local version=$(yc version 2>/dev/null || echo "unknown")
        print_warning "Yandex Cloud CLI уже установлен (версия: $version)"
        read -p "Хотите переустановить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Установка отменена"
            exit 0
        fi
    fi
    
    # Устанавливаем в зависимости от ОС
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
            print_warning "Неизвестная ОС: $OS"
            print_info "Попытка универсальной установки..."
            
            # Универсальная установка через скрипт
            if command_exists curl; then
                curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
            else
                print_error "Не удалось определить способ установки для вашей ОС"
                print_info "Попробуйте установить вручную:"
                echo "  https://cloud.yandex.ru/docs/cli/quickstart"
                exit 1
            fi
            ;;
    esac
    
    echo ""
    verify_installation
}

# Запуск основной функции
main "$@" 