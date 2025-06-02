#!/bin/bash
set -e

echo "Setting up Task Manager Application..."

echo "Creating Docker network..."
docker network create task-app-network || echo "Network already exists"

# Build frontend image
echo "Building frontend Docker image..."
cd frontend
docker build -t task-app-frontend .
cd ..

# Build backend image
echo "Building backend Docker image..."
cd backend
docker build -t task-app-backend .
cd ..

echo "Pulling PostgreSQL image..."
docker pull postgres:latest

echo "Setup complete! Run start.sh to start the application."
