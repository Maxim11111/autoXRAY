#!/bin/bash

# Пути к файлам внутри контейнера
CONFIG_FILE="/usr/local/etc/xray/config.json"
OUTPUT_FILE="/usr/local/etc/xray/run_output.log"
XRAY_BINARY="/usr/local/bin/xray"

# Определяем, какой скрипт запускать. По умолчанию - стандартный.
EXEC_SCRIPT="/scripts/${SCRIPT_NAME:-autoXRAY.sh}"

# Проверяем, существует ли скрипт
if [ ! -f "$EXEC_SCRIPT" ]; then
  echo "Ошибка: Скрипт '$EXEC_SCRIPT' не найден." > "$OUTPUT_FILE"
  exit 1
fi

echo "Запускаю $EXEC_SCRIPT с аргументами: '$SCRIPT_ARGS'..."
# `script` используется для корректной записи цветного вывода в файл
# `yes` автоматически отвечает 'y' на любые вопросы установщика
script -q -c "yes | $EXEC_SCRIPT $SCRIPT_ARGS" "$OUTPUT_FILE"

# После выполнения скрипта, если бинарный файл xray существует,
# запускаем его как основной процесс.
if [ -f "$XRAY_BINARY" ]; then
  echo "Запускаю сервис XRAY..."
  exec $XRAY_BINARY run -config $CONFIG_FILE
else
  echo "Бинарный файл XRAY не найден. Контейнер завершит работу."
  exit 0
fi