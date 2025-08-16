#!/bin/bash

# По умолчанию используется стандартный скрипт
SCRIPT_NAME="autoXRAY.sh"
# Все переданные аргументы по умолчанию идут в SCRIPT_ARGS
SCRIPT_ARGS="$@"

# Анализируем первый аргумент, чтобы выбрать нужный скрипт установки
case "$1" in
  # Ключевые слова для выбора нестандартного скрипта
  selfsteal|selfsteal-ru|selfsteal-china|no443|bridge-ru)
    case "$1" in
      selfsteal)       SCRIPT_NAME="autoXRAYselfsteal.sh" ;;
      selfsteal-ru)    SCRIPT_NAME="autoXRAYselfstealConfRU.sh" ;;
      selfsteal-china) SCRIPT_NAME="autoXRAYselfstealConfChina.sh" ;;
      no443)           SCRIPT_NAME="autoXRAYno443.sh" ;;
      bridge-ru)       SCRIPT_NAME="autoXRAYselfstealConfRUbrEU.sh" ;;
    esac
    # Убираем ключевое слово из списка аргументов
    shift
    SCRIPT_ARGS="$@"
    ;;
esac

# Экспортируем переменные, чтобы docker-compose мог их использовать
export SCRIPT_NAME
export SCRIPT_ARGS

echo "Выбран скрипт: $SCRIPT_NAME"
echo "Аргументы: $SCRIPT_ARGS"
echo "Запускаем контейнер..."

# Запускаем сборку и старт контейнера в фоновом режиме
docker-compose up --build -d

# Путь к файлу с выводом внутри контейнера
OUTPUT_FILE="/usr/local/etc/xray/run_output.log"

echo "Ожидаем результат выполнения команды..."

# Ждем до 60 секунд, пока внутри контейнера не появится результат
for i in {1..30}; do
  output=$(docker-compose exec -T autoxray cat "$OUTPUT_FILE" 2>/dev/null)
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
echo "Чтобы посмотреть логи, используйте команду: docker-compose logs"
exit 1