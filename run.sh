#!/bin/bash

# Немедленно выходить, если команда завершается с ошибкой.
set -e

# --- НОВОЕ: Автоопределение команды docker-compose ---
# Проверяем, доступна ли новая команда 'docker compose'
if docker compose version &>/dev/null; then
  DC_CMD="docker compose"
# Если нет, проверяем старую 'docker-compose'
elif docker-compose --version &>/dev/null; then
  DC_CMD="docker-compose"
else
  echo "Ошибка: Не удалось найти ни 'docker compose', ни 'docker-compose'."
  echo "Пожалуйста, убедитесь, что Docker и Docker Compose установлены правильно."
  exit 1
fi
echo "Используется команда: '$DC_CMD'"
# --- КОНЕЦ НОВОГО БЛОКА ---


# По умолчанию используется стандартный скрипт
SCRIPT_NAME="autoXRAY.sh"
# Все переданные аргументы по умолчанию идут в SCRIPT_ARGS
SCRIPT_ARGS="$@"

# Анализируем первый аргумент, чтобы выбрать нужный скрипт установки
case "$1" in
  selfsteal|selfsteal-ru|selfsteal-china|no443|bridge-ru)
    case "$1" in
      selfsteal)       SCRIPT_NAME="autoXRAYselfsteal.sh" ;;
      selfsteal-ru)    SCRIPT_NAME="autoXRAYselfstealConfRU.sh" ;;
      selfsteal-china) SCRIPT_NAME="autoXRAYselfstealConfChina.sh" ;;
      no443)           SCRIPT_NAME="autoXRAYno443.sh" ;;
      bridge-ru)       SCRIPT_NAME="autoXRAYselfstealConfRUbrEU.sh" ;;
    esac
    shift
    SCRIPT_ARGS="$@"
    ;;
esac

echo "Создаем файл конфигурации .env..."
{
  echo "SCRIPT_NAME=${SCRIPT_NAME}"
  echo "SCRIPT_ARGS=${SCRIPT_ARGS}"
} > .env

echo "Выбран скрипт: $SCRIPT_NAME"
echo "Аргументы: $SCRIPT_ARGS"
echo "Запускаем контейнер..."

# Используем определенную ранее команду $DC_CMD
$DC_CMD up --build -d

# Путь к файлу с выводом внутри контейнера
OUTPUT_FILE="/usr/local/etc/xray/run_output.log"

echo "Ожидаем результат выполнения команды..."

for i in {1..30}; do
  # Используем определенную ранее команду $DC_CMD
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