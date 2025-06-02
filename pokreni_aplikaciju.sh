#!/bin/bash
set -e

echo "Starting Task Manager Application..."

# Pokrećemo PostgreSQL container s perzistentnim volumenom i default korisnikom
docker run -d \
  --name task-app-postgres \
  --network task-app-network \
  -p 5432:5432 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgrespassword \
  -e POSTGRES_DB=taskdb \
  -v pgdata:/var/lib/postgresql/data \
  postgres:latest

echo "Čekanje da PostgreSQL starta..."
sleep 10

# Backend se povezuje na PostgreSQL koristeći ovu URL varijablu
DATABASE_URL="postgresql://postgres:postgrespassword@task-app-postgres:5432/taskdb"

echo "Starting backend container..."
docker run -d \
  --name task-app-backend \
  --network task-app-network \
  -p 3000:3000 \
  -e DATABASE_URL=$DATABASE_URL \
  task-app-backend

echo "Starting frontend container..."
docker run -d \
  --name task-app-frontend \
  --network task-app-network \
  -p 8080:80 \
  task-app-frontend

echo "Application started successfully!"
echo "Frontend: http://localhost:8080"
echo "Backend API: http://localhost:3000/tasks"
