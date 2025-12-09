#!/bin/bash

echo "Деплой приложения Prak1..."

# Клонирование репозитория
cd /opt/prak1
if [ ! -d "prak1" ]; then
    echo "Клонирование репозитория..."
    sudo -u appuser git clone https://github.com/Neu-Vel/prak1.git
else
    echo "Обновление репозитория..."
    cd prak1
    sudo -u appuser git pull origin main
fi

cd /opt/prak1/prak1

# Определение типа приложения и его настройка
if [ -f "package.json" ]; then
    echo "Обнаружено Node.js приложение"
    sudo -u appuser npm install
    
    # Создание systemd сервиса для Node.js приложения
    cat > /etc/systemd/system/prak1-app.service << EOF
[Unit]
Description=Prak1 Node.js Application
After=network.target postgresql.service

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/prak1/prak1
Environment=NODE_ENV=production
Environment=DATABASE_URL=postgresql://prakuser:prakpass@localhost:5432/prak1db
ExecStart=/usr/bin/node /opt/prak1/prak1/app.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
elif [ -f "requirements.txt" ]; then
    echo "Обнаружено Python приложение"
    sudo -u appuser python3 -m venv venv
    sudo -u appuser bash -c "source venv/bin/activate && pip install -r requirements.txt"
    
    # Создание systemd сервиса для Python приложения
    cat > /etc/systemd/system/prak1-app.service << EOF
[Unit]
Description=Prak1 Python Application
After=network.target postgresql.service

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/prak1/prak1
Environment=DATABASE_URL=postgresql://prakuser:prakpass@localhost:5432/prak1db
ExecStart=/opt/prak1/prak1/venv/bin/python /opt/prak1/prak1/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
elif [ -f "pom.xml" ]; then
    echo "Обнаружено Java приложение"
    sudo -u appuser mvn clean package
    
    # Поиск jar файла
    JAR_FILE=$(find target -name "*.jar" -not -name "*sources.jar" -not -name "*tests.jar" | head -1)
    
    if [ -n "$JAR_FILE" ]; then
        cat > /etc/systemd/system/prak1-app.service << EOF
[Unit]
Description=Prak1 Java Application
After=network.target postgresql.service

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/prak1/prak1
Environment=SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/prak1db
Environment=SPRING_DATASOURCE_USERNAME=prakuser
Environment=SPRING_DATASOURCE_PASSWORD=prakpass
ExecStart=/usr/bin/java -jar /opt/prak1/prak1/${JAR_FILE}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    fi
fi

# Если найден docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    echo "Обнаружен Docker Compose файл"
    sudo -u appuser docker-compose down
    sudo -u appuser docker-compose up -d
fi

# Запуск или перезапуск сервиса
if [ -f "/etc/systemd/system/prak1-app.service" ]; then
    systemctl daemon-reload
    systemctl enable prak1-app
    systemctl restart prak1-app
    echo "Сервис приложения запущен"
fi

echo "Деплой приложения завершен!"