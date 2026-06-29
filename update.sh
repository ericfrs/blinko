#!/bin/bash

# Colors for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

container_name="blinko-website"
image_name="ghcr.io/ericfrs/blinko:latest"
backup_dir="blinko-backup-$(date +"%Y%m%d_%H%M%S")"
docker_volume=""

# Step 0: Ensure container exists and extract secrets
if [ ! "$(docker ps -aq -f name=$container_name)" ]; then
  echo -e "${RED}Container $container_name does not exist. Please run install.sh instead of update.sh.${NC}"
  exit 1
fi

echo -e "${YELLOW}Extracting existing environment variables...${NC}"
EXISTING_NEXTAUTH_SECRET=$(docker inspect $container_name | grep -oP '(?<="NEXTAUTH_SECRET=)[^"]*' || docker inspect $container_name | grep "NEXTAUTH_SECRET=" | head -n 1 | cut -d '"' -f 2 | cut -d '=' -f 2-)
EXISTING_DATABASE_URL=$(docker inspect $container_name | grep -oP '(?<="DATABASE_URL=)[^"]*' || docker inspect $container_name | grep "DATABASE_URL=" | head -n 1 | cut -d '"' -f 2 | cut -d '=' -f 2-)

if [ -z "$EXISTING_NEXTAUTH_SECRET" ] || [ -z "$EXISTING_DATABASE_URL" ]; then
    echo -e "${RED}Could not extract NEXTAUTH_SECRET or DATABASE_URL from existing container.${NC}"
    echo -e "${YELLOW}Are you sure this container was started correctly?${NC}"
    exit 1
fi

# Step 1: Backup data from the container
echo -e "${YELLOW}🔄 Backing up data from the container...${NC}"

# Create backup directory
mkdir -p "$backup_dir"

# Copy data from the container
if [ "$(docker ps -q -f name=$container_name)" ]; then
  docker cp "${container_name}:/app/.blinko" "$backup_dir"

  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to backup data from the container. Please check the container name and your Docker setup.${NC}"
    exit 1
  fi

  echo -e "${GREEN}✅ Data backed up to: $backup_dir${NC}"
else
  echo -e "${YELLOW}Container $container_name is not running. Backup might be incomplete.${NC}"
fi

# Check if the container has a volume mounted before removing it
volume_path=$(docker inspect -f '{{ range .Mounts }}{{ if eq .Destination "/app/.blinko" }}{{ .Source }}{{ end }}{{ end }}' "$container_name")
if [ -z "$volume_path" ]; then
  echo -e "${YELLOW}No existing volume found for container $container_name.${NC}"
else
  echo -e "${YELLOW}Using existing volume: $volume_path${NC}"
  docker_volume="-v $volume_path:/app/.blinko"
fi

# Step 2: Stop and remove existing container
echo -e "${YELLOW}1. 🗑 Stopping and removing existing container...${NC}"
if [ "$(docker ps -aq -f name=$container_name)" ]; then
  docker stop "$container_name"
  docker rm "$container_name"
fi

# Step 3: Remove old image and pull the new one
echo -e "${YELLOW}2. 🔄 Updating Docker image...${NC}"
docker pull "$image_name"

# Step 4: Run the blinko-website container
echo -e "${YELLOW}3. ⏳ Starting the new blinko-website container...${NC}"

# Run the new container with the existing volume and secrets
docker run -d \
  --name $container_name \
  --network blinko-network \
  $docker_volume \
  -p 1111:1111 \
  -e NODE_ENV=production \
  -e NEXTAUTH_SECRET="$EXISTING_NEXTAUTH_SECRET" \
  -e DATABASE_URL="$EXISTING_DATABASE_URL" \
  --restart always \
  $image_name

if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to start Docker container. Please check your Docker setup.${NC}"
  exit 1
fi

echo -e "${GREEN}✅ $container_name has been successfully updated and is running.${NC}"
