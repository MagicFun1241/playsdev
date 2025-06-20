# Task 15 - Docker Deployment with Ansible

Автоматическое развертывание Docker и запуск multi-container приложения на Ubuntu и Fedora серверах с помощью Ansible.

## Описание

Проект включает:
- Установку Docker на Ubuntu (apt) и Fedora (dnf)
- Развертывание multi-container приложения с nginx, apache и fallback-nginx
- Использование Ansible ролей и условий для разных ОС
- Docker Compose для оркестрации контейнеров

## Структура проекта

```
task-15/
├── ansible.cfg              # Конфигурация Ansible
├── inventory.yml            # Инвентарь серверов
├── site.yml                # Основной playbook
├── requirements.yml         # Ansible коллекции
├── deploy.sh               # Скрипт развертывания
├── compose.yml             # Docker Compose конфигурация
├── build-and-push.sh       # Сборка и публикация образов
├── roles/
│   ├── docker_install/     # Роль установки Docker
│   │   ├── tasks/main.yml
│   │   ├── vars/Debian.yml
│   │   ├── vars/RedHat.yml
│   │   └── handlers/main.yml
│   └── docker_container/   # Роль управления контейнерами
│       └── tasks/main.yml
├── nginx/                  # Конфигурация nginx
├── apache/                 # Конфигурация apache
└── fallback-nginx/         # Конфигурация fallback nginx
```

## Серверы

- **Ubuntu**: 89.169.177.211 (пользователь: magicfun)
- **Fedora**: 89.169.184.219 (пользователь: magicfun)

## Использование

### 1. Подготовка

Убедитесь, что у вас установлен Ansible:

```bash
# Ubuntu/Debian
sudo apt install ansible

# Fedora
sudo dnf install ansible

# macOS
brew install ansible
```

### 2. Настройка SSH

Настройте SSH доступ к серверам:

```bash
# Добавьте ваш публичный ключ на серверы
ssh-copy-id magicfun@89.169.177.211  # Ubuntu
ssh-copy-id magicfun@89.169.184.219  # Fedora
```

### 3. Развертывание

Запустите развертывание:

```bash
cd task-15
./deploy.sh
```

Скрипт выполнит:
- Установку необходимых Ansible коллекций
- Развертывание Docker на оба сервера
- Запуск multi-container приложения
- Проверку статуса контейнеров

### 4. Проверка

После развертывания проверьте сервисы:

```bash
# Ubuntu сервер
curl http://89.169.177.211        # nginx (порт 80)
curl http://89.169.177.211:8090   # apache (порт 8090)
curl http://89.169.177.211:8080   # fallback-nginx (порт 8080)

# Fedora сервер
curl http://89.169.184.219        # nginx (порт 80)
curl http://89.169.184.219:8090   # apache (порт 8090)
curl http://89.169.184.219:8080   # fallback-nginx (порт 8080)
```

## Особенности реализации

### Роли Ansible

1. **docker_install**: Установка Docker с учетом ОС
   - Ubuntu/Debian: использует apt пакетный менеджер
   - Fedora/RedHat: использует dnf пакетный менеджер
   - Устанавливает Python библиотеки для работы с Docker

2. **docker_container**: Управление контейнерами
   - Использует docker_compose_v2 модуль
   - Копирует compose.yml на сервер
   - Запускает multi-container приложение

### Условия в playbook

```yaml
when: ansible_os_family == "Debian"   # Для Ubuntu
when: ansible_os_family == "RedHat"   # Для Fedora
```

### Docker Compose

Приложение состоит из трех сервисов:
- **nginx**: Основной веб-сервер (порт 80)
- **apache**: PHP сервер (порт 8090)
- **fallback-nginx**: Резервный сервер (порт 8080)

## Troubleshooting

### Проблемы с SSH

```bash
# Проверка подключения
ansible all -i inventory.yml -m ping

# Проверка с дебагом
ansible-playbook -i inventory.yml site.yml -vvv
```

### Проблемы с Docker

```bash
# Проверка статуса Docker
ansible docker_servers -i inventory.yml -m shell -a "systemctl status docker" --become

# Проверка логов
ansible docker_servers -i inventory.yml -m shell -a "journalctl -u docker --no-pager" --become
```

### Проверка контейнеров

```bash
# Список контейнеров
ansible docker_servers -i inventory.yml -m shell -a "docker ps -a" --become

# Логи контейнеров
ansible docker_servers -i inventory.yml -m shell -a "docker-compose -f /opt/playsdev/compose.yml logs" --become
``` 