#!/bin/bash

# Start live-server for frontend with hot reload enabled
echo "Starting frontend development server with hot reload..."

# Pokrećemo live-server na portu 8080 (ili bilo koji drugi port po želji)
npx live-server --port=8080 --no-browser --watch=./

echo "Frontend development server started at http://localhost:8080"
