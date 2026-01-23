## Projeto: Automação de Escaneamento de Segurança com OWASP ZAP

### **Descrição do Projeto**

Este projeto tem como objetivo automatizar o escaneamento de segurança de aplicações web utilizando o OWASP ZAP (Zed Attack Proxy) em um contêiner Docker. O script desenvolvido permite executar escaneamentos completos, gerando relatórios detalhados com base no domínio do site e incluindo a data e hora do escaneamento no nome do arquivo de saída. Agora, o script também gera logs com informações sobre o sucesso ou falha do escaneamento, o tempo total de execução e permite configurar se os testes ativos serão realizados ou não. Caso nenhum parâmetro seja fornecido, o script executa o escaneamento completo (incluindo testes ativos).

* * *

## **Recursos Utilizados**

-  **Docker**
    
-  **Imagem do OWASP ZAP:** `ghcr.io/zaproxy/zaproxy:stable`
    
-  **Shell Script (Bash)**
    

* * *

## **Requisitos de Servidor para o OWASP ZAP (em Produção):**

1.   **Memória RAM:**
    
    - ### Mínimo de 4** GB** (recomendado 8 GB ou mais para um desempenho ideal).
        
2.   **Processador:**
    
    -  Mínimo de 4** núcleos** (recomendado 8 núcleos ou mais para suportar análises simultâneas).
        
3.   **Espaço em Disco:**
    
    -  Mínimo de **100 GB** para armazenar os dados e logs do ZAP (dependendo da intensidade dos testes, mais espaço pode ser necessário).
        
4.   **Sistema Operacional: Homologado no RED HAT 9**
    

* * *

## **Funcionalidades**

1.   Aceita a URL do site como parâmetro na execução do script.
    
2.   Permite definir se os testes ativos serão realizados durante a execução.
    
3.   Executa um escaneamento completo por padrão, caso nenhum tipo de teste seja especificado.
    
4.   Extrai automaticamente o domínio da URL fornecida.
    
5.   Gera relatórios HTML ou XML  nomeados com base no domínio e na data/hora do escaneamento.
    
6.   Cria automaticamente um arquivo de variáveis para o Docker com a URL do site.
    
7.   Gera logs detalhados da execução, incluindo sucesso/falha e o tempo total de execução.
    
8.   Envia um e-mail com o relatório em anexo no final da analise.
    

* * *

## **Testes Realizados pelo OWASP ZAP**

### O OWASP ZAP realiza os seguintes testes de segurança durante o escaneamento:

1.   **Spidering (Mapeamento):** Navega pelo site para identificar todos os endpoints e links disponíveis.
    
2.   **Escaneamento Passivo:**
    
    -  Detecta vulnerabilidades em respostas HTTP sem interagir diretamente com a aplicação.
        
    -  Exemplos: Cabeçalhos inseguros, cookies mal configurados, falhas de políticas de segurança.
        
3.   **Escaneamento Ativo (opcional):**
    
    -  Realiza testes intrusivos para identificar vulnerabilidades exploráveis.
        
    -  Exemplos: Injeção de SQL, Cross-Site Scripting (XSS), inclusão de arquivos (LFI/RFI).
        
4.   **Análise de Autenticação e Sessões:**
    
    -  Verifica falhas no gerenciamento de autenticação e sessões.
        
    -  Exemplos: Tokens expostos, falta de logout seguro.
        
5.  **Políticas de Segurança:**
    
    -  Avalia a ausência de práticas recomendadas, como o uso de HTTPS ou Content Security Policy (CSP).
        

* * *

## **Problemas Comuns no Modo Ativo**

### Ao utilizar o modo ativo do OWASP ZAP, o site pode sair do ar devido à carga excessiva ou à natureza disruptiva dos testes. Abaixo estão algumas causas comuns e soluções sugeridas:

### **Causas Comuns**

1.   **Carga excessiva:** O modo ativo pode gerar muitas requisições simultâneas, sobrecarregando o servidor.
    
2.   **Testes disruptivos:** Alguns testes simulam vulnerabilidades críticas que podem causar falhas em servidores mal configurados.
    
3.   **Limitações no ambiente do servidor:** Recursos insuficientes (CPU, memória ou banda) podem não suportar a carga gerada.
    
4.   **Reações de segurança:** Ferramentas como firewalls podem bloquear o tráfego, causando indisponibilidade temporária.
    

## **Soluções Sugeridas**

## 1\. **Reduzir a intensidade dos testes**

## Edite o arquivo de configuração (`gen.conf`) para ajustar parâmetros, como o número de requisições simultâneas:

```conf
activeScan.inputVector.threadPerHost=1
activeScan.inputVector.threadPoolSize=5
activeScan.inputVector.delay=1000 # Em milissegundos
```

## Isso reduz a quantidade de requisições feitas em paralelo.

## 2\. **Habilitar modos de teste menos agressivos**

## Substitua o modo ativo por testes menos invasivos (como o modo passivo):

```bash
./zap_scan.sh https://www.exemplo.com/ --passive
```

## 3\. **Testar em um ambiente de homologação**

 Evite escanear diretamente o ambiente de produção. Use uma cópia do site ou um ambiente de homologação para realizar testes ativos.

 4\. **Executar os testes ativos em etapas**

 Divida os testes ativos em lotes menores para reduzir a carga no servidor:

-  Teste páginas específicas.
    
-  Exclua endpoints críticos que não precisam ser testados.
    

