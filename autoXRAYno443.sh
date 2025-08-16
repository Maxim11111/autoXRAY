#!/bin/bash

# --- Раздел 0: Проверка прав и обработка ошибок ---
# Немедленно выходить, если любая команда завершается с ошибкой
set -e

# Проверяем, что скрипт запущен от имени суперпользователя (root)
if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: Этот скрипт необходимо запускать с правами суперпользователя."
   echo "Пожалуйста, выполните команду так: sudo $0 $*"
   exit 1
fi


# --- Раздел 1: Настройка портов ---
# ИСПРАВЛЕНО: Корректно обрабатываем необязательный разделитель "--"
if [ "$1" == "--" ]; then
  shift
fi
port1=${1:-4443}
port2=${2:-8443}
port3=${3:-2040}

echo "Будут использованы порты:"
echo "VLESS 1: $port1"
echo "VLESS 2: $port2"
echo "Shadowsocks: $port3"
echo ""


# --- Раздел 2: Установка зависимостей и Xray ---
echo "Обновление и установка необходимых пакетов..."
# sudo не нужен, так как мы уже под root
apt update && apt install -y curl jq

echo "Установка последней версии ядра Xray (вывод будет показан для отладки)..."
# ИСПРАВЛЕНО: Убран > /dev/null, чтобы видеть ошибки установки
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# ИСПРАВЛЕНО: Гарантируем, что директория для конфига существует
mkdir -p /usr/local/etc/xray


# --- Раздел 3: Генерация конфигурационных данных ---
echo "Генерация ключей и UUID..."
# Используем полный путь на случай, если PATH еще не обновился
xray_uuid_vrv=$(/usr/local/bin/xray uuid)
domains=(www.theregister.com www.20minutes.fr www.dealabs.com www.manomano.fr www.caradisiac.com www.techadvisor.com www.computerworld.com www.bing.com github.com tradingview.com)
xray_dest_vrv=${domains[$RANDOM % ${#domains[@]}]}
xray_dest_vrv222=${domains[$RANDOM % ${#domains[@]}]}
key_output=$(/usr/local/bin/xray x25519)
xray_privateKey_vrv=$(echo "$key_output" | awk -F': ' '/Private key/ {print $2}')
xray_publicKey_vrv=$(echo "$key_output" | awk -F': ' '/Public key/ {print $2}')
xray_shortIds_vrv=$(openssl rand -hex 8)
xray_sspasw_vrv=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)
ipserv=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')


# --- Раздел 4: Создание файла config.json ---
echo "Создание файла конфигурации /usr/local/etc/xray/config.json..."
export xray_uuid_vrv xray_dest_vrv xray_dest_vrv222 xray_privateKey_vrv xray_publicKey_vrv xray_shortIds_vrv xray_sspasw_vrv port1 port2 port3

# Шаблон конфигурации (без изменений)
cat << EOF | envsubst > /usr/local/etc/xray/config.json
{
    "dns": { "servers": [ "https+local://8.8.4.4/dns-query", "https+local://8.8.8.8/dns-query", "https+local://1.1.1.1/dns-query", "localhost" ] },
    "log": { "loglevel": "none" },
    "routing": { "rules": [ { "domain": [ "geosite:category-ads", "geosite:win-spy" ], "outboundTag": "block" }, { "ip": [ "geoip:private" ], "outboundTag": "block", "type": "field" } ] },
    "inbounds": [
        { "listen": "0.0.0.0", "port": $port1, "protocol": "vless", "settings": { "clients": [ { "flow": "xtls-rprx-vision", "id": "${xray_uuid_vrv}" } ], "decryption": "none" }, "streamSettings": { "network": "raw", "security": "reality", "realitySettings": { "show": false, "target": "${xray_dest_vrv}:443", "xver": 0, "serverNames": [ "${xray_dest_vrv}" ], "privateKey": "${xray_privateKey_vrv}", "publicKey": "${xray_publicKey_vrv}", "shortIds": [ "${xray_shortIds_vrv}" ] } }, "sniffing": { "enabled": true, "destOverride": [ "http", "tls", "quic" ] } },
        { "listen": "0.0.0.0", "port": $port2, "protocol": "vless", "settings": { "clients": [ { "flow": "xtls-rprx-vision", "id": "${xray_uuid_vrv}" } ], "decryption": "none" }, "streamSettings": { "network": "raw", "security": "reality", "realitySettings": { "show": false, "target": "${xray_dest_vrv222}:443", "xver": 0, "serverNames": [ "${xray_dest_vrv222}" ], "privateKey": "${xray_privateKey_vrv}", "publicKey": "${xray_publicKey_vrv}", "shortIds": [ "${xray_shortIds_vrv}" ] } }, "sniffing": { "enabled": true, "destOverride": [ "http", "tls", "quic" ] } },
        { "listen": "0.0.0.0", "port": $port3, "protocol": "shadowsocks", "settings": { "clients": [ { "password": "${xray_sspasw_vrv}", "method": "chacha20-ietf-poly1305" } ], "network": "tcp,udp" }, "sniffing": { "enabled": true, "destOverride": [ "http", "tls", "quic" ] } }
    ],
    "outbounds": [ { "protocol": "freedom", "tag": "direct" }, { "protocol": "blackhole", "tag": "block" } ]
}
EOF


# --- Раздел 5: Перезапуск сервиса и вывод ссылок ---
echo "Перезапуск сервиса Xray для применения новой конфигурации..."
# sudo не нужен, так как мы уже под root
systemctl restart xray
systemctl enable xray

echo "Готово!"

# Формирование ссылок для вывода
link1="vless://${xray_uuid_vrv}@${ipserv}:$port1?security=reality&sni=${xray_dest_vrv}&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&type=tcp&flow=xtls-rprx-vision&encryption=none#VPN-vless-$port1"
link2="vless://${xray_uuid_vrv}@${ipserv}:$port2?security=reality&sni=${xray_dest_vrv222}&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&type=tcp&flow=xtls-rprx-vision&encryption=none#VPN-vless-$port2"
ENCODED_STRING=$(echo -n "chacha20-ietf-poly1305:${xray_sspasw_vrv}" | base64)
link3="ss://$ENCODED_STRING@${ipserv}:$port3#VPN-ShadowS-$port3"

# Финальный вывод
echo -e "\n\nВаши VPN конфиги. Первый - самый надежный, остальные резервные!\n"
echo -e "\033[32m$link1\033[0m\n"
echo -e "\033[32m$link2\033[0m\n"
echo -e "\033[32m$link3\033[0m\n"
echo -e "Скопируйте конфиг в специализированное приложение.\n"