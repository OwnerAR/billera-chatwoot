# Panduan Deployment Billera Chatwoot

## Deployment dengan Docker Compose

### 1. Persiapan

Pastikan Anda sudah memiliki:
- Docker dan Docker Compose terinstall
- File `.env` dengan konfigurasi yang sesuai
- Akses ke Docker Hub image: `etan1997/billera-chatwoot:latest`

### 2. Setup Environment Variables

Buat file `.env` berdasarkan `.env.example` dan sesuaikan konfigurasi:

#### Generate SECRET_KEY_BASE

Ada beberapa cara untuk generate `SECRET_KEY_BASE`:

**Opsi 1: Menggunakan Rails (Recommended)**
```bash
# Jika Anda memiliki Rails environment
docker run --rm etan1997/billera-chatwoot:latest bundle exec rake secret

# Atau jika sudah clone repository
bundle exec rake secret
```

**Opsi 2: Menggunakan Docker Container**
```bash
# Generate menggunakan container yang sudah ada
docker-compose -f docker-compose.production.yaml run --rm rails bundle exec rake secret
```

**Opsi 3: Menggunakan OpenSSL (Alternative)**
```bash
# Generate 64 karakter random string
openssl rand -hex 32
```

**Opsi 4: Menggunakan Bash (Alternative)**
```bash
# Generate 63 karakter alphanumeric
head /dev/urandom | tr -dc A-Za-z0-9 | head -c 63
```

**Catatan:** `SECRET_KEY_BASE` harus alphanumeric dan hindari special characters. Minimal 30 karakter.

#### Konfigurasi .env

```bash
# Database
POSTGRES_HOST=postgres
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DATABASE=chatwoot

# Redis
REDIS_URL=redis://:your_redis_password@redis:6379
REDIS_PASSWORD=your_redis_password

# Rails
SECRET_KEY_BASE=<paste_secret_key_dari_generate_diatas>
RAILS_ENV=production

# Application
FRONTEND_URL=https://your-domain.com
FORCE_SSL=true
```

### 3. Deploy dengan Docker Compose

```bash
# Pull image terbaru
docker pull etan1997/billera-chatwoot:latest

# Jalankan services
docker-compose -f docker-compose.production.yaml up -d

# Setup database (hanya pertama kali)
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails db:chatwoot_prepare

# Cek status
docker-compose -f docker-compose.production.yaml ps
```

### 4. Update Deployment

```bash
# Pull image terbaru
docker pull etan1997/billera-chatwoot:latest

# Restart services
docker-compose -f docker-compose.production.yaml restart rails sidekiq

# Run migrations (jika ada)
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails db:migrate
```

## Deployment ke Docker App Platform

### Opsi 1: Menggunakan Docker App Compose

1. **Buat `app.yaml` untuk Docker App:**

```yaml
version: '3.8'
services:
  rails:
    image: etan1997/billera-chatwoot:latest
    environment:
      - RAILS_ENV=production
      - NODE_ENV=production
      - INSTALLATION_ENV=docker
    env_file: .env
    ports:
      - "3000:3000"
    depends_on:
      - postgres
      - redis
    entrypoint: docker/entrypoints/rails.sh
    command: ['bundle', 'exec', 'rails', 's', '-p', '3000', '-b', '0.0.0.0']
    restart: always

  sidekiq:
    image: etan1997/billera-chatwoot:latest
    environment:
      - RAILS_ENV=production
      - NODE_ENV=production
      - INSTALLATION_ENV=docker
    env_file: .env
    depends_on:
      - postgres
      - redis
    command: ['bundle', 'exec', 'sidekiq', '-C', 'config/sidekiq.yml']
    restart: always

  postgres:
    image: pgvector/pgvector:pg16
    environment:
      - POSTGRES_DB=chatwoot
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: always

  redis:
    image: redis:alpine
    command: ["sh", "-c", "redis-server --requirepass \"${REDIS_PASSWORD}\""]
    volumes:
      - redis_data:/data
    restart: always

volumes:
  postgres_data:
  redis_data:
```

2. **Deploy dengan Docker App CLI:**

```bash
# Install Docker App CLI (jika belum)
# macOS: brew install docker-app

# Deploy
docker-app deploy app.yaml --set-file .env
```

### Opsi 2: Menggunakan Docker Compose di Server

1. **Copy file ke server:**

```bash
scp docker-compose.production.yaml user@server:/path/to/app/
scp .env user@server:/path/to/app/
```

2. **SSH ke server dan deploy:**

```bash
ssh user@server
cd /path/to/app

# Pull image
docker pull etan1997/billera-chatwoot:latest

# Deploy
docker-compose -f docker-compose.production.yaml up -d

# Setup database
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails db:chatwoot_prepare
```

### Opsi 3: Menggunakan Docker Swarm

```bash
# Initialize swarm (jika belum)
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.production.yaml billera-chatwoot

# Cek status
docker stack services billera-chatwoot
```

## Reverse Proxy dengan Nginx

Tambahkan konfigurasi Nginx untuk reverse proxy:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Monitoring & Logs

