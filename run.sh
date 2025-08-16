#!/bin/bash

# Немедленно выходить, если команда завершается с ошибкой.
set -e

# --- ИСПРАВЛЕНИЕ 1: Определяем публичный IP хоста ---
echo "Определяем публичный IP-адрес сервера..."
PUBLIC_IP=$(curl -s icanhazip.com)
if [ -z "$PUBLIC_IP" ]; then
  echo "Ошибка: не удалось определить публичный IP-адрес."
  exit 1
fi
echo "Сервер имеет IP: $PUBLIC_IP"
# Экспортируем его для .env файла
export PUBLIC_IP

# Автоопределение команды docker-compose
if docker compose version &>/dev/null; then
  DC_CMD="docker compose"
elif docker-compose --version &>/dev/null; then
  DC_CMD="docker-compose"
else
  echo "Ошибка: Не удалось найти ни 'docker compose', ни 'docker-compose'."
  exit 1
fi
echo "Используется команда: '$DC_CMD'"

# --- ИСПРАВЛЕНИЕ 2: Корректная обработка аргументов ---
SCRIPT_NAME="autoXRAY.sh"
SCRIPT_ARGS_RAW="$@"

case "$1" in
  selfsteal|selfsteal-ru|selfsteal-china|no443|bridge-ru)
    # ... (логика выбора скрипта остается прежней)
    case "$1" in
      selfsteal)       SCRIPT_NAME="autoXRAYselfsteal.sh" ;;
      selfsteal-ru)    SCRIPT_NAME="autoXRAYselfstealConfRU.sh" ;;
      selfsteal-china) SCRIPT_NAME="autoXRAYselfstealConfChina.sh" ;;
      no443)           SCRIPT_NAME="autoXRAYno443.sh" ;;
      bridge-ru)       SCRIPT_NAME="autoXRAYselfstealConfRUbrEU.sh" ;;
    esac
    shift # убираем ключевое слово
    # Если следующий аргумент это --, убираем и его
    if [ "$1" == "--" ]; then
      shift
    fi
    SCRIPT_ARGS_RAW="$@"
    ;;
esac

export SCRIPT_NAME
export SCRIPT_ARGS="$SCRIPT_ARGS_RAW"

echo "Создаем файл конфигурации .env..."
{
  echo "SCRIPT_NAME=${SCRIPT_NAME}"
  echo "SCRIPT_ARGS=${SCRIPT_ARGS}"
  echo "PUBLIC_IP=${PUBLIC_IP}" # Добавляем IP в .env
} > .env

echo "Выбран скрипт: $SCRIPT_NAME"
echo "Аргументы: $SCRIPT_ARGS"
echo "Запускаем контейнер..."

$DC_CMD up --build -d

OUTPUT_FILE="/usr/local/etc/xray/run_output.log"
echo "Ожидаем результат выполнения команды..."

for i in {1..30}; do
  output=$($DC_CMD exec -T autoxray cat "$OUTPUT_FILE" 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$output" ]; then
    echo "--------------------------------------------------"
    echo "Результат выполнения:"
    echo "$output"
    echo "--------------------------------------------------"
    exit 0
  fi
  sleep 2
done

echo "Не удалось получить результат выполнения за 60 секунд."
echo "Чтобы посмотреть логи, используйте команду: $DC_CMD logs"
exit 1