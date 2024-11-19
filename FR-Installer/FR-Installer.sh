#!/bin/sh
# FR-Installer.sh - Adaptado para Ubuntu
# Bootstrap para Repositório GIT
TEXTRESET=$(tput sgr0)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
USER=$(whoami)
MAJOROS=$(lsb_release -sr | cut -d. -f1)

# Verificação de permissões do usuário
if [ "$USER" != "root" ]; then
  echo "${RED}Este programa deve ser executado como root${TEXTRESET}"
  echo "Saindo"
  exit 1
fi

# Verificação da versão do Ubuntu
if [ "$MAJOROS" != "20" ] && [ "$MAJOROS" != "22" ]; then
  echo "${RED}Desculpe, mas este instalador só funciona no Ubuntu 20.x ou 22.x${TEXTRESET}"
  echo "Por favor, atualize para ${GREEN}Ubuntu 20.x ou 22.x${TEXTRESET}"
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

apt update && apt -y install wget git dialog

cat <<EOF
${YELLOW}*****************************
Recuperando Arquivos do GitHub
*****************************${TEXTRESET}
EOF
sleep 1

# Clonar repositório FR
mkdir -p /root/FR-Installer
git clone https://github.com/fumatchu/FR-RADS.git /root/FR-Installer
chmod 700 /root/FR-Installer/i*

# Clonar repositório RADS
mkdir -p /root/ADDCInstaller
git clone https://github.com/fumatchu/RADS.git /root/ADDCInstaller
chmod 700 /root/ADDCInstaller/DC*
chmod 700 /root/ADDCInstaller/MEM*
clear

cat <<EOF
*********************************************

Este script foi criado para ${GREEN}Ubuntu 20.x ou 22.x${TEXTRESET}
Este script instalará:
 1. Um servidor primário AD/DC Samba (e criará a Floresta/Domínio)
                       ${YELLOW}-OU-${TEXTRESET}
 2. Um servidor AD adicional e o provisionará.
                       ${YELLOW}-OU-${TEXTRESET}
 3. Um Servidor Membro para um Domínio para Serviços de Arquivo/Impressão
                       ${YELLOW}-OU-${TEXTRESET}
 4. Provisionar e integrar um servidor FreeRADIUS

${RED}Cada servidor deve ser instalado em uma instância de servidor (VM/Hardware) separada${TEXTRESET}

O que este script faz:
 1. Aplica o contexto apropriado do SELinux e regras de firewall
 2. Instala os repositórios e dependências necessárias
 3. Compila pacotes do Samba (se estiver implantando AD)
 4. Configura o sistema conforme necessário, com base nas suas respostas
 5. Fornece testes para a plataforma configurada
 6. Instala ferramentas de gerenciamento de servidor

*********************************************

EOF

read -p "Pressione qualquer tecla para continuar"

items=(1 "Instalar Primeiro Servidor AD/Criar Domínio"
  2 "Instalar Servidor AD Secundário/Terciário"
  3 "Instalar um Servidor Membro para Serviços de Arquivo/Impressão"
  4 "Instalar Servidor FreeRADIUS"
)

while choice=$(dialog --title "Instalador do Servidor" \
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
clear # limpa após o usuário pressionar Cancelar
