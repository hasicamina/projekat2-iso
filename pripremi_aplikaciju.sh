#!/bin/bash

echo "🔧 Priprema Docker okruženja za web aplikaciju..."
echo "==============================================="

# Provjera da li je Docker pokrenut
if ! docker info &> /dev/null; then
    echo "❌ Docker nije pokrenut. Pokreni Docker prije nastavka."
    exit 1
fi

# Provjera da li je Docker Compose dostupan
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose nije instaliran ili dostupan."
    exit 1
fi

echo "✅ Docker je spreman!"

# Kreiranje mreže ako ne postoji
if ! docker network ls | grep -q app-network; then
    echo "🌐 Kreiram Docker mrežu..."
    docker network create --driver bridge --subnet=172.20.0.0/16 app-network
    echo "✅ Mreža 'app-network' kreirana!"
else
    echo "✅ Mreža 'app-network' već postoji!"
fi

# Kreiranje volumena
echo "💾 Kreiram Docker volumene..."
docker volume create postgres_data 2>/dev/null || true
docker volume create redis_data 2>/dev/null || true
docker volume create pgadmin_data 2>/dev/null || true
echo "✅ Volumeni kreirani!"

# Kreiranje direktorija ako ne postoje
echo "📁 Kreiram potrebne direktorije..."
mkdir -p frontend backend logs
echo "✅ Direktoriji kreirani!"

# Postavljanje dozvola za skripte
echo "🔐 Postavljam dozvole za skripte..."
chmod +x *.sh
echo "✅ Dozvole postavljene!"

# Build Docker slika
echo "🏗️  Kreiram Docker slike..."

# Backend slika
echo "⚙️  Kreiranje backend slike..."
if docker build -f Dockerfile.backend -t webapp-backend . --no-cache; then
    echo "✅ Backend slika kreirana!"
else
    echo "❌ Greška pri kreiranju backend slike!"
    exit 1
fi

# Frontend slika
echo "🌐 Kreiranje frontend slike..."
if docker build -f Dockerfile.frontend -t webapp-frontend . --no-cache; then
    echo "✅ Frontend slika kreirana!"
else
    echo "❌ Greška pri kreiranju frontend slike!"
    exit 1
fi

echo ""
echo "🎉 Setup završen uspješno!"
echo "========================="
echo "💡 Sljedeći koraci:"
echo "   1. Pokreni aplikaciju: ./start.sh"
echo "   2. Zaustavi aplikaciju: ./stop.sh"
echo "   3. Restartuj aplikaciju: ./restart.sh"
echo "   4. Očisti sve: ./cleanup.sh"
echo ""
echo "📊 Kreirane slike:"
docker images | grep webapp-
echo ""