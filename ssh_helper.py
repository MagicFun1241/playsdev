#!/usr/bin/env python3

import os
import time
import paramiko

class SSHHelper:
    def __init__(self, config):
        self.config = config
    
    def test_ssh_connection(self, public_ip, private_key_path=None, vm_already_started=False):
        try:
            if not public_ip:
                print("Публичный IP не найден")
                return False
                
            if not private_key_path:
                private_key_path = self.config.default_ssh_key_path.replace('.pub', '')
                
            print(f"\nТестирование SSH подключения к {public_ip}...")
            
            if not vm_already_started:
                print("Ожидание загрузки VM...")
                time.sleep(30)
            
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            try:
                ssh.connect(
                    hostname=public_ip,
                    username=self.config.ssh_username,
                    key_filename=private_key_path,
                    timeout=self.config.ssh_timeout
                )
                
                stdin, stdout, stderr = ssh.exec_command('whoami')
                output = stdout.read().decode().strip()
                
                print("SSH подключение успешно!")
                print(f"Результат команды:\n{output}")
                
                ssh.close()
                return True
                
            except Exception as e:
                print(f"Ошибка SSH подключения: {e}")
                return False
                
        except Exception as e:
            print(f"Ошибка тестирования SSH: {e}")
            return False
    
    def get_ssh_key_from_file(self, key_path=None):
        try:
            if not key_path:
                key_path = self.config.default_ssh_key_path
            else:
                key_path = os.path.expanduser(key_path)
                
            if not os.path.exists(key_path):
                raise FileNotFoundError(f"Файл {key_path} не найден")
                
            with open(key_path, 'r') as f:
                return f.read().strip()
                
        except Exception as e:
            print(f"Ошибка чтения SSH ключа: {e}")
            return None
    
    def format_ssh_metadata(self, ssh_key):
        return f"{self.config.ssh_username}:{ssh_key}"
    
    def generate_user_data(self, ssh_key):
        return f"""#cloud-config
users:
  - name: {self.config.ssh_username}
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - {ssh_key}
    lock_passwd: false

runcmd:
  - systemctl enable ssh
  - systemctl start ssh
  - mkdir -p /home/{self.config.ssh_username}/.ssh
  - chmod 700 /home/{self.config.ssh_username}/.ssh
  - chown {self.config.ssh_username}:{self.config.ssh_username} /home/{self.config.ssh_username}/.ssh
""" 