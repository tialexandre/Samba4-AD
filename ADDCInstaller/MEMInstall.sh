#!/bin/bash
# MEMinstall.sh - Ubuntu version
# This installer will install a member server to a pre-existing domain
clear
apt -y update && apt -y install net-tools dmidecode

TEXTRESET=$(tput sgr0)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
FQDN=$(hostname)
IP=$(hostname -I)
DOMAIN=$(hostname -d)
ADDOMAIN=$(hostname -d | cut -d. -f1 | awk '{print toupper($0)}')
USER=$(whoami)
MAJOROS=$(lsb_release -sr | cut -d. -f1)
DETECTIP=$(nmcli -g ipv4.method connection show "$INTERFACE")

# Verificação de permissões de usuário
if [ "$USER" != "root" ]; then
  echo "${RED}This program must be run as root ${TEXTRESET}"
  echo "Exiting"
  exit 1
fi

# Verificação de versão do sistema
if [ "$MAJOROS" != "20" ] && [ "$MAJOROS" != "22" ]; then
  echo "${RED}Sorry, but this installer only works on Ubuntu 20.x or 22.x ${TEXTRESET}"
  echo "Exiting the installer..."
  exit
fi

clear
cat <<EOF
Checking for static IP Address
EOF
sleep 1s

# Detectando se o IP é estático ou DHCP
if [ "$DETECTIP" = "auto" ]; then
  echo "${RED}Interface $INTERFACE is using DHCP${TEXTRESET}"
  read -p "Please provide a static IP address in CIDR format (i.e., 192.168.24.2/24): " IPADDR
  while [[ ! $IPADDR =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$ ]]; do
    echo "${RED}The entry is not in valid CIDR notation. Please try again: ${TEXTRESET}"
    read -p "Please provide a static IP address in CIDR format: " IPADDR
  done

  read -p "Please Provide a Default Gateway Address: " GW
  read -p "Please provide the FQDN of this machine: " HOSTNAME
  read -p "Please provide the IP address of the Active Directory server: " DNSSERVER
  read -p "Please provide the domain search name: " DNSSEARCH

  nmcli con mod "$INTERFACE" ipv4.address "$IPADDR"
  nmcli con mod "$INTERFACE" ipv4.gateway "$GW"
  nmcli con mod "$INTERFACE" ipv4.method manual
  nmcli con mod "$INTERFACE" ipv4.dns "$DNSSERVER"
  nmcli con mod "$INTERFACE" ipv4.dns-search "$DNSSEARCH"
  hostnamectl set-hostname "$HOSTNAME"

  echo "The system must reboot for changes to take effect. ${RED}Please log back in as root.${TEXTRESET}"
  read -p "Press any Key to Continue"
  reboot
  exit
else
  echo "${GREEN}Interface $INTERFACE is using a static IP address ${TEXTRESET}"
fi

clear
cat <<EOF

*********************************************
This script is compatible with Ubuntu 20.x and 22.x
*********************************************

EOF
read -p "Press any Key to continue or Ctrl-C to Exit"
clear

# Instalando dependências
echo "${GREEN}Installing dependencies${TEXTRESET}"
apt -y install chrony realmd samba winbind libnss-winbind libpam-winbind

# Configurando autenticação no AD
read -p "Please provide a valid AD username for testing: " ADUSER
read -p "Please provide this user's password: " ADPASS
read -p "Please provide the IP/FQDN Address of your NTP/AD Server: " NTP
read -p "Please provide the Administrator Account to join this system to AD (username only): " DOMAINADMIN

realm join --user="$DOMAINADMIN" "$DOMAIN"

# Configurando NTP
sed -i "/pool /c\server $NTP iburst" /etc/chrony/chrony.conf
systemctl restart chrony

echo "${GREEN}Synchronizing time, please wait...${TEXTRESET}"
sleep 10s
chronyc tracking

# Validando winbind
echo "${GREEN}Testing RPC to Active Directory${TEXTRESET}"
wbinfo -t

echo "${GREEN}AD Users${TEXTRESET}"
wbinfo -u

echo "${GREEN}AD Groups${TEXTRESET}"
wbinfo -g

# Teste de login com winbind
echo "${GREEN}Test a winbind login${TEXTRESET}"
wbinfo -a "$ADUSER%$ADPASS"

# Atualizando /etc/issue para exibir hostname e IP antes do login
echo -e "\S\nKernel \r on an \m\nHostname: \n\nIP Address: \4" > /etc/issue

# Instalação opcional do Cockpit
cat <<EOF
${GREEN}Install Cockpit${TEXTRESET}
Cockpit is a server administration tool that provides a web-based interface.
EOF

read -r -p "Would you like to install Cockpit for web-based administration? [y/N] " -n 1
echo
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    apt -y install cockpit
    systemctl enable --now cockpit.socket
    echo "${YELLOW}Your cockpit instance can be accessed at ${FQDN}:9090${TEXTRESET}"
fi

# Habilitando e iniciando o Samba
systemctl enable smbd
systemctl start smbd

clear
cat <<EOF
${GREEN}********************************
   Server Installation Complete
********************************${TEXTRESET}

The server will now reboot to apply changes.
EOF
read -p "Press Any Key to reboot"
reboot
