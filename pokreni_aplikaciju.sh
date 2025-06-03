#!/bin/bash

echo "🚀 Pokretanje web aplikacije..."
echo "==============================="

# Provjera da li je Docker pokrenut
if ! docker info &> /dev/null; then
    echo "❌ Docker nije pokrenut. Pokreni Docker prije nastavka."
    exit 1
fi

# Provjera da li postoji mreža
if ! docker network ls | grep -q app-network; then
    echo "❌ Docker mreža 'app-network' ne postoji. Pokreni ./setup.sh prvo."
    exit 1
fi

# Provjera da li postoje Docker slike
if ! docker images | grep -q webapp-backend; then
    echo "❌ webapp-backend slika ne postoji. Pokreni ./setup.sh prvo."
    exit 1
fi

if ! docker images | grep -q webapp-frontend; then
    echo "❌ webapp-frontend slika ne postoji. Pokreni ./setup.sh prvo."
    exit 1
fi

echo "▶️  Pokrećem sve komponente..."

echo "🗄️  Pokrećem PostgreSQL..."
docker run -d \
    --name webapp_postgres \
    --network app-network \
    -e POSTGRES_DB=webapp_db \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres123 \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    -v postgres_data:/var/lib/postgresql/data \
    -v "$(pwd)/init.sql:/docker-entrypoint-initdb.d/init.sql" \
    -p 54321:5432 \
    --restart unless-stopped \
    postgres:15-alpine

echo "🔴 Pokrećem Redis..."
docker run -d \
    --name webapp_redis \
    --network app-network \
    -v redis_data:/data \
    -p 6379:6379 \
    --restart unless-stopped \
    redis:7-alpine redis-server --appendonly yes

echo "⏳ Čekam da se baza pokrene..."
for i in {1..30}; do
    if docker exec webapp_postgres pg_isready -U postgres -d webapp_db &> /dev/null; then
        echo "✅ Baza je spremna!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Baza se nije pokrenula na vrijeme."
        docker logs webapp_postgres
        exit 1
    fi
    echo "   Pokušaj $i/30..."
    sleep 2
done

echo "⚙️  Pokrećem backend..."
docker run -d \
    --name webapp_backend \
    --network app-network \
    -e NODE_ENV=production \
    -e PORT=3000 \
    -e DB_HOST=webapp_postgres \
    -e DB_PORT=5432 \
    -e DB_NAME=webapp_db \
    -e DB_USER=postgres \
    -e DB_PASSWORD=postgres123 \
    -p 3000:3000 \
    --restart unless-stopped \
    webapp-backend

echo "⏳ Čekam da backend odgovori..."
for i in {1..20}; do
    if curl -f http://localhost:3000/health &> /dev/null; then
        echo "✅ Backend je spreman!"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "❌ Backend nije dostupan!"
        docker logs webapp_backend
        exit 1
    fi
    echo "   Pokušaj $i/20..."
    sleep 3
done

echo "🌐 Pokrećem frontend..."
docker run -d \
    --name webapp_frontend \
    --network app-network \
    -p 80:80 \
    --restart unless-stopped \
    webapp-frontend

echo "⏳ Čekam da frontend odgovori..."
for i in {1..15}; do
    if curl -f http://localhost/ &> /dev/null; then
        echo "✅ Frontend je dostupan!"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "❌ Frontend nije dostupan!"
        docker logs webapp_frontend
        exit 1
    fi
    echo "   Pokušaj $i/15..."
    sleep 3
done

echo "🧠 Pokrećem pgAdmin..."
docker run -d \
    --name webapp_pgadmin \
    --network app-network \
    -e PGADMIN_DEFAULT_EMAIL=admin@webapp.com \
    -e PGADMIN_DEFAULT_PASSWORD=admin123 \
    -e PGADMIN_LISTEN_PORT=80 \
    -v pgadmin_data:/var/lib/pgadmin \
    -p 8080:80 \
    --restart unless-stopped \
    dpage/pgadmin4:latest

echo ""
echo "🎉 Aplikacija je uspješno pokrenuta!"
echo "======================================="
echo "🌐 Frontend:  http://localhost"
echo "🔧 Backend:   http://localhost:3000"
echo "📊 Health:    http://localhost:3000/health"
echo "📋 Tasks API: http://localhost:3000/tasks"
echo "🗄️  pgAdmin:   http://localhost:8080"
echo "   └─ Email: admin@webapp.com"
echo "   └─ Pass:  admin123"
echo ""
echo "💡 Korisni savjeti:"
echo "   - Zaustavi sve: ./stop.sh"
echo "   - Logovi: docker logs <ime_kontejnera>"
echo "   - Status: docker ps"
