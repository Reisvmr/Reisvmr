# Zabbix Full Backup (Servidor)

Backup completo do Zabbix (config + scripts + frontend + banco), pensado para rodar em Linux via cron.

## O que faz
- Backup **FULL** diário (ou manual) do Zabbix Server
- Inclui:
  - **Dump do banco** (MySQL/MariaDB ou PostgreSQL)
  - **Configurações** (`/etc/zabbix`)
  - **AlertScripts / ExternalScripts**
  - **Frontend** (se existir, ex.: `/usr/share/zabbix`)
  - Arquivos extras comuns (nginx/apache/php-fpm) *se encontrados*
- Compacta em `.tar.gz`
- Mantém somente os **últimos 7** backups
- **Não para serviços** por padrão (dump consistente para InnoDB via `--single-transaction`)
  - Opcional: parar serviços via `STOP_SERVICES=yes`

## Estrutura
```
.
├── scripts/
│   └── zabbix-full-backup.sh
├── cron/
│   └── zabbix-full-backup.cron
├── config/
│   ├── db.pass.example
│   └── db.type.example
├── docs/
│   └── db-user-permissions.md
└── README.md
```

## Instalação rápida
### 1) Instalar script
```bash
sudo install -m 750 scripts/zabbix-full-backup.sh /usr/local/sbin/zabbix-full-backup.sh
sudo chown root:root /usr/local/sbin/zabbix-full-backup.sh
```

### 2) Configurar credenciais do banco
```bash
sudo install -d -m 700 /etc/zabbix-backup
sudo cp config/db.pass.example /etc/zabbix-backup/db.pass
sudo chmod 600 /etc/zabbix-backup/db.pass

# Tipo do banco: mysql | postgres
sudo cp config/db.type.example /etc/zabbix-backup/db.type
sudo chmod 600 /etc/zabbix-backup/db.type
```

### 3) Agendar no cron (02:30 diário)
```bash
sudo cp cron/zabbix-full-backup.cron /etc/cron.d/zabbix-full-backup
sudo chmod 644 /etc/cron.d/zabbix-full-backup
```

### 4) Teste manual
```bash
sudo /usr/local/sbin/zabbix-full-backup.sh
tail -f /var/log/zabbix-backup/zabbix-backup_$(date +%F).log
ls -lh /var/backups/zabbix/
```

## Restore (visão geral)
1) Descompacte o pacote:
```bash
tar -xzf zabbix_full_YYYY-MM-DD_HHMMSS.tar.gz -C /tmp/zbx-restore
```

2) Restaure arquivos (ajuste paths e owner):
```bash
sudo rsync -aHAX /tmp/zbx-restore/etc_zabbix/ /etc/zabbix/
sudo rsync -aHAX /tmp/zbx-restore/usr_lib_zabbix/ /usr/lib/zabbix/
```

3) Restaure DB:
- MySQL/MariaDB:
```bash
zcat /tmp/zbx-restore/db/zabbix.sql.gz | mysql -u root -p zabbix
```
- PostgreSQL:
```bash
zcat /tmp/zbx-restore/db/zabbix.sql.gz | sudo -u postgres psql zabbix
```

## Notas importantes
- Se seu banco é grande, considere executar o dump fora do horário de pico.
- Para segurança, nunca commite `db.pass` (o repo já traz `.gitignore`).
