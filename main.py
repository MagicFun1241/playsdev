import sys
from vm_manager import YandexCloudVMManager


def print_menu():
    print("\nВыберите действие:")
    print("1. Создать новую VM")
    print("2. Получить информацию о VM")
    print("3. Обновить SSH ключ VM")
    print("4. Удалить VM")
    print("5. Список всех VM")
    print("0. Выход")

def main():
    manager = YandexCloudVMManager()
    
    print("Yandex Cloud VM Manager")
    
    if not manager.initialize_sdk():
        sys.exit(1)
    
    while True:
        print_menu()
        
        choice = input("\nВведите номер действия: ").strip()
        
        if choice == "1":
            manager.create_vm()
        elif choice == "2":
            manager.get_vm_info()
        elif choice == "3":
            manager.update_ssh_key()
        elif choice == "4":
            manager.delete_vm()
        elif choice == "5":
            manager.list_vms()
        elif choice == "0":
            break
        else:
            print("Неверный выбор")


if __name__ == "__main__":
    main() 