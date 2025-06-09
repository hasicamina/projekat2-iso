#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
echo "🔧 Pokrećem provisioning..."

# Ažuriraj sistem i instaliraj potrebne pakete
yum update -y
yum install -y git curl

# Instaliraj Node.js 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Instaliraj nginx
amazon-linux-extras install nginx1 -y

# Kreiraj aplikacijski direktorij
mkdir -p /opt/webapp
cd /opt/webapp

# Kloniraj repozitorij
git clone ${git_repo_url} .

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

# Kreiraj systemd servis za backend
cat > /etc/systemd/system/webapp-backend.service << EOF
[Unit]
Description=Web App Backend
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/webapp/backend
Environment=NODE_ENV=production
ExecStart=/usr/bin/node server.js
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
        
        # Proxy API requests to backend (fallback)
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

# Test health endpoints
echo "🧪 Testiram health endpoints..."
sleep 60  # Duži timeout za pokretanje
curl -f http://localhost:3000/api/health && echo "✅ Backend API health OK" || echo "❌ Backend API health failed"
curl -f http://localhost:3000/health && echo "✅ Backend root health OK" || echo "❌ Backend root health failed"
curl -f http://localhost/health && echo "✅ Frontend health OK" || echo "❌ Frontend health failed"

# Detaljnije testiranje
echo "🔍 Backend response test:"
curl -v http://localhost:3000/api/health
# Provjeri port binding
echo "📡 Port status:"
netstat -tlnp | grep ':3000\|:80'

echo "✅ Provisioning završen!"

# Dodatne informacije za debugging
echo "🔍 Debug informacije:"
echo "Node.js verzija: $(node --version)"
echo "NPM verzija: $(npm --version)"
echo "Backend PID: $(pgrep -f 'node server.js')"
echo "Nginx PID: $(pgrep nginx)"

# Logovi za praćenje
echo "📋 Važni logovi:"
echo "Backend logs: journalctl -u webapp-backend -f"
echo "Nginx logs: tail -f /var/log/nginx/error.log"
echo "User data log: tail -f /var/log/user-data.log"