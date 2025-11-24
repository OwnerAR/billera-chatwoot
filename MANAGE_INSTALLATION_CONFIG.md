# Panduan Mengubah Installation Config di Production Docker

Ada beberapa cara untuk mengubah `InstallationConfig` di production yang menggunakan Docker:

## Metode 1: Via Rails Console (Recommended)

Cara termudah dan paling aman untuk production Docker:

```bash
# Masuk ke Rails container
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails console

# Atau jika menggunakan docker langsung
docker exec -it billera-chatwoot-rails-1 bundle exec rails console
```

### Contoh: Update BLOCKED_EMAIL_DOMAINS

```ruby
# Cek config saat ini
config = InstallationConfig.find_by(name: 'BLOCKED_EMAIL_DOMAINS')
puts config&.value

# Update dengan domain baru (satu domain per baris)
config = InstallationConfig.find_or_initialize_by(name: 'BLOCKED_EMAIL_DOMAINS')
config.value = "gmail.com\noutlook.com\nyahoo.com\ntempmail.com"
config.locked = false  # Pastikan tidak locked agar bisa diubah
config.save!

# Verifikasi
puts InstallationConfig.find_by(name: 'BLOCKED_EMAIL_DOMAINS').value

# Clear cache agar perubahan langsung efektif
GlobalConfig.clear_cache
```

### Contoh: Update Config Lainnya

```ruby
# Update ENABLE_ACCOUNT_SIGNUP
config = InstallationConfig.find_or_initialize_by(name: 'ENABLE_ACCOUNT_SIGNUP')
config.value = 'false'
config.locked = false
config.save!
GlobalConfig.clear_cache

# Update BRAND_NAME
config = InstallationConfig.find_or_initialize_by(name: 'BRAND_NAME')
config.value = 'Billera Chat'
config.locked = false
config.save!
GlobalConfig.clear_cache
```

## Metode 2: Via Rails Runner (One-liner)

Untuk update cepat tanpa masuk ke console:

```bash
# Update BLOCKED_EMAIL_DOMAINS
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails runner "
config = InstallationConfig.find_or_initialize_by(name: 'BLOCKED_EMAIL_DOMAINS')
config.value = 'gmail.com\noutlook.com'
config.locked = false
config.save!
GlobalConfig.clear_cache
"

# Update ENABLE_ACCOUNT_SIGNUP
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails runner "
config = InstallationConfig.find_or_initialize_by(name: 'ENABLE_ACCOUNT_SIGNUP')
config.value = 'false'
config.locked = false
config.save!
GlobalConfig.clear_cache
"
```

## Metode 3: Via Super Admin Dashboard

Jika Anda sudah setup Super Admin account, bisa akses via web UI:

1. Login sebagai Super Admin
2. Buka: `https://your-domain.com/super_admin/installation_configs`
3. Atau: `https://your-domain.com/super_admin/settings?config=internal`

**Catatan:** `BLOCKED_EMAIL_DOMAINS` ada di kategori "internal" config.

## Metode 4: Via Database Langsung (Advanced)

Jika Rails console tidak tersedia, bisa langsung via PostgreSQL:

```bash
# Masuk ke postgres container
docker-compose -f docker-compose.production.yaml exec postgres psql -U postgres -d chatwoot

# Atau via docker langsung
docker exec -it billera-chatwoot-postgres-1 psql -U postgres -d chatwoot
```

```sql
-- Cek config saat ini
SELECT name, serialized_value FROM installation_configs WHERE name = 'BLOCKED_EMAIL_DOMAINS';

-- Update config (format JSONB)
UPDATE installation_configs 
SET serialized_value = '{"value": "gmail.com\noutlook.com"}'::jsonb,
    locked = false,
    updated_at = NOW()
WHERE name = 'BLOCKED_EMAIL_DOMAINS';

-- Jika belum ada, insert
INSERT INTO installation_configs (name, serialized_value, locked, created_at, updated_at)
VALUES ('BLOCKED_EMAIL_DOMAINS', '{"value": "gmail.com\noutlook.com"}'::jsonb, false, NOW(), NOW())
ON CONFLICT (name) DO UPDATE
SET serialized_value = EXCLUDED.serialized_value,
    locked = false,
    updated_at = NOW();
```

