# Panduan Akses Database di Production Docker

## Metode 1: Via Docker Compose (Recommended)

### Masuk ke PostgreSQL Container

```bash
# Masuk ke postgres container
docker-compose -f docker-compose.production.yaml exec postgres psql -U postgres -d chatwoot

# Atau jika container name berbeda
docker exec -it billera-chatwoot-postgres-1 psql -U postgres -d chatwoot
```

### Setelah masuk ke psql, Anda bisa:

```sql
-- Cek semua tables
\dt

-- Cek installation_configs
SELECT * FROM installation_configs;

-- Cek config tertentu
SELECT name, serialized_value FROM installation_configs WHERE name = 'BLOCKED_EMAIL_DOMAINS';

-- Update config langsung
UPDATE installation_configs 
SET serialized_value = '{"value": "gmail.com\noutlook.com"}'::jsonb,
    locked = false,
    updated_at = NOW()
WHERE name = 'BLOCKED_EMAIL_DOMAINS';

-- Keluar dari psql
\q
```

## Metode 2: Via Rails Console (Lebih Mudah)

### Masuk ke Rails Console

```bash
# Via docker-compose
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails console

# Atau via docker langsung
docker exec -it billera-chatwoot-rails-1 bundle exec rails console
```

### Di Rails Console:

```ruby
# Cek koneksi database
ActiveRecord::Base.connection

# Cek semua installation configs
InstallationConfig.all.each { |c| puts "#{c.name}: #{c.value}" }

# Cek config tertentu
config = InstallationConfig.find_by(name: 'BLOCKED_EMAIL_DOMAINS')
puts config&.value

# Update config
config = InstallationConfig.find_or_initialize_by(name: 'BLOCKED_EMAIL_DOMAINS')
config.value = "gmail.com\noutlook.com\nyahoo.com"
config.locked = false
config.save!

# Cek users
User.count
User.first

# Cek accounts
Account.count
Account.first

# Cek conversations
Conversation.count

# Akses database langsung via SQL
ActiveRecord::Base.connection.execute("SELECT * FROM installation_configs LIMIT 5")
```

## Metode 3: Via External Database Client

### Dapatkan Connection Info

```bash
# Cek postgres port
docker-compose -f docker-compose.production.yaml ps postgres

# Atau cek port mapping
docker port billera-chatwoot-postgres-1
```

### Koneksi dari Host Machine

Jika postgres port sudah di-expose (biasanya `127.0.0.1:5432`), Anda bisa connect dari host:

**Connection Details:**
- **Host:** `localhost` atau `127.0.0.1`
- **Port:** `5432` (default, cek di docker-compose)
- **Database:** `chatwoot`
- **Username:** `postgres`
- **Password:** (cek di `.env` file, variable `POSTGRES_PASSWORD`)

### Menggunakan psql dari Host

```bash
# Install psql client (jika belum ada)
# macOS: brew install postgresql
# Ubuntu: sudo apt-get install postgresql-client

# Connect
psql -h localhost -p 5432 -U postgres -d chatwoot
```

### Menggunakan GUI Tools

**DBeaver / pgAdmin / TablePlus:**
- Host: `localhost`
- Port: `5432`
- Database: `chatwoot`
- Username: `postgres`
- Password: (dari `.env` file)

## Metode 4: Export/Import Database

### Export Database

```bash
# Export seluruh database
docker-compose -f docker-compose.production.yaml exec postgres pg_dump -U postgres chatwoot > backup.sql

# Export hanya schema
docker-compose -f docker-compose.production.yaml exec postgres pg_dump -U postgres -s chatwoot > schema.sql

# Export hanya data
docker-compose -f docker-compose.production.yaml exec postgres pg_dump -U postgres -a chatwoot > data.sql
```

### Import Database

```bash
# Import dari backup
docker-compose -f docker-compose.production.yaml exec -T postgres psql -U postgres chatwoot < backup.sql
```

## Quick Commands untuk Installation Config

### Update BLOCKED_EMAIL_DOMAINS via Rails Console

```bash
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails runner "
config = InstallationConfig.find_or_initialize_by(name: 'BLOCKED_EMAIL_DOMAINS')
config.value = 'gmail.com\noutlook.com\nyahoo.com'
config.locked = false
config.save!
GlobalConfig.clear_cache
puts 'Updated: ' + config.value.inspect
"
```

### Update via psql

```bash
docker-compose -f docker-compose.production.yaml exec postgres psql -U postgres -d chatwoot -c "
UPDATE installation_configs 
SET serialized_value = '{\"value\": \"gmail.com\noutlook.com\"}'::jsonb,
    locked = false,
    updated_at = NOW()
WHERE name = 'BLOCKED_EMAIL_DOMAINS';
"
```

## Troubleshooting

### Error: "password authentication failed"
- Pastikan password di `.env` file sesuai
- Cek variable `POSTGRES_PASSWORD` di `.env`

### Error: "could not connect to server"
- Pastikan postgres container running: `docker ps`
- Cek port mapping di `docker-compose.production.yaml`
- Pastikan port tidak di-bind ke `127.0.0.1` saja (harus accessible)

### Error: "database does not exist"
- Cek nama database di `.env`: `POSTGRES_DATABASE`
- Default: `chatwoot`

### Container tidak running
```bash
# Start container
docker-compose -f docker-compose.production.yaml up -d postgres

# Cek logs
docker-compose -f docker-compose.production.yaml logs postgres
```

## Useful SQL Queries

### Cek Installation Configs

```sql
-- List semua configs
SELECT name, serialized_value->>'value' as value, locked 
FROM installation_configs 
ORDER BY name;

-- Cek config tertentu
SELECT name, serialized_value->>'value' as value 
FROM installation_configs 
WHERE name = 'BLOCKED_EMAIL_DOMAINS';

-- Update config
UPDATE installation_configs 
SET serialized_value = jsonb_set(
  serialized_value, 
  '{value}', 
  '"new_value_here"'::jsonb
),
locked = false,
updated_at = NOW()
WHERE name = 'BLOCKED_EMAIL_DOMAINS';
```

### Cek Users & Accounts

```sql
-- Count users
SELECT COUNT(*) FROM users;

-- List users
SELECT id, email, name, created_at FROM users LIMIT 10;

-- Count accounts
SELECT COUNT(*) FROM accounts;

-- List accounts
SELECT id, name, created_at FROM accounts LIMIT 10;
```

### Backup Specific Table

```sql
-- Export installation_configs
\copy installation_configs TO '/tmp/installation_configs.csv' CSV HEADER;
```

## Security Notes

⚠️ **PENTING:**
- Jangan expose postgres port ke public tanpa password yang kuat
- Gunakan password yang kuat untuk production
- Backup database secara berkala
- Jangan commit `.env` file ke git

