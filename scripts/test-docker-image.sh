#!/bin/bash

# Test the published Docker image

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

IMAGE="${1:-ghcr.io/menkveldj/immich-server-patched:v1.122.3}"

echo -e "${YELLOW}Testing Docker image: ${IMAGE}${NC}"
echo "==========================================="

# Pull the image
echo -e "\n${YELLOW}Pulling image...${NC}"
docker pull "$IMAGE"

# Test 1: Check if patches are applied
echo -e "\n${YELLOW}Verifying patches in image...${NC}"

echo -n "Checking for distance field in search repository... "
if docker run --rm "$IMAGE" sh -c "cat /usr/src/app/dist/repositories/search.repository.js | grep -q 'addSelect.*distance'"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

echo -n "Checking for getRawAndEntities... "
if docker run --rm "$IMAGE" sh -c "cat /usr/src/app/dist/repositories/search.repository.js | grep -q 'getRawAndEntities'"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

echo -n "Checking for album filtering... "
if docker run --rm "$IMAGE" sh -c "cat /usr/src/app/dist/utils/database.js | grep -q 'albumId'"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Test 2: Check image metadata
echo -e "\n${YELLOW}Image information:${NC}"
docker inspect "$IMAGE" | jq -r '.[0].Config.Labels' | head -10

echo -e "\n${GREEN}✅ Image verification successful!${NC}"
echo ""
echo "You can now use this image in your docker-compose.yml:"
echo -e "${YELLOW}"
echo "services:"
echo "  immich-server:"
echo "    image: $IMAGE"
echo "    # ... rest of your configuration"
echo -e "${NC}"