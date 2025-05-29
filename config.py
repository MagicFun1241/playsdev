#!/usr/bin/env python3

import os

class Config:
    def __init__(self):
        self.token = None
        self.folder_id = None
        self.subnet_id = None
        self.zone_id = "ru-central1-b"
        self.platform_id = "standard-v2"
        
        self.default_memory = 1 * 1024 * 1024 * 1024  # 1GB
        self.default_cores = 2
        self.default_core_fraction = 5  # 5%
        self.default_disk_size = 10 * 1024 * 1024 * 1024
        self.default_disk_type = "network-hdd"
        self.default_image_id = "fd8kdq6d0p8sij7h5qe3"
        
        self.ssh_username = "magicfun"
        self.default_ssh_key_path = os.path.expanduser("~/.ssh/id_rsa.pub")
        self.ssh_timeout = 30
        
    def load_config(self):
        try:
            self.token = os.getenv('YC_TOKEN')
            
            if not self.token:
                token_file = os.path.expanduser('~/.config/yandex-cloud/config.yaml')
                if os.path.exists(token_file):
                    import yaml
                    with open(token_file, 'r') as f:
                        config = yaml.safe_load(f)
                        self.token = config.get('token')
            
            if not self.token:
                raise ValueError("Токен не найден. Установите YC_TOKEN или настройте ~/.config/yandex-cloud/config.yaml")
            
            self.folder_id = os.getenv('YC_FOLDER_ID')
            if not self.folder_id:
                raise ValueError("Не указан YC_FOLDER_ID")
            
            self.subnet_id = os.getenv('YC_SUBNET_ID')
            if not self.subnet_id:
                raise ValueError("Не указан YC_SUBNET_ID")
            
            zone_from_env = os.getenv('YC_ZONE_ID')
            
            if zone_from_env:
                self.zone_id = zone_from_env
                print(f"Используется зона из переменной окружения: {self.zone_id}")
            else:
                print(f"Используется зона по умолчанию: {self.zone_id}")
                
            return True
            
        except Exception as e:
            print(f"Ошибка загрузки конфигурации: {e}")
            return False
    
    def get_default_ssh_key(self):
        try:
            if os.path.exists(self.default_ssh_key_path):
                with open(self.default_ssh_key_path, 'r') as f:
                    return f.read().strip()
            else:
                raise FileNotFoundError("SSH ключ не найден. Создайте ключ: ssh-keygen -t rsa")
        except Exception as e:
            print(f"Ошибка чтения SSH ключа: {e}")
            return None 