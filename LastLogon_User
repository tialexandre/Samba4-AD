#!/bin/bash

# Função para converter o lastLogon do AD em segundos Unix (EPOCH)
convert_lastlogon_to_epoch() {
    local ad_timestamp=$1
    # Remove os últimos 7 dígitos do timestamp do AD e converte para segundos Unix
    echo $(( ($ad_timestamp / 10000000) - 11644473600 ))
}

# Lista os usuários e verifica a data do último login
read -p "Digite o nome do usuário:" user
# Obtém o valor do lastLogon do usuário em Windows FileTime
last_logon=$(samba-tool user show $user | grep "lastLogon:" | awk '{print $2}')

# Verifica o status do usuário para garantir que ele não esteja desativado
user_status=$(samba-tool user show $user | grep "userAccountControl:" | awk '{print $2}')

# Se userAccountControl indicar que o usuário está desativado, informe o status e saia
if [ "$user_status" -eq 514 ]; then
    echo "Usuário $user está desativado"
    exit 1
fi

# Verifica se o usuário tem um registro de último login
if [ -n "$last_logon" ]; then
    # Converte o lastLogon para o formato Unix e exibe a data de último login
    last_logon_epoch=$(convert_lastlogon_to_epoch $last_logon)
    
    # Converte o timestamp em uma data legível (formato humano)
    last_logon_human=$(date -d @"$last_logon_epoch" "+%Y-%m-%d %H:%M:%S")

    echo "A data de último login é: $last_logon_human"
else
    echo "Não foi possível encontrar o registro de último login para o usuário $user"
fi
