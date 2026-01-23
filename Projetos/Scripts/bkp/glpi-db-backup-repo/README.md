# GLPI DB Backup (FULL semanal + incremental diário via binlog)

Repo simples e direto para backup **somente do banco** do GLPI (MySQL/MariaDB), sem parar serviço.

## O que faz
- Executa **diariamente** (via cron)
- **FULL semanal** (configurável por dia da semana)
- **Incremental diário real** via **binlog** (copia/compacta binlogs após `FLUSH BINARY LOGS`)
- Mantém somente os **últimos 7 dias** (pastas por data)
- Logs em `/var/log/glpi-backup/`

> Importante: incremental real requer **binlog habilitado** no MySQL/MariaDB.

---

## Estrutura
```
.
├── scripts/
│   └── glpi-db-backup.sh
├── cron/
│   └── glpi-db-backup.cron
├── config/
│   └── db.pass.example
├── docs/
│   └── mysql-user-permissions.sql
└── README.md
```

---

## Instalação rápida

### 1) Copie o script
```bash
sudo install -m 750 scripts/glpi-db-backup.sh /usr/local/sbin/glpi-db-backup.sh
sudo chown root:root /usr/local/sbin/glpi-db-backup.sh
```

### 2) Configure a senha do usuário de backup
```bash
sudo install -d -m 700 /etc/glpi-backup
sudo cp config/db.pass.example /etc/glpi-backup/db.pass
sudo nano /etc/glpi-backup/db.pass
sudo chmod 600 /etc/glpi-backup/db.pass
```

### 3) Crie o usuário/permissões no MySQL/MariaDB
```bash
mysql -u root -p < docs/mysql-user-permissions.sql
```
Edite o arquivo SQL se precisar ajustar host/senha/database.

### 4) Agende no cron (diário às 02:15)
```bash
sudo cp cron/glpi-db-backup.cron /etc/cron.d/glpi-db-backup
sudo chmod 644 /etc/cron.d/glpi-db-backup
```

### 5) Teste manual
```bash
sudo /usr/local/sbin/glpi-db-backup.sh
tail -f /var/log/glpi-backup/glpi-db-backup_$(date +%F).log
ls -lh /var/backups/glpi-db/
```

---

## Pré-requisito: binlog habilitado
Verifique:
```sql
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'log_bin_basename';
```

Se `log_bin` estiver `OFF`, habilite no arquivo de config do MySQL/MariaDB (ex.: `/etc/my.cnf`, `/etc/mysql/my.cnf`, `/etc/mysql/mariadb.conf.d/*.cnf`):
```ini
[mysqld]
log_bin = mysql-bin
binlog_format = ROW
binlog_expire_logs_seconds = 604800
```

---

## Restore (visão geral)
1) Restaure o FULL:
```bash
zcat /var/backups/glpi-db/YYYY-MM-DD/glpi_full_*.sql.gz | mysql -u root -p glpi10
```

2) Aplique binlogs (do(s) dia(s) após o FULL):
```bash
zcat /var/backups/glpi-db/YYYY-MM-DD/binlogs/mysql-bin.*.gz | mysql -u root -p
```

---

## Notas
- O FULL usa `--single-transaction` (consistente para InnoDB) e **não para o serviço**.
- O incremental via binlog é o método “de adulto” para restore ponto-a-ponto.

