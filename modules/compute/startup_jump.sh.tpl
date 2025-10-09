#!/bin/bash
set -e

ELASTIC_HOST="https://elasticsearch.babenkov.pp.ua:9200"
KIBANA_HOST="https://kibana.babenkov.pp.ua:5601"
ELASTIC_USERNAME="elastic"
ELASTIC_PASSWORD="your_elastic_password"
DOMAIN_NAME="babenkov.pp.ua"
DEVOPS_SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJEqNqXbRHf5BXgaNTnBwQYmdbaKTJGE6S/hgYVsMmuz babenkov09@gmail.com"

apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx curl docker.io docker-compose-plugin

# Створення користувача devops
if ! id -u devops > /dev/null 2>&1; then
  useradd -m -s /bin/bash devops
fi
mkdir -p /home/devops/.ssh
echo "$DEVOPS_SSH_PUBLIC_KEY" > /home/devops/.ssh/authorized_keys
chown -R devops:devops /home/devops/.ssh
chmod 700 /home/devops/.ssh
chmod 600 /home/devops/.ssh/authorized_keys

# SSH без root і паролю
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || true
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || true
systemctl restart sshd || systemctl restart ssh || true

# Відключення unattended-upgrades
if systemctl list-units --type=service --all | grep -q unattended-upgrades; then
  systemctl disable --now unattended-upgrades || true
  apt-get remove -y unattended-upgrades || true
fi

###########################################
# 3. Nginx + SSL
###########################################
mkdir -p /var/www/html
cat > /var/www/html/index.html <<'EOF'
<html>
  <head><title>babenkov.pp.ua</title></head>
  <body>
    <h1>Jump Host — babenkov.pp.ua</h1>
    <p>Served from jump host</p>
  </body>
</html>
EOF

cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name ${DOMAIN_NAME};

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /private/ {
        proxy_pass http://PRIVATE_BACKEND_IP/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

systemctl restart nginx || true

# SSL сертифікат
sleep 10
certbot --nginx -d ${DOMAIN_NAME} --agree-tos --non-interactive --register-unsafely-without-email || true

###########################################
# 4. Моніторинг (Filebeat + Metricbeat)
###########################################
MONITORING_DIR="/opt/monitoring"
mkdir -p $MONITORING_DIR
cd $MONITORING_DIR

# Docker Compose
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  filebeat:
    image: docker.elastic.co/beats/filebeat:8.15.1
    container_name: filebeat
    user: root
    volumes:
      - ./filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /var/log/nginx:/var/log/nginx:ro
    environment:
      - ELASTIC_HOST=${ELASTIC_HOST}
      - ELASTIC_USERNAME=${ELASTIC_USERNAME}
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
    network_mode: host
    restart: always

  metricbeat:
    image: docker.elastic.co/beats/metricbeat:8.15.1
    container_name: metricbeat
    user: root
    volumes:
      - ./metricbeat.yml:/usr/share/metricbeat/metricbeat.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /sys/fs/cgroup:/hostfs/sys/fs/cgroup:ro
      - /proc:/hostfs/proc:ro
      - /:/hostfs:ro
    environment:
      - ELASTIC_HOST=${ELASTIC_HOST}
      - ELASTIC_USERNAME=${ELASTIC_USERNAME}
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
    network_mode: host
    restart: always
EOF

# Filebeat config
cat > filebeat.yml <<EOF
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
  hosts: ["${ELASTIC_HOST}"]
  username: "${ELASTIC_USERNAME}"
  password: "${ELASTIC_PASSWORD}"

setup.kibana:
  host: "${KIBANA_HOST}"

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
EOF

# Metricbeat config
cat > metricbeat.yml <<EOF
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
    metricsets: ["container", "cpu", "diskio", "healthcheck", "info", "memory", "network"]
    hosts: ["unix:///var/run/docker.sock"]
    period: 10s

output.elasticsearch:
  hosts: ["${ELASTIC_HOST}"]
  username: "${ELASTIC_USERNAME}"
  password: "${ELASTIC_PASSWORD}"

setup.kibana:
  host: "${KIBANA_HOST}"

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
EOF

docker compose up -d

echo "✅ Сервіс запущено: babenkov.pp.ua з моніторингом Filebeat + Metricbeat"
