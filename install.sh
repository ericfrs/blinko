#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

NEXTAUTH_SECRET=$(openssl rand -base64 32)
DB_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/' | head -c 32)

echo -e "${CYAN}🔐 Generated secure secrets for this installation.${NC}"

if [ "$(docker ps -aq -f name=blinko-website)" ]; then
    echo -e "${RED}Container 'blinko-website' already exists. Remove it first with:${NC}"
    echo -e "  docker stop blinko-website && docker rm blinko-website"
    exit 1
fi

if ss -tlnp | grep -q ':1111 '; then
    echo -e "${RED}Port 1111 is already in use. Free it before running this script.${NC}"
    exit 1
fi

if [ ! "$(docker network ls -q -f name=blinko-network)" ]; then
    echo -e "${YELLOW}Network 'blinko-network' does not exist. Creating network...${NC}"
    docker network create blinko-network

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create Docker network. Please check your Docker setup.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Successfully created Docker network: blinko-network${NC}"
else
    echo -e "${YELLOW}Network 'blinko-network' already exists. Skipping network creation.${NC}"
fi

if [ "$(docker ps -aq -f name=blinko-postgres)" ]; then
    echo -e "${YELLOW}Container 'blinko-postgres' already exists. Skipping container creation.${NC}"
    echo -e "${YELLOW}⚠️  Extracting existing DB_PASSWORD from postgres container...${NC}"
    EXISTING_DB_PASSWORD=$(docker inspect blinko-postgres | grep -oP '(?<="POSTGRES_PASSWORD=)[^"]*' || docker inspect blinko-postgres | grep "POSTGRES_PASSWORD=" | head -n 1 | cut -d '"' -f 2 | cut -d '=' -f 2-)
    
    if [ -n "$EXISTING_DB_PASSWORD" ]; then
        DB_PASSWORD="$EXISTING_DB_PASSWORD"
        echo -e "${GREEN}✅ Successfully extracted existing DB_PASSWORD.${NC}"
    else
        echo -e "${RED}Failed to extract existing POSTGRES_PASSWORD from blinko-postgres. Please check the container manually.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}2. 🐳 Starting PostgreSQL container...${NC}"
    docker run -d \
      --name blinko-postgres \
      --network blinko-network \
      -e POSTGRES_DB=postgres \
      -e POSTGRES_USER=postgres \
      -e POSTGRES_PASSWORD="$DB_PASSWORD" \
      -e TZ=America/Buenos_Aires \
      --restart always \
      postgres:14

    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to start PostgreSQL container.${NC}"
      exit 1
    fi
    echo -e "${GREEN}✅ PostgreSQL container is running.${NC}"
fi

echo -e "${YELLOW}Do you want to mount a local '.blinko' directory to '/app/.blinko' in the container? (y/n)${NC}"
read -p "Enter your choice: " mount_choice

if [[ "$mount_choice" == "y" || "$mount_choice" == "Y" ]]; then
    read -p "Please provide the path to your '.blinko' folder: " blnko_folder

    if [ ! -d "$blnko_folder" ]; then
        echo -e "${YELLOW}Directory does not exist. Creating directory...${NC}"
        mkdir -p "$blnko_folder"

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to create the directory. Please check permissions.${NC}"
            exit 1
        fi
    fi

    if [ ! -w "$blnko_folder" ]; then
        echo -e "${RED}The directory '$blnko_folder' does not have write permissions.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Directory is ready for mounting: $blnko_folder${NC}"
    volume_mount="-v $blnko_folder:/app/.blinko"
else
    volume_mount=""
    echo -e "${YELLOW}Skipping mounting of .blinko directory.${NC}"
fi

echo -e "${YELLOW}3. 🖥️ Starting BlinkOS container...${NC}"
docker run -d \
  --name blinko-website \
  --network blinko-network \
  -p 1111:1111 \
  -e NODE_ENV=production \
  -e NEXTAUTH_SECRET="$NEXTAUTH_SECRET" \
  -e DATABASE_URL="postgresql://postgres:${DB_PASSWORD}@blinko-postgres:5432/postgres" \
  $volume_mount \
  --restart always \
  ghcr.io/ericfrs/blinko:latest

if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to start BlinkOS container.${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✅ All containers are up and running.${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  ⚠️  SAVE THESE CREDENTIALS — they won't be shown again:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  NEXTAUTH_SECRET : ${YELLOW}${NEXTAUTH_SECRET}${NC}"
echo -e "  DB_PASSWORD     : ${YELLOW}${DB_PASSWORD}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
