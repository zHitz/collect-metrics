#!/bin/bash

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Load environment variables
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${YELLOW}.env file not found. Copying from .env.example...${NC}"
    if [ -f "$PROJECT_ROOT/.env.example" ]; then
        cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
        echo -e "${GREEN}Copied .env.example to .env. Please review and update your configuration if needed.${NC}"
    else
        echo -e "${RED}Error: .env.example file not found!${NC}"
        exit 1
    fi
fi

set -a
source "$PROJECT_ROOT/.env"
set +a

if [ "${ENABLE_PORTAINER:-false}" = "true" ]; then
    # Portainer directory
    echo "Deploying Portainer as separate stack..."
    mkdir -p "$PROJECT_ROOT/portainer/data"

    # Use separate project name for Portainer to avoid orphan containers warning
    cd "$PROJECT_ROOT/portainer"
    COMPOSE_PROJECT_NAME="management" docker compose -f portainer-compose.yml up -d

    echo "Portainer deployed successfully as separate stack!"
else
    echo -e "${YELLOW}DEPLOY_PORTAINER is not set to true. Skipping Portainer deployment.${NC}"
fi
