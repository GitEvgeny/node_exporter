#!/bin/bash

# Установим переменные.
NODE_EXPORTER_VERSION="1.8.0"
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
  sudo apt update
  sudo apt -y install wget tar
}

# Функция установки необходимых пакетов и настройки firewall на AlmaLinux:
packages_firewall_almalinux() {
  sudo dnf -y update
  sudo dnf -y install wget tar
  # Настройка firewall
  sudo firewall-cmd --permanent --add-port=9100/tcp
  sudo firewall-cmd --reload
}

# Функция подготовки почвы:
preparation() {
  # Создание пользователя для запуска Node Exporter.
  sudo useradd --no-create-home --shell /sbin/nologin node_exporter
}

# Функция для скачивания Node Exporter:
download_node_exporter () {
  # Загрузка Node Exporter
  sudo wget $NODE_EXPORTER_URL -O /tmp/node_exporter.tar.gz
  # Распаковка архива
  sudo tar -xzf /tmp/node_exporter.tar.gz -C /tmp
  # Перемещение бинарного файла в /usr/local/bin
  sudo mv /tmp/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter /usr/local/bin/
  sudo rm -rf /tmp/node_exporter*
  # Убедитесь, что файл node_exporter принадлежит правильному пользователю и группе
  sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
}

# Функция создания юнита Node Exporter для systemd:
create_unit_node_exporter() {
  sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}

# Запуск и включение Node Exporter:
start_enable_node_exporter() {
  sudo systemctl daemon-reload
  sudo systemctl start node_exporter
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
  sudo systemctl status node_exporter --no-pager
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
