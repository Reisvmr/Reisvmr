#!/bin/bash

# Autor: Vinicius Reis
# Objetivo: Realizar escaneamento de vulnerabilidades em uma URL fornecida utilizando o OWASP ZAP.
#           O script pode realizar escaneamento ativo ou passivo e envia relatórios por e-mail.
# Versão: 1.0
# Data: 15/01/2025

# Verifica se a URL foi passada como parâmetro
if [ -z "$1" ]; then
  echo "Erro: Nenhuma URL fornecida. Uso: ./zap_scan.sh <URL> [<TIPO_DE_TESTE>]"
  exit 1
fi

cd /home/analista/relatorios

# Obtém a URL e o tipo de teste
TARGET_URL=$1
TEST_TYPE=$2

# Define o comportamento padrão como escaneamento completo
if [ -z "$TEST_TYPE" ]; then
  TEST_TYPE="--active"
fi

# Valida o tipo de teste
if [[ "$TEST_TYPE" != "--active" && "$TEST_TYPE" != "--passive" ]]; then
  echo "Erro: Tipo de teste inválido. Use --active, --passive ou deixe vazio para o escaneamento completo."
  exit 1
fi

# Define a configuração para testes ativos
if [ "$TEST_TYPE" == "--active" ]; then
  ACTIVE_SCANNING=true
else
  ACTIVE_SCANNING=false
fi

# Extrai o domínio do site
domain=$(echo "$TARGET_URL" | awk -F[/:] '{print $4}')

# Verifica se o domínio foi extraído corretamente
if [ -z "$domain" ]; then
  echo "Erro: Não foi possível extrair o domínio da URL fornecida. Saindo."
  exit 1
fi

# Gera o nome do arquivo de relatório e log com a data e hora do scan
current_date=$(date +"%Y%m%d_%H%M%S")
report_name="${domain}_scan_${current_date}.xml"
log_name="${domain}_scan_${current_date}.log"

# Cria o arquivo de variáveis do Docker
cat <<EOL > variables.env
TARGET_URL=$TARGET_URL
ACTIVE_SCANNING=$ACTIVE_SCANNING
EOL

# Marca o início da execução
start_time=$(date +%s)
echo "Iniciando escaneamento de $TARGET_URL às $(date)" > $log_name

# Executa o comando Docker e redireciona a saída para o log
if [ "$ACTIVE_SCANNING" == "true" ]; then
  echo "Modo: Testes Ativos" >> $log_name
  docker run --network="host" --env-file=variables.env \
      -v $(pwd):/zap/wrk/:rw -t ghcr.io/zaproxy/zaproxy:stable zap-full-scan.py \
      -t $TARGET_URL -g gen.conf -x $report_name >> $log_name 2>&1
else
  echo "Modo: Escaneamento Passivo" >> $log_name
  docker run --network="host" --env-file=variables.env \
      -v $(pwd):/zap/wrk/:rw -t ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
      -t $TARGET_URL -x $report_name >> $log_name 2>&1
fi

# Verifica o status da execução
if [ $? -eq 0 ]; then
  echo "Escaneamento concluído com sucesso." >> $log_name
else
  echo "Erro durante o escaneamento." >> $log_name
fi

# Calcula o tempo total de execução
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Tempo total de execução: ${duration}s" >> $log_name

echo "Log gerado: $log_name"
echo "Relatório gerado: $report_name"

# Configuração do e-mail com s-nail
MAIL_TO="E_MAIL_DESTINATARIO"
MAIL_SUBJECT="Relatório de escaneamento - $domain"
MAIL_BODY="Prezados, o relatório de escaneamento do domínio $domain está em anexo."
MAIL_SENDER="IP_SERVIDOR_DE_ENVIO_DE_E-MAIL"
SMTP_SERVER="smtp.exemplo.com.br"  # Substitua pelo seu servidor SMTP
SMTP_PORT="25"                          # Porta SMTP (pode ser 465 ou 25, dependendo do servidor)

# Configura o s-nail para usar o servidor de relé SMTP sem autenticação
export SMTP_SERVER
export SMTP_PORT

# Enviar e-mail com o relatório em anexo utilizando s-nail
echo "$MAIL_BODY" | s-nail -s "$MAIL_SUBJECT" -a "$report_name" "$MAIL_TO" \
  -S smtp="$SMTP_SERVER:$SMTP_PORT" \
  -S from="$MAIL_SENDER"