#!/bin/bash
#DC-Installer.sh #Bootstrap to GIT REPO
TEXTRESET=$(tput sgr0)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
USER=$(whoami)
MAJOROS=$(lsb_release -sr | cut -d '.' -f1)

# Verificando permissões do usuário
if [ "$USER" = "root" ]; then
  echo " "
else
  echo "${RED}Este programa deve ser executado como root ${TEXTRESET}"
  echo "Saindo"
  exit 1
fi

# Verificando versão do Ubuntu
if [ "$MAJOROS" = "22" ]; then
  echo " "
else
  echo "${RED}Desculpe, mas este instalador funciona apenas no Ubuntu 22.X ${TEXTRESET}"
  echo "Por favor, atualize para ${GREEN}Ubuntu 22.x${TEXTRESET}"
  echo "Saindo do instalador..."
  exit 1
fi

cat <<EOF
${GREEN}**************************
Aguarde enquanto reunimos alguns arquivos
**************************${TEXTRESET}


${YELLOW}Instalando wget e git${TEXTRESET}
EOF
sleep 1

apt update
apt -y install wget git dialog

cat <<EOF
${YELLOW}*****************************
Recuperando arquivos do GitHub
*****************************${TEXTRESET}
EOF

sleep 1
# Clone FR
mkdir /root/FR-Installer

git clone https://github.com/fumatchu/FR-RADS.git /root/FR-Installer

chmod 700 /root/FR-Installer/i*
# Clone RADS
mkdir /root/ADDCInstaller

git clone https://github.com/fumatchu/RADS.git /root/ADDCInstaller

chmod 700 /root/ADDCInstaller/DC*
chmod 700 /root/ADDCInstaller/MEM*

clear
cat <<EOF
 *********************************************

 Este script foi criado para ${GREEN}Ubuntu 22.x${TEXTRESET}
 Ele instalará:
 1. Um servidor primário Samba AD/DC (e criará a Floresta/Domínio)
                       ${YELLOW}-OU-${TEXTRESET}
 2. Um servidor AD adicional e o provisionará.
                       ${YELLOW}-OU-${TEXTRESET} 
 3. Um Servidor Membro para um Domínio para Serviços de Arquivo/Impressão
                       ${YELLOW}-OU-${TEXTRESET}
 4. Provisionará e integrará um servidor FreeRADIUS
 
 ${RED}Cada servidor deve ser instalado em uma instância separada (VM/Hardware)${TEXTRESET}
 
 O que este script faz:
 1. Aplica contexto de segurança apropriado e regras de firewall
 2. Instala os repositórios e dependências necessárias
 3. Compila o Samba (se estiver implementando AD)
 4. Configura o sistema conforme necessário, com base nas suas respostas
 5. Fornece testes para a plataforma configurada
 6. Instala ferramentas de gerenciamento do servidor

 *********************************************
 

EOF

read -p "Pressione qualquer tecla para continuar"

items=(1 "Instalar Primeiro Servidor AD/Criar Domínio"
  2 "Instalar Servidor AD Secundário/Terciário"
  3 "Instalar um Servidor Membro para Arquivo/Impressão"
  4 "Instalar Servidor FreeRADIUS"
)

while choice=$(dialog --title "$TITLE" \
  --backtitle "Instalador do Servidor" \
  --menu "Selecione o tipo de instalação" 15 65 3 "${items[@]}" \
  2>&1 >/dev/tty); do
  case $choice in
  1) /root/ADDCInstaller/DCInstall.sh ;;
  2) /root/ADDCInstaller/DC1-Install.sh ;;
  3) /root/ADDCInstaller/MEMInstall.sh ;;
  4) /root/FR-Installer/install.sh ;;

  esac
done
clear # Limpa a tela após o usuário pressionar Cancelar
