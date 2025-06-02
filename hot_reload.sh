#!/bin/bash

echo "Starting frontend development server with hot reload..."

if ! command -v npx &> /dev/null; then
    echo "npx command not found. Installing npm..."
    apt-get update && apt-get install -y npm || sudo apt-get update && sudo apt-get install -y npm
fi

cat > .live-server.json << EOL
{
  "port": 8080,
  "host": "0.0.0.0",
  "root": "./",
  "open": false,
  "file": "index.html",
  "wait": 1000,
  "logLevel": 2,
  "watch": ["*.html", "*.css", "*.js"],
  "mount": []
}
EOL

echo "Created hot reload configuration file"

npx live-server --no-browser

echo "Frontend development server started at http://localhost:8080