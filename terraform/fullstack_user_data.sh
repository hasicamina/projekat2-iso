#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
echo "🔧 Pokrećem provisioning..."

# Ažuriraj sistem i instaliraj osnovne pakete
yum update -y
yum install -y git curl wget

# ISPRAVKA: Instaliraj Node.js na pravi način za Amazon Linux 2
echo "📦 Instaliram Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Provjeri da li je Node.js uspješno instaliran
if ! command -v node &> /dev/null; then
    echo "❌ Node.js instalacija neuspješna, pokušavam alternativni način..."
    # Alternativni način - direktno iz yum
    yum install -y nodejs npm
fi

# Provjeri još jednom
if ! command -v node &> /dev/null; then
    echo "❌ Node.js se ne može instalirati!"
    exit 1
fi

echo "✅ Node.js instaliran: $(node --version)"
echo "✅ NPM verzija: $(npm --version)"
echo "✅ Node.js putanja: $(which node)"

# Instaliraj nginx
amazon-linux-extras install nginx1 -y

# Kreiraj aplikacijski direktorij
mkdir -p /opt/webapp
cd /opt/webapp

# Kloniraj repozitorij
git clone https://github.com/hasicamina/projekat2-iso .

# Postavljanje backend-a
echo "🔧 Postavljam backend..."
cd /opt/webapp/backend

# Kreiraj .env fajl sa production vrijednostima
cat > .env << EOF
PORT=3000
NODE_ENV=production
DB_HOST=${db_host}
DB_PORT=5432
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
DATABASE_URL=postgresql://${db_username}:${db_password}@${db_host}:5432/${db_name}
EOF

# Instaliraj backend dependencies
npm install --production

# ISPRAVKA: Dinamički uzmi putanju Node.js-a za systemd servis
NODE_PATH=$(which node)
echo "🔧 Node.js putanja za systemd: $NODE_PATH"

# Kreiraj systemd servis sa ispravnom putanjom
cat > /etc/systemd/system/webapp-backend.service << EOF
[Unit]
Description=Web App Backend
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/webapp/backend
Environment=NODE_ENV=production
ExecStart=$NODE_PATH server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Postavljanje frontend-a
echo "🔧 Postavljam frontend..."
cd /opt/webapp

# Kopiraj frontend fajlove u nginx direktorij
cp -r frontend/* /usr/share/nginx/html/

# Ukloni default nginx konfiguraciju
rm -f /etc/nginx/conf.d/default.conf
rm -f /etc/nginx/nginx.conf

# Kreiraj novu nginx konfiguraciju
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;
        
        # Frontend static files
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        # Proxy API requests to backend
        location /api/ {
            proxy_pass http://127.0.0.1:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }
        
        # Health check endpoint za ALB
        location /health {
            access_log off;
            return 200 "Frontend healthy\n";
            add_header Content-Type text/plain;
        }
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            access_log off;
        }
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
    }
}
EOF

# Postavi vlasništvo fajlova
chown -R ec2-user:ec2-user /opt/webapp
chown -R nginx:nginx /usr/share/nginx/html

# ISPRAVKA: Dodaj dodatne provjere prije pokretanja servisa
echo "🔍 Provjeram backend setup..."
ls -la /opt/webapp/backend/server.js
ls -la /opt/webapp/backend/package.json
ls -la /opt/webapp/backend/.env

# Testiranje Node.js aplikacije prije systemd servisa
echo "🧪 Testiram Node.js aplikaciju direktno..."
cd /opt/webapp/backend
timeout 10s su - ec2-user -c "cd /opt/webapp/backend && node server.js" &
sleep 5
kill $! 2>/dev/null || true

# Pokreni i omogući servise
systemctl daemon-reload
systemctl enable webapp-backend
systemctl start webapp-backend

systemctl enable nginx
systemctl start nginx

# Sačekaj da se servisi pokrenu
echo "⏳ Čekam da se servisi pokrenu..."
sleep 30

# Provjeri status servisa
echo "📊 Status servisa:"
systemctl status webapp-backend --no-pager -l
systemctl status nginx --no-pager -l

# ISPRAVKA: Dodaj više debug informacija
echo "🔍 Debug informacije:"
echo "Node.js verzija: $(node --version)"
echo "NPM verzija: $(npm --version)"
echo "Node.js putanja: $(which node)"
echo "Backend PID: $(pgrep -f 'node server.js' || echo 'Nije pokrenut')"
echo "Nginx PID: $(pgrep nginx || echo 'Nije pokrenut')"

# Provjeri portove
echo "📡 Port status:"
netstat -tlnp | grep ':3000\|:80' || echo "Portovi nisu aktivni"

# Test health endpoints sa više pokušaja
echo "🧪 Testiram health endpoints..."
for i in {1..5}; do
    echo "Pokušaj $i/5:"
    curl -f -m 5 http://localhost:3000/api/health && echo "✅ Backend API health OK" || echo "❌ Backend API health failed"
    curl -f -m 5 http://localhost/health && echo "✅ Frontend health OK" || echo "❌ Frontend health failed"
    sleep 10
done

# Logovi za praćenje
echo "📋 Važni logovi:"
echo "Backend logs: journalctl -u webapp-backend -f"
echo "Nginx logs: tail -f /var/log/nginx/error.log"
echo "User data log: tail -f /var/log/user-data.log"

# ISPRAVKA: Dodatni error handling
if ! systemctl is-active --quiet webapp-backend; then
    echo "❌ Backend servis nije aktivan, provjeri logove:"
    journalctl -u webapp-backend --no-pager -l
fi

if ! systemctl is-active --quiet nginx; then
    echo "❌ Nginx servis nije aktivan, provjeri logove:"
    journalctl -u nginx --no-pager -l
fi

echo "✅ Provisioning završen!"