#!/bin/bash

# Красивый ASCII баннер
echo -e "\e[34mIP address:\e[0m \e[93m$(hostname -I | awk '{print $1}')\e[0m"
echo -e "\e[34mMask:\e[0m \e[93m$(ip -o -f inet addr show $(ip route | grep default | awk '{print $5}') | awk '{print $4}' | cut -d/ -f2)\e[0m"
echo -e "\e[34mGate:\e[0m \e[93m$(ip route | grep default | awk '{print $3}')\e[0m"
echo -e "\e[34mDNS:\e[0m \e[93m$(systemd-resolve --status | grep 'DNS Servers' | awk '{print $3}')\e[0m"
echo -e "\e[34mHostname:\e[0m \e[93m$(hostname)\e[0m"
echo -e "\e[34mInterfaceName:\e[0m \e[93m$(ip route | grep default | awk '{print $5}')\e[0m"
echo ""


function set_hostname() {
    read -p "Введите новое имя ПК: " new_hostname
    hostnamectl set-hostname $new_hostname
    echo "Имя ПК изменено на $new_hostname"
}

function configure_ufw() {
    if ! which ufw > /dev/null; then
        echo "UFW firewall не установлен."
        read -p "Хотите установить? (yes/no): " install_ufw
        if [ "$install_ufw" == "yes" ]; then
            sudo apt update
            sudo apt install -y ufw
            sudo ufw enable
        fi
    else
        sudo ufw disable
        read -p "Введите порты для TCP через запятую: " tcp_ports
        IFS=',' read -ra tcp_ports_array <<< "$tcp_ports"
        for port in "${tcp_ports_array[@]}"; do
            sudo ufw allow $port/tcp
        done

        read -p "Введите порты для UDP через запятую: " udp_ports
        IFS=',' read -ra udp_ports_array <<< "$udp_ports"
        for port in "${udp_ports_array[@]}"; do
            sudo ufw allow $port/udp
        done
    fi
}

function set_ssh_port() {
    read -p "Введите новый номер порта для SSH: " ssh_port
    sudo sed -i "s/^#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
    sudo service ssh restart
    echo "SSH порт изменен на $ssh_port"
}

function add_ssh_key() {
    if [ ! -d ~/.ssh ]; then
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
    fi
    wget https://raw.githubusercontent.com/zip609/ubuntu/main/basic.sh -O - >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
}


function configure_network() {
    default_iface=$(ip route | grep default | awk '{print $5}')
    read -p "Введите IP адрес: " ip_address
    read -p "Введите маску сети: " netmask
    read -p "Введите адрес основного шлюза: " gateway
    read -p "Введите адреса DNS (через запятую): " dns

    echo "network:" > /etc/netplan/01-netcfg.yaml
    echo "  version: 2" >> /etc/netplan/01-netcfg.yaml
    echo "  renderer: networkd" >> /etc/netplan/01-netcfg.yaml
    echo "  ethernets:" >> /etc/netplan/01-netcfg.yaml
    echo "    $default_iface:" >> /etc/netplan/01-netcfg.yaml
    echo "      addresses: [$ip_address/$netmask]" >> /etc/netplan/01-netcfg.yaml
    echo "      gateway4: $gateway" >> /etc/netplan/01-netcfg.yaml
    echo "      nameservers:" >> /etc/netplan/01-netcfg.yaml
    echo "        addresses: [${dns//,/ , }]" >> /etc/netplan/01-netcfg.yaml
    netplan apply
    echo "Настройки сети применены"
}

function enable_routing() {
    read -p "Включить маршрутизацию (yes/no)? " routing_decision
    if [ "$routing_decision" == "yes" ]; then
        sudo iptables --policy FORWARD ACCEPT
    fi
}

function enable_ufw() {
    sudo ufw enable
}

function enable_root_ssh() {
    echo "Установка пароля для пользователя root..."
    sudo passwd root

    echo "Разрешение доступа по SSH для пользователя root..."
    sudo sed -i "s/^#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
    sudo service ssh restart
}

function set_ssh_key_only() {
    read -p "Разрешить доступ по SSH только по ключу? (Да/Нет) " choice
    if [[ $choice == "Да" || $choice == "да" ]]; then
        sudo sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
        echo "Теперь для SSH доступ возможен только по ключу."
    else
        sudo sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
        echo "Доступ к SSH разрешен как по ключу, так и по паролю."
    fi
    sudo service ssh restart
}


function reboot_server() {
    read -p "Перезагрузить сервер (yes/no)? " reboot_decision
    if [ "$reboot_decision" == "yes" ]; then
        sudo reboot
    fi
}

while true; do
    echo "1. Изменение имени ПК"
    echo "2. Настройка портов в UFW firewall"
    echo "3. Настройка номера порта SSH"
    echo "4. Установка публичного SSH ключа"
    echo "5. Настройка сети"
    echo "6. Включить маршрутизацию"
    echo "7. Активировать UFW"
	echo "8. Активировать root по SSH"
	echo "9. Доступ к SSH только по ключу или по ключу и паролю"
    echo "10. Выполнить все пункты меню последовательно"
    echo "11. Перезагрузить сервер"
    echo "0. Выход"
    read -p "Выберите пункт меню (0-9): " choice

    case $choice in
        1) set_hostname ;;
        2) configure_ufw ;;
        3) set_ssh_port ;;
        4) add_ssh_key ;;
        5) configure_network ;;
        6) enable_routing ;;
        7) enable_ufw ;;
		8) enable_root_ssh;;
		9) set_ssh_key_only;;
        10) set_hostname; configure_ufw; set_ssh_port; add_ssh_key; configure_network; enable_routing; enable_ufw; enable_root_ssh;set_ssh_key_only;;
        11) reboot_server ;;
        0) exit 0 ;;
        *) echo "Неверный выбор";;
    esac
done
