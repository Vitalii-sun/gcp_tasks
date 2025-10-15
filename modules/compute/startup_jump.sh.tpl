#!/bin/bash
set -e
exec > >(tee /var/log/startup_jump.log|logger -t startup_jump -s 2>/dev/console) 2>&1
set -x

ELASTIC_HOST="${ELASTIC_HOST}" 
KIBANA_HOST="${KIBANA_HOST}" 
ELASTIC_USERNAME="${ELASTIC_USERNAME}"
ELASTIC_PASSWORD="${ELASTIC_PASSWORD}"
DOMAIN_NAME="${DOMAIN_NAME}"
PRIVATE_BACKEND_IP="${PRIVATE_BACKEND_IP}"

###########################################
# 0. Create swap (2GB)
###########################################
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
fi

###########################################
# 1. System Update & Base Packages
###########################################
sudo apt-get update -y
sudo apt-get install -y nginx certbot python3-certbot-nginx curl docker.io

# Docker Compose plugin
sudo mkdir -p /usr/lib/docker/cli-plugins
sudo curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-x86_64" \
    -o /usr/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/lib/docker/cli-plugins/docker-compose
docker compose version

###########################################
# 2. Create user 'devops'
###########################################
if ! id -u devops >/dev/null 2>&1; then
    sudo useradd -m -s /bin/bash devops
fi
sudo mkdir -p /home/devops/.ssh
sudo tee /home/devops/.ssh/authorized_keys >/dev/null
sudo chown -R devops:devops /home/devops/.ssh
sudo chmod 700 /home/devops/.ssh
sudo chmod 600 /home/devops/.ssh/authorized_keys

sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || true
sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || true
sudo systemctl restart sshd || sudo systemctl restart ssh || true

###########################################
# 4. Docker Compose: Elasticsearch + Kibana
###########################################
MONITORING_DIR="/opt/monitoring"
sudo mkdir -p "$MONITORING_DIR"
cd "$MONITORING_DIR"

sudo tee docker-compose.yml > /dev/null <<EOF
version: "3.8"

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.15.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - ES_JAVA_OPTS=-Xms256m -Xmx256m
      - network.host=0.0.0.0
    network_mode: "host"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es_data:/usr/share/elasticsearch/data
    restart: always

  kibana:
    image: docker.elastic.co/kibana/kibana:8.15.0
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://127.0.0.1:9200
    network_mode: "host"
    depends_on:
      - elasticsearch
    restart: always

volumes:
  es_data:
EOF

sudo docker compose up -d

###########################################
# 5. Nginx Reverse Proxy + SSL for all services
###########################################

NGINX_CONF="/etc/nginx/sites-available/monitoring.conf"

# Створюємо конфігурацію без SSL (тимчасово)
sudo tee "$NGINX_CONF" > /dev/null <<EOF
# Jump Host HTTP -> HTTPS redirect
server {
    listen 80;
    server_name ${DOMAIN_NAME} ${ELASTIC_HOST} ${KIBANA_HOST};
    root /var/www/html;
    index index.html;
}
EOF

sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/monitoring.conf
sudo systemctl restart nginx || true

# Отримуємо сертифікати через standalone (Nginx тимчасово не повинен слухати 80)
sudo systemctl stop nginx
sudo certbot certonly --standalone \
    -d ${DOMAIN_NAME} -d ${ELASTIC_HOST} -d ${KIBANA_HOST} \
    --agree-tos --non-interactive --register-unsafely-without-email
sudo systemctl start nginx

# Тепер переписуємо конфіг з SSL
sudo tee "$NGINX_CONF" > /dev/null <<EOF
# Jump Host HTTP -> HTTPS redirect
server {
    listen 80;
    server_name ${DOMAIN_NAME} ${ELASTIC_HOST} ${KIBANA_HOST};
    return 301 https://\$host\$request_uri;
}

# Jump Host HTTPS
server {
    listen 443 ssl;
    server_name ${DOMAIN_NAME};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /private/ {
        proxy_pass http://${PRIVATE_BACKEND_IP}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}

# Elasticsearch HTTPS via Nginx
server {
    listen 443 ssl;
    server_name ${ELASTIC_HOST};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:9200;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

# Kibana HTTPS via Nginx
server {
    listen 443 ssl;
    server_name ${KIBANA_HOST};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:5601;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo systemctl reload nginx

###########################################
# 6. Beats Configs (Filebeat + Metricbeat)
###########################################
cat <<EOF | sudo tee "$MONITORING_DIR/filebeat.yml"
filebeat.inputs:
  - type: container
    paths:
      - /var/lib/docker/containers/*/*.log
    json.keys_under_root: true
    processors:
      - add_docker_metadata: ~

  - type: log
    enabled: true
    paths:
      - /var/log/nginx/*.log
    fields:
      service: nginx
    fields_under_root: true

output.elasticsearch:
  hosts: ["https://${ELASTIC_HOST}:443"]
  username: "${ELASTIC_USERNAME}"
  password: "${ELASTIC_PASSWORD}"
  ssl.verification_mode: none

setup.kibana:
  host: "https://${KIBANA_HOST}:443"
  ssl.verification_mode: none
EOF

cat <<EOF | sudo tee "$MONITORING_DIR/metricbeat.yml"
metricbeat.modules:
  - module: system
    period: 10s
    metricsets: ["cpu", "memory", "network", "process", "diskio", "filesystem"]
    processes: ['.*']
    cpu.metrics: ["percentages", "normalized_percentages"]
    process.include_top_n:
      by_cpu: 5
      by_memory: 5

  - module: nginx
    metricsets: ["stubstatus"]
    period: 10s
    hosts: ["http://127.0.0.1/nginx_status"]

  - module: docker
    metricsets: ["container", "cpu", "diskio", "info", "memory", "network"]
    hosts: ["unix:///var/run/docker.sock"]
    period: 10s

output.elasticsearch:
  hosts: ["https://${ELASTIC_HOST}:443"]
  username: "${ELASTIC_USERNAME}"
  password: "${ELASTIC_PASSWORD}"
  ssl.verification_mode: none

setup.kibana:
  host: "https://${KIBANA_HOST}:443"
  ssl.verification_mode: none
EOF

# Run Beats
sudo docker run -d --restart always \
  -v "$MONITORING_DIR/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro" \
  -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /var/log/nginx:/var/log/nginx:ro \
  --name filebeat docker.elastic.co/beats/filebeat:8.15.1

sudo docker run -d --restart always \
  -v "$MONITORING_DIR/metricbeat.yml:/usr/share/metricbeat/metricbeat.yml:ro" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /sys/fs/cgroup:/hostfs/sys/fs/cgroup:ro \
  -v /proc:/hostfs/proc:ro \
  -v /:/hostfs:ro \
  --name metricbeat docker.elastic.co/beats/metricbeat:8.15.1

echo "✅ Jump Host + Monitoring stack deployed successfully!"
echo "🔗 Jump Host: https://${DOMAIN_NAME}"
echo "🔗 Elasticsearch: https://${ELASTIC_HOST}"
echo "🔗 Kibana: https://${KIBANA_HOST}"
