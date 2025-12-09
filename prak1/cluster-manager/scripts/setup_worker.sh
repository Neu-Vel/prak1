#!/bin/bash

# Обновление системы
echo "Обновление пакетов системы..."
apt-get update
apt-get upgrade -y

# Установка необходимых пакетов
echo "Установка базовых пакетов..."
apt-get install -y \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    default-jdk \
    maven \
    net-tools \
    htop

# Настройка firewall
echo "Настройка firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 3000/tcp
ufw --force enable

# Создание пользователя для приложения
echo "Создание пользователя приложения..."
useradd -m -s /bin/bash appuser
echo "appuser:apppassword" | chpasswd

# Установка Docker
echo "Установка Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker appuser
usermod -aG docker vagrant

# Настройка мониторинга
echo "Установка инструментов мониторинга..."
apt-get install -y prometheus-node-exporter
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter

# Создание директории для приложения
echo "Подготовка директории для приложения..."
mkdir -p /opt/prak1
chown -R appuser:appuser /opt/prak1

# Настройка SSH для кластера
echo "Настройка SSH для работы в кластере..."
mkdir -p /home/appuser/.ssh
cp /vagrant/configs/ssh_keys/worker_key.pub /home/appuser/.ssh/authorized_keys 2>/dev/null || true
chown -R appuser:appuser /home/appuser/.ssh
chmod 700 /home/appuser/.ssh
chmod 600 /home/appuser/.ssh/authorized_keys

# Создание простого веб-сервера для тестирования балансировки
cat > /home/appuser/simple-server.js << 'EOF'
const http = require('http');
const os = require('os');

const hostname = '0.0.0.0';
const port = 3000;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html');
  res.end(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>Worker Node - ${os.hostname()}</title>
        <style>
            body { 
                font-family: Arial, sans-serif; 
                text-align: center; 
                padding: 50px; 
                background-color: #f0f0f0;
            }
            .container { 
                background: white; 
                padding: 30px; 
                border-radius: 10px; 
                box-shadow: 0 0 10px rgba(0,0,0,0.1);
                display: inline-block;
            }
            h1 { color: #333; }
            .info { 
                background: #e8f4f8; 
                padding: 15px; 
                border-radius: 5px; 
                margin: 20px 0;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Worker Node</h1>
            <div class="info">
                <p><strong>Hostname:</strong> ${os.hostname()}</p>
                <p><strong>IP Address:</strong> ${req.connection.localAddress}</p>
                <p><strong>Request received at:</strong> ${new Date()}</p>
            </div>
            <p>Это воркер-нода кластера</p>
            <p>Запрос обработан сервером: <strong>${os.hostname()}</strong></p>
        </div>
    </body>
    </html>
  `);
});

server.listen(port, hostname, () => {
  console.log(`Server running at http://${hostname}:${port}/`);
});
EOF

chown appuser:appuser /home/appuser/simple-server.js

# Создание systemd сервиса для веб-приложения
cat > /etc/systemd/system/cluster-app.service << EOF
[Unit]
Description=Cluster Application Server
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/home/appuser
ExecStart=/usr/bin/node /home/appuser/simple-server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cluster-app
systemctl start cluster-app

echo "Настройка воркер-ноды завершена!"
echo "IP адрес: 192.168.56.11"
echo "Веб-сервер запущен на порту 3000"