```bash
# View logs
docker-compose -f docker-compose.production.yaml logs -f rails
docker-compose -f docker-compose.production.yaml logs -f sidekiq

# Check resource usage
docker stats

# Restart service
docker-compose -f docker-compose.production.yaml restart rails
```

## Akses Database

Untuk akses database PostgreSQL di production Docker, lihat panduan lengkap di [ACCESS_DATABASE.md](./ACCESS_DATABASE.md).

**Quick access:**
```bash
# Via Rails Console (Recommended)
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails console

# Via psql langsung
docker-compose -f docker-compose.production.yaml exec postgres psql -U postgres -d chatwoot
```

## Mengubah Installation Config

Untuk mengubah installation config (seperti `BLOCKED_EMAIL_DOMAINS`) di production Docker, lihat panduan lengkap di [MANAGE_INSTALLATION_CONFIG.md](./MANAGE_INSTALLATION_CONFIG.md).

**Quick reference:**
```bash
# Via Rails Console
docker-compose -f docker-compose.production.yaml exec rails bundle exec rails console

# Di console:
config = InstallationConfig.find_or_initialize_by(name: 'BLOCKED_EMAIL_DOMAINS')
config.value = "gmail.com\noutlook.com"
config.locked = false
config.save!
GlobalConfig.clear_cache
```

## Troubleshooting

### Error: "pull access denied for billera-chatwoot"

**Penyebab:** Image belum ada di Docker Hub atau belum login ke Docker Hub.

**Solusi:**

1. **Login ke Docker Hub:**
```bash
docker login -u etan1997
# Masukkan password atau access token saat diminta
```

2. **Pastikan file docker-compose.production.yaml sudah terupdate:**
```bash
# Cek apakah image sudah benar
grep "image:" docker-compose.production.yaml

# Harus menampilkan: image: etan1997/billera-chatwoot:latest
# Bukan: image: billera-chatwoot:latest
```

3. **Pastikan image sudah di-push ke Docker Hub:**
   - Image harus di-push terlebih dahulu melalui GitHub Actions workflow
   - Atau pull image manual jika sudah ada:
   ```bash
   docker pull etan1997/billera-chatwoot:latest
   ```

4. **Jika image belum ada, build lokal sementara:**
```bash
# Build image dari Dockerfile
docker build -t etan1997/billera-chatwoot:latest -f docker/Dockerfile .

# Update docker-compose.production.yaml untuk menggunakan build lokal
# Ganti:
#   image: etan1997/billera-chatwoot:latest
# Dengan:
#   build:
#     context: .
#     dockerfile: docker/Dockerfile
```

### Postgres Container Restart Loop

**Penyebab:** Postgres container terus restart, biasanya karena:
1. POSTGRES_PASSWORD kosong atau tidak valid
2. Volume postgres corrupt atau permission issue
3. Database sudah ada dengan konfigurasi berbeda

**Solusi:**

1. **Cek logs postgres:**
```bash
docker logs billera-chatwoot-postgres-1
# atau
docker-compose -f docker-compose.production.yaml logs postgres
```

2. **Set POSTGRES_PASSWORD di .env:**
```bash
# Edit .env file
POSTGRES_PASSWORD=your_secure_password_here
```

3. **Update docker-compose.production.yaml untuk menggunakan .env:**
```yaml
postgres:
  image: pgvector/pgvector:pg16
  restart: always
  ports:
    - '127.0.0.1:5432:5432'
  volumes:
    - postgres_data:/var/lib/postgresql/data
  env_file: .env  # Tambahkan ini
  environment:
    - POSTGRES_DB=chatwoot
    - POSTGRES_USER=postgres
    - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}  # Ambil dari .env
```

4. **Jika volume corrupt, hapus dan buat ulang:**
```bash
# Stop semua container
docker-compose -f docker-compose.production.yaml down

# Hapus volume postgres (PERINGATAN: Data akan hilang!)
docker volume rm billera-chatwoot_postgres_data

# Start ulang
docker-compose -f docker-compose.production.yaml up -d
```

5. **Cek permission volume:**
```bash
# Cek ownership
ls -la /var/lib/docker/volumes/billera-chatwoot_postgres_data/_data

# Fix permission jika perlu (ganti user:group sesuai kebutuhan)
chown -R 999:999 /var/lib/docker/volumes/billera-chatwoot_postgres_data/_data
```

### Database connection error
- Pastikan POSTGRES_HOST, POSTGRES_USERNAME, dan POSTGRES_PASSWORD sudah benar
- Cek apakah postgres container sudah running
- Pastikan POSTGRES_DATABASE sesuai dengan yang di-set di postgres container

### Redis connection error
- Pastikan REDIS_URL dan REDIS_PASSWORD sudah benar
- Cek apakah redis container sudah running

### Image tidak ditemukan
- Pastikan image sudah di-push ke Docker Hub: `docker pull etan1997/billera-chatwoot:latest`
- Cek koneksi internet dan akses ke Docker Hub
- Login ke Docker Hub dengan: `docker login -u etan1997`

