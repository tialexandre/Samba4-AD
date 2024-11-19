#!/bin/bash
#DC-install.sh adaptado para Ubuntu
# Este script instala o PRIMEIRO Samba AD com suporte DC

clear
# Instalação de pacotes necessários
apt update && apt -y install net-tools dmidecode wget dialog samba smbclient krb5-user isc-dhcp-server cockpit

# Variáveis de cores para saída
TEXTRESET=$(tput sgr0)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | head -n 1)
FQDN=$(hostname)
IP=$(hostname -I | awk '{print $1}')
DOMAIN=$(hostname | sed 's/^[^.:]*[.:]//' | sed -e 's/\(.*\)/\U\1/')
USER=$(whoami)

# Verificação de permissões de root
if [ "$USER" != "root" ]; then
  echo "${RED}Este programa deve ser executado como root${TEXTRESET}"
  echo "Saindo..."
  exit 1
fi

# Verificação de versão do Ubuntu
MAJOROS=$(lsb_release -sr | cut -d '.' -f1)
if [ "$MAJOROS" != "22" ]; then
  echo "${RED}Este instalador funciona apenas no Ubuntu 22.x ${TEXTRESET}"
  exit 1
fi

# Configurando IP estático
echo "${GREEN}Verificando se o IP estático está configurado${TEXTRESET}"
sleep 1

if [ -z "$INTERFACE" ]; then
  echo "Interface de rede não detectada."
  exit 1
fi

read -p "Por favor, forneça um endereço IP estático em formato CIDR (ex: 192.168.24.2/24): " IPADDR
read -p "Por favor, forneça um Gateway padrão: " GW
read -p "Por favor, forneça o FQDN para este servidor: " HOSTNAME
read -p "Forneça o IP do servidor DNS: " DNSSERVER
read -p "Forneça o domínio de busca DNS: " DNSSEARCH

nmcli con mod $INTERFACE ipv4.address $IPADDR
nmcli con mod $INTERFACE ipv4.gateway $GW
nmcli con mod $INTERFACE ipv4.method manual
nmcli con mod $INTERFACE ipv4.dns-search $DNSSEARCH
nmcli con mod $INTERFACE ipv4.dns $DNSSERVER
hostnamectl set-hostname $HOSTNAME

echo "${GREEN}Configuração de rede concluída. O sistema será reiniciado para aplicar as alterações.${TEXTRESET}"
read -p "Pressione qualquer tecla para continuar"
reboot

# Provisionamento do Samba AD/DC
clear
echo "${GREEN}Instalação e configuração inicial do Samba AD/DC${TEXTRESET}"
read -p "Por favor, forneça uma senha de Administrador para provisionar o AD/DC: " ADMINPASS
read -p "Por favor, forneça o escopo de rede para NTP (exemplo: 192.168.0.0/16): " NTPCIDR

samba-tool domain provision \
  --realm="$DOMAIN" \
  --domain="$DOMAIN" \
  --adminpass="$ADMINPASS"

# Configuração de DHCP
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.orig
cat <<EOF >/etc/dhcp/dhcpd.conf
authoritative;
option domain-name-servers ${IP};
option domain-name "${DOMAIN}";
EOF

# Configuração do firewall com UFW
ufw allow samba
ufw allow ntp
ufw reload

# Sincronização de tempo com NTP
sed -i "/pool /c\server ${DOMAIN} iburst" /etc/chrony/chrony.conf
systemctl restart chrony
chronyc tracking

# Configuração do Cockpit
systemctl enable cockpit.socket
systemctl start cockpit.socket

clear
echo "${GREEN}Instalação e configuração do Samba AD/DC concluídas!${TEXTRESET}"

# Validação da instalação
echo "${GREEN}Testando o Kerberos e registros DNS${TEXTRESET}"
kinit Administrator
klist
echo "${GREEN}Verificando registros SRV de DNS para _ldap._tcp e _kerberos._udp${TEXTRESET}"
host -t SRV _ldap._tcp.$DOMAIN.
host -t SRV _kerberos._udp.$DOMAIN.

# Finalização
echo "${GREEN}********************************
    Instalação do Servidor Concluída
********************************${TEXTRESET}"
