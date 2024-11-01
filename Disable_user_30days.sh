#!/bin/bash

# Define o período de inatividade em dias
inactive_days=30

# Define a data limite para o último login em segundos Unix (EPOCH)
cutoff_date=$(date -d "$inactive_days days ago" +%s)

# Função para converter o lastLogon do AD em segundos Unix (EPOCH)
convert_lastlogon_to_epoch() {
    local ad_timestamp=$1
    # Remove os últimos 7 dígitos do timestamp do AD e converte para segundos Unix
    echo $(( ($ad_timestamp / 10000000) - 11644473600 ))
}

# Lista os usuários e verifica a data do último login
for user in $(samba-tool user list); do
    # Obtém o valor do lastLogon do usuário em Windows FileTime
    last_logon=$(samba-tool user show $user | grep "lastLogon:" | awk '{print $2}')
    
    # Verifica o status do usuário para garantir que ele não esteja desativado
    user_status=$(samba-tool user show $user | grep "userAccountControl:" | awk '{print $2}')
    
    # Se userAccountControl indicar que o usuário está desativado, pule para o próximo usuário
    if [ "$user_status" -eq 514 ]; then
       # echo "Usuário $user já está desativado. Nenhuma ação necessária."
        continue
    fi

    # Verifica se o usuário tem um registro de último login
    if [ -n "$last_logon" ]; then
        # Converte o lastLogon para o formato Unix e compara com a data limite
        last_logon_epoch=$(convert_lastlogon_to_epoch $last_logon)

        if [ $last_logon_epoch -lt $cutoff_date ]; then
            # Desativa o usuário se estiver inativo por mais do que o período definido
            samba-tool user disable $user
            echo "Usuário $user desativado por inatividade."
        else
           i# echo "Usuário $user está ativo ou dentro do período de login recente."
        fi
    else
        # Desativa o usuário que não possui data de login registrada, exceto administradores
        if [ "$user" != "Administrador" ] && [ "$user" != "tiagocpd" ]; then
            samba-tool user disable $user
            echo "Usuário $user não possui data de login registrada e foi desativado."
        fi
    fi
done
