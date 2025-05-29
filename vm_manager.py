#!/usr/bin/env python3

import os
import time
import yandexcloud
import paramiko

from yandex.cloud.compute.v1.instance_service_pb2 import (
    CreateInstanceRequest, 
    GetInstanceRequest,
    DeleteInstanceRequest,
    ListInstancesRequest
)

from yandex.cloud.compute.v1.instance_service_pb2_grpc import InstanceServiceStub
from yandex.cloud.operation.operation_service_pb2_grpc import OperationServiceStub
from yandex.cloud.operation.operation_service_pb2 import GetOperationRequest

from config import Config
from ssh_helper import SSHHelper

class YandexCloudVMManager:
    def __init__(self):
        self.config = Config()
        self.ssh_helper = SSHHelper(self.config)
        self.sdk = None
        self.instance_id = None
        self.public_ip = None
        
    def initialize_sdk(self):
        try:
            if not self.config.load_config():
                return False
                
            self.sdk = yandexcloud.SDK(token=self.config.token)
            return True
            
        except Exception as e:
            print(f"Ошибка инициализации SDK: {e}")
            return False
    
    def create_vm(self, vm_name=None):
        try:
            print("\nСоздание новой VM...")
            
            if not vm_name:
                vm_name = input("Введите имя VM (по умолчанию: test-vm): ").strip() or "test-vm"
            
            instance_service = self.sdk.client(InstanceServiceStub)
            
            ssh_key = self.config.get_default_ssh_key()
            if not ssh_key:
                return False
            
            user_data = self.ssh_helper.generate_user_data(ssh_key)
            
            print(f"Создание пользователя: {self.config.ssh_username}")
            
            request = CreateInstanceRequest(
                folder_id=self.config.folder_id,
                name=vm_name,
                description="VM created by Python script",
                zone_id=self.config.zone_id,
                platform_id=self.config.platform_id,
                resources_spec={
                    "memory": self.config.default_memory,
                    "cores": self.config.default_cores,
                    "core_fraction": self.config.default_core_fraction
                },
                boot_disk_spec={
                    "mode": "READ_WRITE",
                    "disk_spec": {
                        "type_id": self.config.default_disk_type,
                        "size": self.config.default_disk_size,
                        "image_id": self.config.default_image_id
                    }
                },
                network_interface_specs=[{
                    "subnet_id": self.config.subnet_id,
                    "primary_v4_address_spec": {
                        "one_to_one_nat_spec": {
                            "ip_version": "IPV4"
                        }
                    }
                }],
                metadata={
                    "ssh-keys": self.ssh_helper.format_ssh_metadata(ssh_key),
                    "user-data": user_data
                }
            )
            
            operation = instance_service.Create(request)
            print(f"Операция создания запущена: {operation.id}")
            
            if not self._wait_for_operation(operation.id, "Ожидание создания VM..."):
                return False
                
            operation = self._get_operation(operation.id)
            
            # Parse the protobuf response to get the instance ID
            from yandex.cloud.compute.v1.instance_pb2 import Instance
            instance_response = Instance()
            instance_response.ParseFromString(operation.response.value)
            self.instance_id = instance_response.id
            
            print(f"VM создана успешно! ID: {self.instance_id}")
            
            self.get_vm_info()
            return True
            
        except Exception as e:
            print(f"Ошибка создания VM: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def get_vm_info(self):
        try:
            if not self._ensure_vm_selected():
                return False
                
            instance_service = self.sdk.client(InstanceServiceStub)
            request = GetInstanceRequest(instance_id=self.instance_id)
            instance = instance_service.Get(request)
            
            print(f"\nИнформация о VM:")
            print(f"  ID: {instance.id}")
            print(f"  Имя: {instance.name}")
            print(f"  Статус: {instance.status}")
            print(f"  Зона: {instance.zone_id}")
            print(f"  Платформа: {instance.platform_id}")
            print(f"  Ядра: {instance.resources.cores}")
            print(f"  Память: {instance.resources.memory // (1024**3)} GB")
            print(f"  Диск: {instance.resources.core_fraction}%")
            
            for interface in instance.network_interfaces:
                print(f"  Внутренний IP: {interface.primary_v4_address.address}")
                if interface.primary_v4_address.one_to_one_nat:
                    self.public_ip = interface.primary_v4_address.one_to_one_nat.address
                    print(f"  Публичный IP: {self.public_ip}")
            
            print(f"  Создана: {instance.created_at}")
            
            return True
            
        except Exception as e:
            print(f"Ошибка получения информации о VM: {e}")
            return False
    
    def _ssh_execute_command(self, command, private_key_path=None):
        try:
            if not self.public_ip:
                print("Публичный IP не найден")
                return None, None
                
            if not private_key_path:
                private_key_path = self.config.default_ssh_key_path.replace('.pub', '')
                
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            ssh.connect(
                hostname=self.public_ip,
                username=self.config.ssh_username,
                key_filename=private_key_path,
                timeout=self.config.ssh_timeout
            )
            
            stdin, stdout, stderr = ssh.exec_command(command)
            output = stdout.read().decode().strip()
            error = stderr.read().decode().strip()
            
            ssh.close()
            return output, error
            
        except Exception as e:
            print(f"Ошибка выполнения SSH команды: {e}")
            return None, str(e)
    
    def update_ssh_key(self, key_path=None):
        try:
            if not self._ensure_vm_selected():
                return False
                
            print(f"\nДобавление SSH ключа для VM: {self.instance_id}")
            
            if not self.public_ip:
                self.get_vm_info()
                
            if not self.public_ip:
                print("Публичный IP не найден. Не удается подключиться к VM.")
                return False
            
            if not key_path:
                key_path = input("Введите путь к новому публичному SSH ключу (по умолчанию: ~/.ssh/id_rsa.pub): ").strip()
                if not key_path:
                    key_path = self.config.default_ssh_key_path
            
            new_ssh_key = self.ssh_helper.get_ssh_key_from_file(key_path)
            if not new_ssh_key:
                return False
            
            print("Подключение к VM для добавления SSH ключа...")
            
            instance_service = self.sdk.client(InstanceServiceStub)
            get_request = GetInstanceRequest(instance_id=self.instance_id)
            instance = instance_service.Get(get_request)
            
            if instance.status != 2:
                print("VM не запущена. Для добавления SSH ключа VM должна быть запущена.")
                return False
            
            private_key_path = os.path.expanduser(key_path.replace('.pub', '')) if key_path.endswith('.pub') else os.path.expanduser(key_path)
            existing_private_key_path = self.config.default_ssh_key_path.replace('.pub', '')
            
            print("Подключение с существующим ключом...")
            
            output, error = self._ssh_execute_command("mkdir -p ~/.ssh && chmod 700 ~/.ssh", existing_private_key_path)
            if error and "mkdir" in error:
                print(f"Предупреждение при создании директории .ssh: {error}")
            
            output, error = self._ssh_execute_command("cat ~/.ssh/authorized_keys 2>/dev/null || echo ''", existing_private_key_path)
            if error and "cat" not in error.lower():
                print(f"Ошибка чтения authorized_keys: {error}")
                return False
            
            current_keys = output if output else ""
            print(f"Найдено существующих ключей: {len(current_keys.splitlines()) if current_keys else 0}")
            
            if new_ssh_key in current_keys:
                print("Этот SSH ключ уже существует в authorized_keys")
                return True
            
            escaped_key = new_ssh_key.replace("'", "'\"'\"'")  # Убераем одинарные кавычки
            append_command = f"echo '{escaped_key}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
            
            output, error = self._ssh_execute_command(append_command, existing_private_key_path)
            if error:
                print(f"Ошибка добавления ключа: {error}")
                return False
            
            print("SSH ключ успешно добавлен в ~/.ssh/authorized_keys!")
            
            print("Тестирование подключения с новым ключом...")
            return self.ssh_helper.test_ssh_connection(self.public_ip, private_key_path, vm_already_started=True)
            
        except Exception as e:
            print(f"Ошибка добавления SSH ключа: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def delete_vm(self):
        try:
            if not self._ensure_vm_selected():
                return False
                
            confirm = input(f"Вы уверены, что хотите удалить VM {self.instance_id}? (y/N): ").strip().lower()
            if confirm != 'y':
                print("Удаление отменено")
                return False
                
            print("\nНачинаем удаление VM")
            
            instance_service = self.sdk.client(InstanceServiceStub)
            request = DeleteInstanceRequest(instance_id=self.instance_id)
            operation = instance_service.Delete(request)
            
            if not self._wait_for_operation(operation.id, "Удаление в работе..."):
                return False
                
            print("VM удалена успешно!")
            self.instance_id = None
            self.public_ip = None
            return True
            
        except Exception as e:
            print(f"Ошибка удаления VM: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def list_vms(self):
        try:
            print("\nСписок VM:")
            
            instance_service = self.sdk.client(InstanceServiceStub)
            request = ListInstancesRequest(folder_id=self.config.folder_id)
            response = instance_service.List(request)
            
            if not response.instances:
                print("VM не найдены")
                return True
                
            for i, vm in enumerate(response.instances, 1):
                status_text = self._get_status_text(vm.status)
                print(f"  {i}. {vm.name} ({vm.id}) - {status_text}")
                
            choice = input("\nВыберите номер VM для работы (Enter - пропустить): ").strip()
            if choice.isdigit() and 1 <= int(choice) <= len(response.instances):
                selected_vm = response.instances[int(choice) - 1]
                self.instance_id = selected_vm.id
                print(f"Выбрана VM: {selected_vm.name}")
                
                for interface in selected_vm.network_interfaces:
                    if interface.primary_v4_address.one_to_one_nat:
                        self.public_ip = interface.primary_v4_address.one_to_one_nat.address
                        break
                
            return True
            
        except Exception as e:
            print(f"Ошибка получения списка VM: {e}")
            return False
    
    def _ensure_vm_selected(self):
        if not self.instance_id:
            print("VM не выбрана. Сначала выберите VM из списка:")
            if not self.list_vms():
                return False
            if not self.instance_id:
                print("VM не была выбрана. Операция отменена.")
                return False
        return True
    
    def _wait_for_operation(self, operation_id, status_message):
        operation_service = self.sdk.client(OperationServiceStub)
        while True:
            time.sleep(5)
            operation = self._get_operation(operation_id)
            if operation.done:
                break
            print(status_message)
        
        if operation.error.code != 0:
            print(f"Ошибка операции:")
            print(f"  Код: {operation.error.code}")
            print(f"  Сообщение: {operation.error.message}")
            if operation.error.details:
                print(f"  Детали: {operation.error.details}")
            return False
        
        return True
    
    def _get_operation(self, operation_id):
        operation_service = self.sdk.client(OperationServiceStub)
        operation_request = GetOperationRequest(operation_id=operation_id)
        return operation_service.Get(operation_request)
    
    def _get_status_text(self, status):
        status_map = {
            2: "RUNNING",
            4: "STOPPED"
        }
        return status_map.get(status, f"STATUS_{status}") 