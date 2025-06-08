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

# Funkcija za čekanje servisa
wait_for_service() {
    local service_name=$1
    local url=$2
    local max_attempts=$3
    local wait_time=${4:-3}
    
    echo "⏳ Čekam da $service_name odgovori..."
    for i in $(seq 1 $max_attempts); do
        if curl -f "$url" &> /dev/null; then
            echo "✅ $service_name je spreman!"
            return 0
        fi
        if [ $i -eq $max_attempts ]; then
            echo "❌ $service_name nije dostupan nakon $max_attempts pokušaja!"
            return 1
        fi
        echo "   Pokušaj $i/$max_attempts..."
        sleep $wait_time
    done
}

# Funkcija za čekanje PostgreSQL-a
wait_for_postgres() {
    echo "⏳ Čekam da se PostgreSQL pokrene..."
    for i in $(seq 1 30); do
        if docker exec webapp_postgres pg_isready -U postgres -d webapp_db &> /dev/null; then
            echo "✅ PostgreSQL je spreman!"
            return 0
        fi
        if [ $i -eq 30 ]; then
            echo "❌ PostgreSQL se nije pokrenuo na vrijeme."
            echo "📋 Logovi PostgreSQL-a:"
            docker logs webapp_postgres | tail -20
            return 1
        fi
        echo "   Pokušaj $i/30..."
        sleep 2
    done
}

# Pokretanje PostgreSQL
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
    --health-cmd="pg_isready -U postgres -d webapp_db" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=5 \
    postgres:15-alpine

if ! wait_for_postgres; then
    exit 1
fi

# Pokretanje Redis
echo "🔴 Pokrećem Redis..."
docker run -d \
    --name webapp_redis \
    --network app-network \
    -v redis_data:/data \
    -p 6379:6379 \
    --restart unless-stopped \
    --health-cmd="redis-cli ping" \
    --health-interval=10s \
    --health-timeout=3s \
    --health-retries=3 \
    redis:7-alpine redis-server --appendonly yes

# Pokretanje Backend
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
    -e CORS_ORIGIN=http://localhost \
    -p 3000:3000 \
    --restart unless-stopped \
    --health-cmd="curl -f http://localhost:3000/api/health || exit 1" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    webapp-backend

if ! wait_for_service "Backend" "http://localhost:3000/api/health" 20; then
    echo "📋 Logovi backend-a:"
    docker logs webapp_backend | tail -20
    exit 1
fi

# Pokretanje Frontend
echo "🌐 Pokrećem frontend..."
docker run -d \
    --name webapp_frontend \
    --network app-network \
    -p 80:80 \
    --restart unless-stopped \
    --health-cmd="curl -f http://localhost/ || exit 1" \
    --health-interval=30s \
    --health-timeout=3s \
    --health-retries=3 \
    webapp-frontend

if ! wait_for_service "Frontend" "http://localhost/" 15; then
    echo "📋 Logovi frontend-a:"
    docker logs webapp_frontend | tail -20
    exit 1
fi

# Pokretanje pgAdmin
echo "🧠 Pokrećem pgAdmin..."
docker run -d \
    --name webapp_pgadmin \
    --network app-network \
    -e PGADMIN_DEFAULT_EMAIL=admin@webapp.com \
    -e PGADMIN_DEFAULT_PASSWORD=admin123 \
    -e PGLADMIN_LISTEN_PORT=80 \
    -v pgadmin_data:/var/lib/pgladmin \
    -p 8080:80 \
    --restart unless-stopped \
    dpage/pgladmin4:latest

# Čekanje malo da se pgAdmin pokrene
sleep 5
if ! wait_for_service "pgAdmin" "http://localhost:8080" 10 5; then
    echo "⚠️  pgAdmin možda nije potpuno spreman, ali to nije kritično."
fi

echo ""
echo "🎉 Aplikacija je uspješno pokrenuta!"
echo "======================================="
echo "🌐 Frontend:  http://localhost"
echo "🔧 Backend:   http://localhost:3000"
echo "📊 Health:    http://localhost:3000/api/health"
echo "📋 Tasks API: http://localhost:3000/api/tasks"
echo "🗄️  pgAdmin:   http://localhost:8080"
echo "   └─ Email: admin@webapp.com"
echo "   └─ Pass:  admin123"
echo ""
echo "📊 Status kontejnera:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep webapp_

echo ""
echo "💡 Korisni savjeti:"
echo "   - Status:     docker ps"
echo "   - Logovi:     docker logs <container_name>"
echo "   - Zaustavi:   ./stop.sh"
echo "   - Restartuj:  ./restart.sh"
echo "   - Health:     docker ps --format 'table {{.Names}}\t{{.Status}}'"
echo ""

# Testiranje osnovnih funkcionalnosti
echo "🧪 Testiram osnovne funkcionalnosti..."
if curl -s http://localhost:3000/api/tasks > /dev/null; then
    echo "✅ API endpoints rade!"
else
    echo "⚠️  API možda nije potpuno spreman."
fi