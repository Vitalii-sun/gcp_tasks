# get_my_ip.sh
#!/bin/bash
# Отримує поточну публічну IP через зовнішній сервіс
IP=$(curl -s https://api.ipify.org)
# Форматуємо як CIDR (/32 для однієї IP)
echo "{\"ip\": \"$IP/32\"}"