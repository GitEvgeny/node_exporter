#!/bin/bash

# Установим переменные.
# Переменная для хранения версии Node Exporter:
NODE_EXPORTER_VERSION="1.8.0"
# Переменная для хранения URL сайта GitHub Node Exporter для скачивания:
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

# Переменная определения и хранения дистрибутива:
OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)

# Выбор ОС для установки необходимых пакетов и настройки firewall.
check_os() {
  if [ "$OS" == "ubuntu" ]; then
      packages_firewall_ubuntu
  elif [ "$OS" == "almalinux" ]; then
      packages_firewall_almalinux
  else
      echo "Скрипт не поддерживает установленную ОС: $OS"
      # Выход из скрипта с кодом 1.
      exit 1
  fi
}

# Функция установки необходимых пакетов и настройки firewall на Ubuntu:
packages_firewall_ubuntu() {
  # Обновить список доступных пакетов.
  sudo apt update
  # Установить wget и tar.
  sudo apt -y install wget tar
}

# Функция установки необходимых пакетов и настройки firewall на AlmaLinux:
packages_firewall_almalinux() {
  # Обновить список доступных пакетов.
  sudo dnf -y update
  # Установить wget и tar.
  sudo dnf -y install wget tar
  # Открыть порт 9100.
  sudo firewall-cmd --permanent --add-port=9100/tcp
  # Перезагрузить firewall-cmd для применения и сохранения настроек.
  sudo firewall-cmd --reload
}

# Функция подготовки почвы:
preparation() {
  # Создание пользователя для запуска Node Exporter.
  sudo useradd --no-create-home --shell /sbin/nologin node_exporter
}

# Функция для скачивания Node Exporter:
download_node_exporter () {
  # Скачивание Node Exporter с указанным именем:
  sudo wget $NODE_EXPORTER_URL -O /tmp/node_exporter.tar.gz
  # Распаковка Node Exporter в директорию /tmp:
  sudo tar -xzf /tmp/node_exporter.tar.gz -C /tmp
  # Перемещение бинарного файла в /usr/local/bin:
  sudo mv /tmp/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter /usr/local/bin/
  # Удаление директорий node_exporter:
  sudo rm -rf /tmp/node_exporter*
  # Настройка прав:
  sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
}

# Функция создания юнита Node Exporter для systemd:
create_unit_node_exporter() {
  sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
# Описание юнита.
Description=Node Exporter
# Указывает, что этот юнит "хочет" (т.е. желательно, но не обязательно) запустить network-online.target перед тем,
# как запустится сам. Это обычно используется для обеспечения того, чтобы сеть была доступна.
Wants=network-online.target
# Указывает, что данный юнит должен запускаться после network-online.target. Это гарантирует,
# что юнит запустится только после того, как сеть будет онлайн.
After=network-online.target

[Service]
# Указывает пользователя, от имени которого будет запущена служба.
User=node_exporter
# Указывает группу, от имени которой будет запущена служба.
Group=node_exporter
# Указывает тип службы. В данном случае это simple, что означает, что процесс, указанный в ExecStart,
# будет основным процессом службы. Systemd считает службу запущенной, как только этот процесс будет запущен.
Type=simple
# Команда, которая будет выполнена для запуска сервиса. В данном случае, это запуск node_exporter из указанного пути.
ExecStart=/usr/local/bin/node_exporter
# Указывает, что служба должна автоматически перезапускаться в случае сбоя. Это помогает обеспечить высокую доступность службы.
Restart=on-failure

[Install]
# Указывает, что служба должна быть запущена при достижении multi-user.target. Это стандартный уровень запуска для большинства систем,
# который включает в себя все службы, необходимые для работы в многопользовательском режиме без графического интерфейса.
# Это позволяет службе автоматически запускаться при загрузке системы в многопользовательский режим.
WantedBy=multi-user.target
EOF
}

# Запуск и включение Node Exporter:
start_enable_node_exporter() {
  # Перезапуск всех сервисов.
  sudo systemctl daemon-reload
  # Запуск Prometheus.
  sudo systemctl start node_exporter
  # Добавление в автозапуск Prometheus.
  sudo systemctl enable node_exporter
}

disable_selinux() {
  # Проверка, существует ли файл конфигурации SELinux
  if [ -f /etc/selinux/config ]; then
    # Изменение строки SELINUX= на SELINUX=disabled
    sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config  
    echo "SELinux был отключен. Перезагрузите систему для применения изменений."
  else
    echo "Файл конфигурации SELinux не найден."
  fi
}

# Функция проверки состояния Node Exporter:
check_status_node_exporter() {
  # Проверить статус работы:
  sudo systemctl status node_exporter --no-pager
  # Вывести версию:
  node_exporter --version
  echo "Node Exporter успешно установлен и настроен на $OS."
}

# Создание функций main.
main() {
  check_os
  preparation
  download_node_exporter
  create_unit_node_exporter
  start_enable_node_exporter
  disable_selinux
  check_status_node_exporter
}

# Вызов функции main.
main