**PENTING:** Setelah update via database, perlu clear Redis cache:

```bash
# Masuk ke Rails console dan clear cache
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails runner "GlobalConfig.clear_cache"
```

## Script Helper untuk Update BLOCKED_EMAIL_DOMAINS

Buat file `update_blocked_domains.sh`:

```bash
#!/bin/bash
# Usage: ./update_blocked_domains.sh "gmail.com\noutlook.com\nyahoo.com"

DOMAINS="$1"
CONTAINER_NAME="billera-chatwoot-rails-1"

if [ -z "$DOMAINS" ]; then
  echo "Usage: $0 \"domain1.com\ndomain2.com\""
  exit 1
fi

docker exec -it $CONTAINER_NAME bundle exec rails runner "
config = InstallationConfig.find_or_initialize_by(name: 'BLOCKED_EMAIL_DOMAINS')
config.value = '$DOMAINS'
config.locked = false
config.save!
GlobalConfig.clear_cache
puts 'BLOCKED_EMAIL_DOMAINS updated successfully'
puts 'Domains: ' + config.value.inspect
"
```

Cara pakai:
```bash
chmod +x update_blocked_domains.sh
./update_blocked_domains.sh "gmail.com\noutlook.com\nyahoo.com"
```

## Daftar Config yang Bisa Diubah

### General Configs
- `ENABLE_ACCOUNT_SIGNUP` - Enable/disable signup
- `BRAND_NAME` - Nama brand
- `INSTALLATION_NAME` - Nama installation
- `FRONTEND_URL` - URL frontend
- `FORCE_SSL` - Force SSL

### Internal Configs (Enterprise)
- `BLOCKED_EMAIL_DOMAINS` - Domain email yang diblokir
- `CHATWOOT_INBOX_TOKEN` - Inbox token
- `DASHBOARD_SCRIPTS` - Custom scripts
- `ANALYTICS_TOKEN` - Analytics token

### Custom Branding
- `LOGO` - Logo URL
- `LOGO_DARK` - Logo dark mode
- `LOGO_THUMBNAIL` - Logo thumbnail
- `BRAND_URL` - Brand URL
- `TERMS_URL` - Terms URL
- `PRIVACY_URL` - Privacy URL

## Tips Penting

1. **Selalu clear cache setelah update:**
   ```ruby
   GlobalConfig.clear_cache
   ```

2. **Pastikan `locked = false`** agar config bisa diubah:
   ```ruby
   config.locked = false
   ```

3. **Format untuk multi-line values** (seperti BLOCKED_EMAIL_DOMAINS):
   - Gunakan `\n` untuk newline
   - Contoh: `"domain1.com\ndomain2.com\ndomain3.com"`

4. **Verifikasi perubahan:**
   ```ruby
   # Di Rails console
   GlobalConfigService.load('BLOCKED_EMAIL_DOMAINS', '')
   ```

5. **Backup sebelum update:**
   ```ruby
   # Backup config
   config = InstallationConfig.find_by(name: 'BLOCKED_EMAIL_DOMAINS')
   puts config.value  # Copy value ini sebagai backup
   ```

## Troubleshooting

### Config tidak berubah setelah update
- Pastikan sudah clear cache: `GlobalConfig.clear_cache`
- Restart Rails container jika perlu: `docker-compose restart rails`

### Error "locked = true"
- Set `locked = false` sebelum save
- Beberapa config memang locked dan tidak bisa diubah

### Format tidak sesuai
- Untuk string biasa, langsung assign: `config.value = "string"`
- Untuk multi-line, gunakan `\n`: `config.value = "line1\nline2"`
- Untuk boolean, gunakan string: `config.value = "true"` atau `config.value = "false"`

