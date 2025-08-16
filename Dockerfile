# Использование официального образа Ubuntu 24.04
FROM ubuntu:24.04

# Установка временной зоны и зависимостей
ENV TZ=Etc/UTC
RUN apt-get update && apt-get install -y curl unzip coreutils wget procps && rm -rf /var/lib/apt/lists/*

# Создаем директорию для скриптов
WORKDIR /scripts

# Скачиваем ВСЕ скрипты из вашего репозитория
RUN curl -L https://raw.githubusercontent.com/Maxim11111/autoXRAY/main/autoXRAY.sh -o autoXRAY.sh
RUN curl -L https://raw.githubusercontent.com/Maxim11111/autoXRAY/main/autoXRAYselfsteal.sh -o autoXRAYselfsteal.sh
RUN curl -L https://raw.githubusercontent.com/Maxim11111/autoXRAY/main/autoXRAYselfstealConfRU.sh -o autoXRAYselfstealConfRU.sh
RUN curl -L https://raw.githubusercontent.com/Maxim11111/autoXRAY/main/autoXRAYselfstealConfChina.sh -o autoXRAYselfstealConfChina.sh
RUN curl -L https://raw.githubusercontent.com/Maxim11111/autoXRAY/main/autoXRAYno443.sh -o autoXRAYno443.sh
RUN curl -L https://raw.githubusercontent.com/Maxim11111/autoXRAY/main/autoXRAYselfstealConfRUbrEU.sh -o autoXRAYselfstealConfRUbrEU.sh

# Делаем все скрипты исполняемыми
RUN chmod +x *.sh

# Копируем и делаем исполняемым наш управляющий скрипт
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Указываем, что при старте контейнера должен запускаться наш скрипт
ENTRYPOINT ["/entrypoint.sh"]