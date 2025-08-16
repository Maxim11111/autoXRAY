#!/bin/bash

# --- Раздел 1: Настройка портов ---
# Используем переданные аргументы или значения по умолчанию
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
apt update && apt install sudo curl -y > /dev/null 2>&1
sudo apt update && sudo apt install -y jq > /dev/null 2>&1

echo "Установка последней версии ядра Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1

# --- Раздел 3: Генерация конфигурационных данных ---
echo "Генерация ключей и UUID..."

# ИСПРАВЛЕНО: Указываем полный путь к xray, чтобы избежать ошибки "command not found"
# Это гарантирует, что мы получим UUID, даже если PATH еще не обновился.
xray_uuid_vrv=$(/usr/local/bin/xray uuid)

# Список доменов для маскировки
domains=(www.theregister.com www.20minutes.fr www.dealabs.com www.manomano.fr www.caradisiac.com www.techadvisor.com www.computerworld.com www.bing.com github.com tradingview.com)
xray_dest_vrv=${domains[$RANDOM % ${#domains[@]}]}
xray_dest_vrv222=${domains[$RANDOM % ${#domains[@]}]}

# ИСПРАВЛЕНО: Указываем полный путь к xray для генерации ключей
key_output=$(/usr/local/bin/xray x25519)
xray_privateKey_vrv=$(echo "$key_output" | awk -F': ' '/Private key/ {print $2}')
xray_publicKey_vrv=$(echo "$key_output" | awk -F': ' '/Public key/ {print $2}')

xray_shortIds_vrv=$(openssl rand -hex 8)
xray_sspasw_vrv=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)

# Определяем публичный IP сервера
ipserv=$(curl -s ifconfig.me)
# Если curl не сработал, пробуем через hostname
if [ -z "$ipserv" ]; then
    ipserv=$(hostname -I | awk '{print $1}')
fi

# --- Раздел 4: Создание файла config.json ---
echo "Создание файла конфигурации /usr/local/etc/xray/config.json..."
# Экспортируем переменные, чтобы envsubst мог их использовать
export xray_uuid_vrv xray_dest_vrv xray_dest_vrv222 xray_privateKey_vrv xray_publicKey_vrv xray_shortIds_vrv xray_sspasw_vrv port1 port2 port3

# Создаем JSON конфигурацию на основе шаблона
cat << EOF | envsubst > /usr/local/etc/xray/config.json
{
    "dns": { "servers": [ "https+local://8.8.4.4/dns-query", "https+local://8.8.8.8/dns-query", "https+local://1.1.1.1/dns-query", "localhost" ] },
    "log": { "loglevel": "none", "dnsLog": false },
    "routing": {
        "rules": [
            { "domain": [ "geosite:category-ads", "geosite:win-spy" ], "outboundTag": "block" },
            { "ip": [ "geoip:private" ], "outboundTag": "block", "type": "field" }
        ]
    },
  "inbounds": [
    {
      "tag": "VTR$port1", "listen": "0.0.0.0", "port": $port1, "protocol": "vless",
      "settings": { "clients": [ { "flow": "xtls-rprx-vision", "id": "${xray_uuid_vrv}" } ], "decryption": "none" },
      "streamSettings": {
        "network": "raw", "security": "reality",
        "realitySettings": { "show": false, "target": "${xray_dest_vrv}:443", "xver": 0, "SpiderX": "/", "serverNames": [ "${xray_dest_vrv}" ], "privateKey": "${xray_privateKey_vrv}", "publicKey": "${xray_publicKey_vrv}", "shortIds": [ "${xray_shortIds_vrv}" ] }
      },
      "sniffing": { "enabled": true, "destOverride": [ "http", "tls", "quic" ] }
    },
    {
      "tag": "VTR$port2", "listen": "0.0.0.0", "port": $port2, "protocol": "vless",
      "settings": { "clients": [ { "flow": "xtls-rprx-vision", "id": "${xray_uuid_vrv}" } ], "decryption": "none" },
      "streamSettings": {
        "network": "raw", "security": "reality",
        "realitySettings": { "show": false, "target": "${xray_dest_vrv222}:443", "xver": 0, "SpiderX": "/", "serverNames": [ "${xray_dest_vrv222}" ], "privateKey": "${xray_privateKey_vrv}", "publicKey": "${xray_publicKey_vrv}", "shortIds": [ "${xray_shortIds_vrv}" ] }
      },
      "sniffing": { "enabled": true, "destOverride": [ "http", "tls", "quic" ] }
    },
    {
      "tag": "SS$port3", "listen": "0.0.0.0", "port": $port3, "protocol": "shadowsocks",
      "settings": { "clients": [ { "password": "${xray_sspasw_vrv}", "method": "chacha20-ietf-poly1305" } ], "network": "tcp,udp" },
      "sniffing": { "enabled": true, "destOverride": [ "http", "tls", "quic" ] }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct", "settings": { "domainStrategy": "ForceIPv4" } },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
EOF

# --- Раздел 5: Перезапуск сервиса и вывод ссылок ---
echo "Перезапуск сервиса Xray для применения новой конфигурации..."
sudo systemctl restart xray
sudo systemctl enable xray > /dev/null 2>&1

echo "Готово!"

# Формирование ссылок для вывода
link1="vless://${xray_uuid_vrv}@${ipserv}:$port1?security=reality&sni=${xray_dest_vrv}&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&type=tcp&flow=xtls-rprx-vision&encryption=none#VPN-vless-$port1"
link2="vless://${xray_uuid_vrv}@${ipserv}:$port2?security=reality&sni=${xray_dest_vrv222}&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&type=tcp&flow=xtls-rprx-vision&encryption=none#VPN-vless-$port2"
ENCODED_STRING=$(echo -n "chacha20-ietf-poly1305:${xray_sspasw_vrv}" | base64)
link3="ss://$ENCODED_STRING@${ipserv}:$port3#VPN-ShadowS-$port3"

# --- Финальный вывод ---
echo -e "

Ваши VPN конфиги. Первый - самый надежный, остальные резервные!

\033[32m$link1\033[0m

\033[32m$link2\033[0m

\033[32m$link3\033[0m

Скопируйте конфиг в специализированное приложение:
- iOS: Happ или v2rayTun или FoXray
- Android: Happ или v2rayTun или v2rayNG
- Windows: Happ & winLoadXRAY & Hiddify & Nekoray

Сайт с инструкциями: blog.skybridge.run

Поддержать автора: https://github.com/xVRVx/autoXRAY

"