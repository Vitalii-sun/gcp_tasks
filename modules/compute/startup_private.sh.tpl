#!/bin/bash
set -e

apt-get update -y
apt-get install -y nginx

# Створення користувача devops та SSH ключ
if ! id -u devops > /dev/null 2>&1; then
  useradd -m -s /bin/bash devops
fi
mkdir -p /home/devops/.ssh
echo "${devops_ssh_public_key}" > /home/devops/.ssh/authorized_keys
chown -R devops:devops /home/devops/.ssh
chmod 700 /home/devops/.ssh
chmod 600 /home/devops/.ssh/authorized_keys

# Відключення root login і password auth
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || true
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || true
systemctl restart sshd || systemctl restart ssh || true

# Відключення unattended-upgrades
if systemctl list-units --type=service --all | grep -q unattended-upgrades; then
  systemctl disable --now unattended-upgrades || true
  apt-get remove -y unattended-upgrades || true
fi

# Простий index.html
cat > /var/www/html/index.html <<'EOF'
<html>
  <head><title>Private Host</title></head>
  <body>
    <h1>Private Host - internal</h1>
    <p>Served from private host (no external IP)</p>
  </body>
</html>
EOF

systemctl restart nginx || true