## Para excluir URLs específicas, adicione no arquivo de configuração:

```conf
excludeFromScan=https://www.exemplo.com/admin
```

 5\. **Monitorar os recursos do servidor**

 Monitore o uso de CPU, memória e banda do servidor durante o escaneamento com ferramentas como Zabbix, Grafana ou comandos nativos (`top`, `htop`, etc.).

* * *

 **Configuração dos Tipos de Escaneamento**

 Para configurar os tipos de escaneamento realizados pelo OWASP ZAP, você pode definir diretamente no momento da execução do script se os testes ativos devem ser habilitados, ou permitir que o script execute um escaneamento completo por padrão.

 **Parâmetro para Ativar/Desativar Testes Ativos**

### Adicione o segundo parâmetro `--active` ou `--passive` ao executar o script para definir o tipo de escaneamento desejado:

-  **`--active`:** Habilita testes ativos.
    
-  **`--passive`:** Desativa testes ativos (somente escaneamento passivo e spidering).
    
-  **Nenhum parâmetro:** Executa o escaneamento completo (incluindo testes ativos).
    

* * *

### **Estrutura do Projeto**

## **Arquivos Criados**

1.   **Script Principal:** `zap_scan.sh`
    
    -  Realiza todo o processo de escaneamento, geração de relatórios e criação de logs.
        
2. **Arquivo de Variáveis:** `variables.env`
    
    -  Armazena a URL do site a ser escaneado e a configuração de testes ativos.
        
3.   **Logs Gerados:**
    
    -  Arquivos de log no formato `<domínio>_scan_<data_hora>.log`.
        
4.   **Relatórios Gerados:**
    
    -  Relatórios no formato HTML com nomes no padrão `<domínio>_scan_<data_hora>.html`.
        

* * *

## **Pré-requisitos**

1.  ### **Instalações**
    
    -  Certifique-se de que o Docker está instalado e funcionando em sua máquina. Para instalar o Docker, siga as instruções disponíveis em [Docker Documentation](https://docs.docker.com/get-docker/).
        
    -  Inalação do Postfix [How to install and configure Postfix](https://www.redhat.com/en/blog/install-configure-postfix)
        
    -  Instação do s-nail [Instalação do S-NAIL](https://medium.com/@kemalozz/sending-email-using-s-nail-on-rhel-9-with-enhanced-security-measures-6f15e42cc5d2)
        
2.  ### **Permissão para Executar Scripts:**
    
    -  O script deve ter permissões de execução no sistema operacional:
        
        ```bash
        chmod +x zap_scan.sh
        ```
        
3.  ### **Acesso à Internet:**
    
    -  O contêiner precisa acessar a internet para interagir com os sites escaneados.
        

* * *

## **Problemas**

* * *

## **Como Utilizar o Script**

## **Passos para Execução**

1.   Clone ou copie os arquivos do projeto para o seu sistema.
    
2.  ; Certifique-se de que o script `zap_scan.sh` está com permissão de execução:
    
    ```bash
    chmod +x zap_scan.sh
    ```
    
3.   Execute o script passando a URL do site como primeiro parâmetro e, opcionalmente, o tipo de escaneamento como segundo parâmetro:
    
    ```bash
    ./zap_scan.sh <URL_DO_SITE> [<TIPO_DE_TESTE>]
    ```
    
    ### Exemplos:
    
    -  Escaneamento com testes ativos:
        
        ```bash
        ./zap_scan.sh https://www.exemplo.com/ --active
        ```
        
    -  Escaneamento passivo (sem testes ativos):
        
        ```bash
        ./zap_scan.sh https://www.exemplo.com/ --passive
        ```
        
    -  Escaneamento completo (padrão):
        
        ```bash
        ./zap_scan.sh https://www.exemplo.com/
        ```
        
4.   O relatório será gerado no diretório atual com o nome no formato:
    
    ```
    <domínio>_scan_<data_hora>.html
    ```
    
     Exemplo de saída:
    
    ```
    exemplo.com_scan_20250111_154500.html
    ```
    
5.   O log será gerado no diretório atual com o nome no formato:
    
    ```
    <domínio>_scan_<data_hora>.log
    ```
    
     Exemplo de saída:
    
    ```
    exemplo.com_scan_20250111_154500.log
    ```
    

* * *

## **Script Principal: zap_scan.sh**

```bash
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
```

* * *

## **Exemplo de Saída**

Ao executar o script com a URL `https://www.exemplo.com/`, o seguinte relatório e log serão gerados:

### **Relatório:**

```bash
Relatório gerado: exemplo.com_scan_20250111_154500.html
```

 **Log:**

```bash
Log gerado: exemplo.com_scan_20250111_154500.log
```

* * *

### **Notas Adicionais**

- Certifique-se de ter permissão para escanear o site antes de iniciar o processo.
- Para ajustar configurações de escaneamento, edite o arquivo `gen.conf` gerado automaticamente após a execução do script.

* * *

### **Melhorias Futuras**

- Adicionar suporte a múltiplas URLs em uma única execução.
- Integração com ferramentas de CI/CD para automação contínua.
- Opção para salvar relatórios em outros formatos (JSON, ~~XML,~~ HTML), de forma automatizada.
- Adicionar logs detalhados do processo de escaneamento.

* * *

### **Contato**

Autor: Vinicius Reis
E-mail: [contato](mailto:reisvmr@gmail.com)
