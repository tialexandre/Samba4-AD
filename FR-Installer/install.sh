#!/bin/bash
#install.sh-FreeRADIUS adaptado para Ubuntu
clear
apt -y update && apt -y install net-tools dmidecode
TEXTRESET=$(tput sgr0)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
FQDN=$(hostname)
IP=$(hostname -I | awk '{print $1}')
DOMAIN=$(hostname -d | awk '{print toupper($0)}')
USER=$(whoami)
MAJOROS=$(lsb_release -sr | cut -d. -f1)
DETECTIP=$(nmcli -g ipv4.method connection show "$INTERFACE")

# Verificação de permissões do usuário
if [ "$USER" != "root" ]; then
  echo "${RED}Este programa deve ser executado como root ${TEXTRESET}"
  echo "Saindo"
  exit 1
fi

# Verificação da versão do sistema
if [ "$MAJOROS" != "20" ] && [ "$MAJOROS" != "22" ]; then
  echo "${RED}Desculpe, mas este instalador só funciona no Ubuntu 20.x ou 22.x${TEXTRESET}"
  echo "Por favor, atualize para ${GREEN}Ubuntu 20.x ou 22.x${TEXTRESET}"
  echo "Saindo do instalador..."
  exit
fi
clear

cat <<EOF
Verificando configuração de IP estático
EOF
sleep 1s

# Detectar IP estático ou DHCP (se não for estático, solicitar configuração)
if [ "$DETECTIP" = "auto" ]; then
  echo "${RED}Interface $INTERFACE está usando DHCP${TEXTRESET}"
  read -p "Forneça um endereço IP estático em formato CIDR (ex.: 192.168.24.2/24): " IPADDR
  read -p "Forneça o Gateway padrão: " GW
  read -p "Forneça o FQDN desta máquina: " HOSTNAME
  read -p "Forneça o IP do servidor de Active Directory: " DNSSERVER
  read -p "Forneça o nome de busca do domínio: " DNSSEARCH

  cat <<EOF
As seguintes alterações serão aplicadas ao sistema:
IP address: ${GREEN}$IPADDR${TEXTRESET}
Gateway: ${GREEN}$GW${TEXTRESET}
DNS Search: ${GREEN}$DNSSEARCH${TEXTRESET}
DNS Server: ${GREEN}$DNSSERVER${TEXTRESET}
HOSTNAME: ${GREEN}$HOSTNAME${TEXTRESET}
EOF

  read -p "Pressione qualquer tecla para continuar"
  nmcli con mod "$INTERFACE" ipv4.address "$IPADDR"
  nmcli con mod "$INTERFACE" ipv4.gateway "$GW"
  nmcli con mod "$INTERFACE" ipv4.method manual
  nmcli con mod "$INTERFACE" ipv4.dns-search "$DNSSEARCH"
  nmcli con mod "$INTERFACE" ipv4.dns "$DNSSERVER"
  hostnamectl set-hostname "$HOSTNAME"
  
  reboot
  exit
else
  echo "${GREEN}Interface $INTERFACE está usando um endereço IP estático${TEXTRESET}"
fi

clear
cat <<EOF
*********************************************
Este script foi criado para ${GREEN}Ubuntu 20.x ou 22.x${TEXTRESET}
Este script configurará rapidamente um servidor FreeRADIUS.

Este processo:
    1. Atualiza e instala todas as dependências para o FreeRADIUS.
    2. Adiciona as portas do radius ao firewall.
    3. Integra o servidor ao AD.
    4. Configura winbind, PEAP/MS-CHAP, autenticação MAC e autenticação MAC com IPSK.
    5. Testa winbind, MS-CHAP e FreeRADIUS.

*********************************************
EOF
read -p "Pressione qualquer tecla para continuar ou Ctrl-C para sair"
clear

# Instalando dependências e ferramentas adicionais
apt -y install wget git freeradius freeradius-utils realmd samba winbind libnss-winbind libpam-winbind

# Adicionando portas ao firewall
echo "Atualizando regras do firewall"
ufw allow proto udp from any to any port 1812,1813
ufw reload
clear

# Configuração do FreeRADIUS
echo "${GREEN}Instalando Cockpit para administração baseada em web${TEXTRESET}"
apt -y install cockpit
systemctl enable --now cockpit.socket
echo "Acesse Cockpit em https://$FQDN:9090"

clear
cat <<EOF
O instalador agora solicitará algumas informações da lista de verificação fornecida anteriormente.

EOF
read -p "Pressione qualquer tecla para continuar ou Ctrl-C para sair"
clear

read -p "Forneça o nome de usuário AD para teste: " FRUSER
read -p "Forneça a senha deste usuário: " FRPASS
read -p "Forneça o nome do grupo AD para verificação de associação: " GROUP
read -p "Forneça o nome do domínio AD (preferencialmente em maiúsculas): " ADDOMAIN
read -p "Forneça o endereço IP/FQDN do servidor NTP/AD: " NTP
read -p "Forneça a conta do Administrador AD para unir o sistema ao domínio: " DOMAINADMIN
read -p "Forneça a sub-rede em notação CIDR para dispositivos NAS se conectarem ao radius: " CIDRNAS
read -p "Forneça a senha compartilhada que os dispositivos NAS usarão: " NASSECRET

cat <<EOF
Validando entradas:
Usuário de teste RADIUS: ${GREEN}$FRUSER${TEXTRESET}
Senha de teste RADIUS: ${GREEN}$FRPASS${TEXTRESET}
Grupo AD para verificação de associação: ${GREEN}$GROUP${TEXTRESET}
Domínio AD: ${GREEN}$ADDOMAIN${TEXTRESET}
Servidor NTP: ${GREEN}$NTP${TEXTRESET}
Conta de Administrador AD: ${GREEN}$DOMAINADMIN${TEXTRESET}
Sub-rede para dispositivos NAS: ${GREEN}$CIDRNAS${TEXTRESET}
Senha para dispositivos NAS: ${GREEN}$NASSECRET${TEXTRESET}
EOF

read -p "Pressione qualquer tecla para continuar ou Ctrl-C para sair"
clear

# Configurando a integração com o AD e outras opções de autenticação
realm join -U "$DOMAINADMIN" --client-software=winbind "$ADDOMAIN"
sed -i "/pool /c\server $NTP iburst" /etc/chrony/chrony.conf
systemctl restart chrony

# Validação e testes de winbind e FreeRADIUS
wbinfo -t
wbinfo -u
wbinfo -g

# Configuração de FreeRADIUS para integração com Samba e AD
touch /etc/freeradius/3.0/mods-available/ntlm_auth
cat <<EOF >/etc/freeradius/3.0/mods-available/ntlm_auth
exec ntlm_auth {
    wait = yes
    program = "/usr/bin/ntlm_auth --request-nt-key --username=%{mschap:User-Name} --domain=$ADDOMAIN --challenge=%{mschap:Challenge} --nt-response=%{mschap:NT-Response}"
}
EOF
ln -s /etc/freeradius/3.0/mods-available/ntlm_auth /etc/freeradius/3.0/mods-enabled/

cat <<EOF
A instalação do servidor está completa.
Para verificar a configuração, execute os testes com radtest.
EOF

# Limpeza e finalização
rm -rf /root/FR-Installer
