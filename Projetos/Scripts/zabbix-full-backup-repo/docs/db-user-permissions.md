# Permissões do usuário de backup (referência)

## MySQL/MariaDB (dump consistente sem parar serviço)
Exemplo (ajuste host/senha conforme seu ambiente):

```sql
CREATE USER 'zabbix_backup'@'127.0.0.1' IDENTIFIED BY 'SENHA_FORTE_AQUI';
GRANT SELECT, SHOW VIEW, TRIGGER, EVENT, LOCK TABLES ON zabbix.* TO 'zabbix_backup'@'127.0.0.1';
FLUSH PRIVILEGES;
```

> `mysqldump --single-transaction` é consistente para tabelas InnoDB e não requer parar o serviço.

## PostgreSQL
Crie um usuário com permissão de leitura no schema/tabelas do banco `zabbix`.
O `pg_dump` geralmente requer que o usuário tenha acesso de leitura a todos os objetos do banco.

```sql
CREATE USER zabbix_backup WITH PASSWORD 'SENHA_FORTE_AQUI';
GRANT CONNECT ON DATABASE zabbix TO zabbix_backup;
\c zabbix
GRANT USAGE ON SCHEMA public TO zabbix_backup;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO zabbix_backup;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO zabbix_backup;
```
