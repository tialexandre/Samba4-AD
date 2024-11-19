#!/bin/bash
# DC1-install.sh adaptado para Ubuntu
# Este script instala uma instância adicional do Samba AD (Servidor Secundário/Terciário) com suporte DC.

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

clear
echo "${GREEN}Aguarde enquanto verificamos os pré-requisitos...${TEXTRESET}"
sleep 1
apt update && apt -y install net-tools dmidecode wget git dialog

# Configurando Interface IP
cat <<EOF
Verificando se o IP estático está configurado.
EOF
sleep 1s

if [ -z "$INTERFACE" ]; then
  echo "Interface de rede não detectada."
  exit 1
fi

read -p "Por favor, forneça um endereço IP estático em formato CIDR (ex: 192.168.24.2/24): " IPADDR
read -p "Por favor, forneça um Gateway padrão: " GW
read -p "Por favor, forneça o FQDN para este servidor: " HOSTNAME
read -p "Forneça o IP do servidor AD primário: " DNSSERVER
read -p "Forneça o domínio de busca DNS: " DNSSEARCH

nmcli con mod $INTERFACE ipv4.address $IPADDR
nmcli con mod $INTERFACE ipv4.gateway $GW
nmcli con mod $INTERFACE ipv4.method manual
nmcli con mod $INTERFACE ipv4.dns-search $DNSSEARCH
nmcli con mod $INTERFACE ipv4.dns $DNSSERVER
hostnamectl set-hostname $HOSTNAME

clear
cat <<EOF
 *********************************************
 
 Este script configurará outro servidor AD para um domínio existente.
 Certifique-se de ter as seguintes informações:
 1. FQDN do DC existente
 2. Senha do administrador para entrar no domínio
 3. Subrede para NTP
 4. Intervalo de IP para DHCP (opcional)

 *********************************************

EOF

read -p "Pressione qualquer tecla para continuar ou Ctrl-C para sair."

# Configurando DHCP
read -p "Deseja instalar o servidor DHCP? [y/N]" -n 1 REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  echo "${GREEN}Instalando servidor DHCP${TEXTRESET}"
  apt -y install isc-dhcp-server

  read -p "Forneça o IP inicial para o intervalo de leases DHCP: " DHCPBEGIP
  read -p "Forneça o IP final para o intervalo de leases DHCP: " DHCPENDIP
  read -p "Forneça a máscara de subrede para clientes: " DHCPNETMASK
  read -p "Forneça o gateway padrão para clientes: " DHCPDEFGW
  read -p "Descrição para a subrede: " SUBNETDESC

  cat <<EOF >/etc/dhcp/dhcpd.conf
authoritative;
subnet ${SUBNETNETWORK} netmask ${DHCPNETMASK} {
  range ${DHCPBEGIP} ${DHCPENDIP};
  option subnet-mask ${DHCPNETMASK};
  option routers ${DHCPDEFGW};
}
EOF

  systemctl enable isc-dhcp-server
  systemctl start isc-dhcp-server
fi

clear
# Instalação do Cockpit para administração web
echo "${GREEN}Instalando Cockpit para administração via Web${TEXTRESET}"
read -p "Deseja instalar o Cockpit? [y/N]" -n 1 REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  apt -y install cockpit
  systemctl enable cockpit.socket
  systemctl start cockpit.socket
fi

# Instalação do Samba e configuração do domínio
apt -y install samba smbclient krb5-user

cat <<EOF
Joining o domínio
EOF

read -p "Forneça o FQDN do AD server existente: " ADDC
samba-tool domain join ${DOMAIN} DC -U "${ADDOMAIN}\administrator"

# Sincronização de tempo com NTP
sed -i "/pool /c\server ${ADDC} iburst" /etc/chrony/chrony.conf
systemctl restart chrony
sleep 10s
chronyc tracking

# Aplicação de regras de firewall usando UFW
echo "${GREEN}Atualizando Regras de Firewall${TEXTRESET}"
ufw allow samba
ufw allow ntp
ufw reload

# Mensagem final de sucesso
clear
cat <<EOF
${GREEN}********************************
 Instalação do Servidor Completa
********************************${TEXTRESET}
EOF

# Limpando arquivos temporários
rm -rf /root/DC-Installer.sh /root/ADDCInstaller

echo "${GREEN}Validação completa! Instalação realizada com sucesso!${TEXTRESET}"
