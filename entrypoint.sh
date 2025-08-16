#!/bin/bash

# Пути к файлам внутри контейнера
CONFIG_FILE="/usr/local/etc/xray/config.json"
OUTPUT_FILE="/usr/local/etc/xray/run_output.log"
XRAY_BINARY="/usr/local/bin/xray"

# Определяем, какой скрипт запускать. По умолчанию - стандартный.
EXEC_SCRIPT="/scripts/${SCRIPT_NAME:-autoXRAY.sh}"

if [ ! -f "$EXEC_SCRIPT" ]; then
  echo "Ошибка: Скрипт '$EXEC_SCRIPT' не найден." > "$OUTPUT_FILE"
  exit 1
fi

# --- ИСПРАВЛЕНИЕ 3: Патчим скрипт перед запуском ---
echo "Патчим скрипт для работы в Docker..."

# Заменяем автоопределение IP на наш публичный IP из переменной
# (работает для большинства скриптов, которые используют ifconfig.me)
sed -i "s|IP=\$(curl -s ifconfig.me)|IP=\"$PUBLIC_IP\"|g" "$EXEC_SCRIPT"
sed -i "s|ip=\$(curl -s ifconfig.me)|ip=\"$PUBLIC_IP\"|g" "$EXEC_SCRIPT"

# Заменяем вызов systemctl, чтобы избежать ошибки
sed -i 's/sudo systemctl restart xray/echo "Docker: Xray будет запущен через entrypoint"/g' "$EXEC_SCRIPT"

echo "Запускаю $EXEC_SCRIPT с аргументами: '$SCRIPT_ARGS'..."
script -q -c "yes | $EXEC_SCRIPT $SCRIPT_ARGS" "$OUTPUT_FILE"

if [ -f "$XRAY_BINARY" ]; then
  echo "Запускаю сервис XRAY..."
  exec $XRAY_BINARY run -config $CONFIG_FILE
else
  echo "Бинарный файл XRAY не найден. Контейнер завершит работу."
  exit 0
fi