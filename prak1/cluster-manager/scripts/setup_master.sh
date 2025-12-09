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
    nginx \
    postgresql \
    postgresql-contrib \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    default-jdk \
    maven \
    net-tools \
    htop

# Настройка PostgreSQL
echo "Настройка PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE prak1db;"
sudo -u postgres psql -c "CREATE USER prakuser WITH PASSWORD 'prakpass';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE prak1db TO prakuser;"
sudo -u postgres psql -c "ALTER DATABASE prak1db OWNER TO prakuser;"

# Настройка firewall
echo "Настройка firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp
ufw allow 5432/tcp
ufw --force enable

# Создание пользователя для приложения
echo "Создание пользователя приложения..."
useradd -m -s /bin/bash appuser
usermod -aG sudo appuser
echo "appuser:apppassword" | chpasswd

# Установка Docker (опционально, для контейнеризации)
echo "Установка Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker appuser
usermod -aG docker vagrant

# Установка Docker Compose
echo "Установка Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Настройка балансировщика нагрузки (NGINX)
echo "Настройка NGINX как балансировщика..."
cat > /etc/nginx/sites-available/cluster << EOF
upstream app_servers {
    server 192.168.56.10:3000 weight=3;
    server 192.168.56.11:3000 weight=2;
    server 127.0.0.1:3000 backup;
}

server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://app_servers;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Настройки для балансировки
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_connect_timeout 2s;
    }
    
    location /status {
        stub_status on;
        access_log off;
        allow 192.168.56.0/24;
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/cluster /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

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
cp /vagrant/configs/ssh_keys/master_key.pub /home/appuser/.ssh/authorized_keys 2>/dev/null || true
chown -R appuser:appuser /home/appuser/.ssh
chmod 700 /home/appuser/.ssh
chmod 600 /home/appuser/.ssh/authorized_keys

# Создание скрипта проверки кластера
cat > /usr/local/bin/check-cluster << 'EOF'
#!/bin/bash
echo "=== Проверка состояния кластера ==="
echo "1. Проверка сервисов на мастер-ноде:"
echo "   PostgreSQL: $(systemctl is-active postgresql)"
echo "   NGINX: $(systemctl is-active nginx)"
echo "   Node Exporter: $(systemctl is-active prometheus-node-exporter)"
echo ""
echo "2. Проверка соединения с воркер-нодой:"
ping -c 2 192.168.56.11 >/dev/null && echo "   Worker node доступен" || echo "   Worker node недоступен"
echo ""
echo "3. Проверка балансировщика:"
curl -s http://localhost/status | grep -i "active"
echo ""
echo "4. Проверка ресурсов системы:"
free -h | grep -i mem
echo ""
echo "=== Проверка завершена ==="
EOF

chmod +x /usr/local/bin/check-cluster

echo "Настройка мастер-ноды завершена!"
echo "IP адрес: 192.168.56.10"
echo "Для проверки кластера выполните: check-cluster"