#!/bin/bash

echo "Cleaning up Task Manager Application..."

./stop.sh

echo "Removing Docker images..."
docker rmi task-app-frontend task-app-backend 2>/dev/null || echo "Images already removed"

echo "Removing Docker network..."
docker network rm task-app-network 2>/dev/null || echo "Network already removed"

echo "Removing PostgreSQL data volume..."
docker volume rm pgdata 2>/dev/null || echo "Volume already removed"

echo "Cleanup complete! All application resources have been removed."
