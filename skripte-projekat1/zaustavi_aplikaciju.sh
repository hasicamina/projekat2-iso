#!/bin/bash

echo "Stopping Task Manager Application..."

# Stop and remove containers
echo "Stopping containers..."
docker stop task-app-frontend task-app-backend task-app-postgres 2>/dev/null || echo "Some containers were not running"

echo "Removing containers..."
docker rm task-app-frontend task-app-backend task-app-postgres 2>/dev/null || echo "Some containers were already removed"

echo "Application stopped successfully!"
