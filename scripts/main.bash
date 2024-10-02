#! /bin/bash
# one change
# two change

# ! ROOT ACCESS ! #

# Paths varibles
file_krb5_conf="/etc/krb5.conf"
file_private_krb5_conf="/var/lib/samba/private/krb5.conf"
file_alt_krb5_conf="/lib/alterator/defaults/krb5.conf"
file_network="/etc/sysconfig/network"
file_samba_conf="/etc/samba/smb.conf"
file_lib_samba="/var/lib/samba"
file_cache_samba="/var/cache/samba"
file_sysvol_samba="/var/lib/samba/sysvol"
file_resolv_conf="/etc/resolv.conf"

# Install task-samba-dc and bind(for using 'host' program)
echo -e "\e[32;1mINFO:\e[0m Выполнение обновления системы перед установкой"
apt-get update 
apt-get dist-upgrade
echo -e "\e[32;1mINFO:\e[0m Установка пакета 'task-samba-dc'"
apt-get install bind bind-utils task-samba-dc

# Comment using core-cache
sed -i "16s/^/#/" $file_krb5_conf

echo -e "\e[32;1mINFO:\e[0m Строка номер 16 в файле $file_krb5_conf была успешно закомментирована."

# Disable some daemons
echo -e "\e[32;1mINFO:\e[0m Остановка и отключение сервисов 'bind', 'krb5kdc', 'slapd'"
echo -e "\e[33;1mWARNING:\e[0m Может появиться ошибка, из-за отсутствия сервиса"
systemctl stop bind && systemctl disable bind 
systemctl stop krb5kdc && systemctl disable krb5kdc 
systemctl stop slapd && systemctl disable slapd

# Remove database and configuration files
echo -e "\e[32;1mINFO:\e[0m Удаление файла $file_samba_conf"
rm -f $file_samba_conf 

echo -e "\e[32;1mINFO:\e[0m Рекурсивное удаление каталога $file_lib_samba"
rm -rf $file_lib_samba 

echo -e "\e[32;1mINFO:\e[0m Рекурсивное удаление каталога $file_cache_samba"
rm -rf $file_cache_samba 

echo -e "\e[32;1mINFO:\e[0m Создание каталога $file_sysvol_samba"
mkdir -p $file_sysvol_samba

# Install domen name with precheck

domen_pattern1="^[[^0-9]][a-zA-Z0-9]{2,}\.[^0-9][a-zA-Z0-9]{5,}\.[^0-9][a-zA-Z0-9]{3,}$"  # don't work
domen_pattern2="^[a-zA-Z]{2,}(\.[a-zA-Z]{2,})+$"                                          # work, but not correct
domen_pattern3="^((?!-)[A-Za-Z0-9-]{1,63}(?<!-)\.)+[A-Za-z]{2,6}$"                        # don't work (internet)
domen_pattern4="^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$"          # work, but not understand

read -p "Введите название домена, например 'dc.domain.alt': " domen_name

echo -e "\e[32;1mINFO:\e[0m Установка доменного имени..."
if [[ $domen_name =~ $domen_pattern4 ]]; then
    hostnamectl set-hostname $domen_name
else
    echo "Ошибка: строка \"$domen_name\" не соответствует формату домена."
fi

# Check TLD to include ".local"
if [[ $domen_name == ".local" ]]; then
	echo -e "\e[32;1mINFO:\e[0m Остановка 'avahi-daemon'"
    systemctl stop avahi-daemon
fi

# Change HOSTNAME in /etc/sysconfig/network
echo -e "\e[32;1mINFO:\e[0m Смена HOSTNAME в $file_network..."
echo "HOSTNAME=$domen_name" > $file_network

# Other host and domen changes
domen_name_without_subdomain=$(echo "$domen_name" | \
grep -Eo "[a-zA-Z0-9\-]*\.([a-zA-Z0-9\-]*)$") 

only_domen=$(echo "$domen_name" | grep -Eo "\.[^.]*\." | \
grep -Eo "[a-zA-Z\-]*")

echo -e "\e[32;1mINFO:\e[0m Вызов команды 'hostname' и 'domainname'" 
hostname $domen_name
domainname $domen_name_without_subdomain

# Create domen with SAMBA_INTERNAL

# Checking for the correct admin password
# flag="true"
# while [[ flag == "true" ]]
# do
# 	read -p "Введите пароль админа домена ($domen_name_without_subdomain): " admin_pass
# 
# 	read -p "Введите его ещё раз, для соответствия: " admin_pass_check
# 
# if [[ admin_pass == admin_pass_check ]]; then
# fi	
# done

read -s -p "Введите пароль админа домена ($domen_name_without_subdomain): " admin_pass

echo -e "\n\e[32;1mINFO:\e[0m Создание домена с SAMBA_INTERNAL...\n"
samba-tool domain provision --realm=$domen_name_without_subdomain \
							--domain $only_domen \
							--adminpass=$admin_pass \
							--dns-backend=SAMBA_INTERNAL \
							--server-role=dc

# Execute service Samba
echo -e "\e[32;1mINFO:\e[0m Запуск сервиса SAMBA..." 
systemctl enable --now samba

# Copy configuration file Kerberos
echo -e "\e[32;1mINFO:\e[0m Копирование конфигурационного файла Kerberos..."
cp $file_private_krb5_conf $file_krb5_conf

# Checking info about domain
echo -e "\e[32;1mINFO:\e[0m Проверка информации о домене..." 
samba-tool domain info 127.0.0.1

# Viewing services
echo -e "\e[32;1mINFO:\e[0m Просмотр предоставляемых служб..." 
smbclient -L localhost -U administrator

# Edit resolf.conf
echo -e "\e[32;1mINFO:\e[0m Редактирование $file_resolf_conf"
echo "nameserver 127.0.0.1" > $file_resolv_conf

# Checking configuration DNS
echo -e "\e[32;1mINFO:\e[0m Проверка настройки DNS..."
host $domen_name_without_subdomain

# Checking hosts name
echo -e "\e[32;1mINFO:\e[0m Проверка имен хостов..."
host -t SRV _kerberos._udb.$domen_name_without_subdomain.
host -t SRV _ldap._tcp.$domen_name_without_subdomain.
host -t A $domen_name

# Checking Kerberos
echo -e "\e[32;1mINFO:\e[0m Проверка Kerberos..."
kinit administrator && klist

# Adding users
echo -e "\e[32;1mINFO:\e[0m Добавление пользователя..."
read -p "Придумайте логин нового пользователя домена: " new_login
read -p "Введите имя нового пользователя домена: " new_user 
samba-tool user create $new_login --given-name='$new_user'
samba-tool user setexpiry $new_login

echo -e "\e[32;1mINFO:\e[0m Вывод списка пользователей..."
samba-tool user list
