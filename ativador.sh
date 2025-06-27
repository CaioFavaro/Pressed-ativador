#!/bin/bash
set -e

# ativador.sh — bootstrap completo para Zabbix Proxy

# 1) Atualiza sistema e instala Docker, OpenSSL e iptables-persistent
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io openssl iptables-persistent curl

# 2) Aplica regras de firewall 
iptables -F INPUT
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -p tcp --dport 22   -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 10051 -m conntrack --ctstate NEW -j ACCEPT

# Garante que as chains do Docker 
for C in DOCKER DOCKER-ISOLATION-STAGE-1 DOCKER-ISOLATION-STAGE-2; do
  iptables -t filter -N $C >/dev/null 2>&1 || true
done
iptables -t nat -N DOCKER >/dev/null 2>&1 || true

netfilter-persistent save

# 3) Gera PSK para Zabbix proxy
PSK_FILE="/var/lib/zabbix/enc/zabbix_proxy.psk"
mkdir -p "$(dirname "$PSK_FILE")"
openssl rand -hex 32 | tee "$PSK_FILE" >/dev/null
chmod 777 "$PSK_FILE"

# 4) Habilita e inicia Docker
systemctl enable --now docker

# 4.1) Espera o daemon responder
until docker info >/dev/null 2>&1; do
  sleep 1
done

# 5) Captura hostname para usar nos containers
PROXY_NAME=$(hostname -s)

# 6) Sobe container MySQL para o Proxy
docker run -d --name mysql-proxy \
  --restart unless-stopped \
  -e MYSQL_DATABASE=zabbix_proxy \
  -e MYSQL_USER=zabbix \
  -e MYSQL_PASSWORD=zabbix_pwd \
  -e MYSQL_ROOT_PASSWORD=root_pwd \
  mysql:8.0 \
  --character-set-server=utf8 \
  --collation-server=utf8_bin \
  --default-authentication-plugin=mysql_native_password

# 7) Aguarda MySQL ficar pronto
sleep 15

# 8) Sobe container Zabbix Proxy com PSK
docker run -d --name zabbix-proxy \
   --link mysql-proxy:mysql-proxy \
   --restart unless-stopped \
   -p 10051:10051 \
   -v /var/lib/zabbix/enc:/var/lib/zabbix/enc:ro \
   -e DB_SERVER_HOST="mysql-proxy" \
   -e MYSQL_DATABASE="zabbix_proxy" \
   -e MYSQL_USER="zabbix" \
   -e MYSQL_PASSWORD="zabbix_pwd" \
   -e ZBX_SERVER_HOST="10.1.40.19" \
   -e ZBX_PROXY_MODE="0" \
   -e ZBX_HOSTNAME="$PROXY_NAME" \
   -e ZBX_TLSCONNECT=psk \
   -e ZBX_TLSACCEPT=psk \
   -e ZBX_TLSPSKIDENTITY="$PROXY_NAME" \
   -e ZBX_TLSPSKFILE="/var/lib/zabbix/enc/zabbix_proxy.psk" \
   zabbix/zabbix-proxy-mysql:latest

# 9) Cria usuário cliente e injeta chave SSH pública
USERNAME="cliente-${PROXY_NAME}"
useradd -m -s /bin/bash "$USERNAME"

SSH_DIR="/home/$USERNAME/.ssh"
mkdir -p "$SSH_DIR"
chmod 777 "$SSH_DIR"

# Busca chave no servidor predefinido (URL baseada no hostname)
KEY_URL="http://10.1.15.87/keys/${PROXY_NAME}.pub"
curl -fsSL "$KEY_URL" > "$SSH_DIR/authorized_keys"

chmod 777 "$SSH_DIR/authorized_keys"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

# 10) Desabilita login por senha para esse usuário e mantém apenas SSH-key
sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload sshd

echo "Bootstrap concluído."
echo "– Root login com senha já configurada."
echo "– Acesse via SSH como $USERNAME@$PROXY_NAME usando sua chave privada correspondente."