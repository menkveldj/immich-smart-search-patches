#!/bin/bash

# Script to validate patches against a specific Immich version

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default version
IMMICH_VERSION="${1:-v1.122.3}"
PATCH_FILE="${2:-patches/add-smartsearch-score-and-album.diff}"

echo -e "${YELLOW}Validating patch against Immich ${IMMICH_VERSION}${NC}"
echo "==========================================="

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Clone Immich
echo -e "\n${YELLOW}Cloning Immich ${IMMICH_VERSION}...${NC}"
git clone --depth 1 --branch "$IMMICH_VERSION" \
  https://github.com/immich-app/immich.git immich-source 2>/dev/null || {
    echo -e "${RED}Failed to clone Immich ${IMMICH_VERSION}${NC}"
    exit 1
  }

cd immich-source

# Try to apply patch
echo -e "\n${YELLOW}Testing patch application...${NC}"
if git apply --check "$OLDPWD/$PATCH_FILE" 2>/dev/null; then
    echo -e "${GREEN}✅ Patch can be applied cleanly!${NC}"
    
    # Actually apply it
    git apply "$OLDPWD/$PATCH_FILE"
    
    # Verify key changes
    echo -e "\n${YELLOW}Verifying patch contents...${NC}"
    
    # Check for distance/similarity in DTOs
    if grep -q "distance?: number" server/src/dtos/asset-response.dto.ts; then
        echo -e "${GREEN}✅ Distance field found in AssetResponseDto${NC}"
    else
        echo -e "${RED}✗ Distance field not found${NC}"
    fi
    
    if grep -q "similarity?: number" server/src/dtos/asset-response.dto.ts; then
        echo -e "${GREEN}✅ Similarity field found in AssetResponseDto${NC}"
    else
        echo -e "${RED}✗ Similarity field not found${NC}"
    fi
    
    # Check for albumId in search DTO
    if grep -q "albumId?: string" server/src/dtos/search.dto.ts; then
        echo -e "${GREEN}✅ AlbumId field found in SearchDto${NC}"
    else
        echo -e "${RED}✗ AlbumId field not found${NC}"
    fi
    
    # Check for getRawAndEntities in search repository
    if grep -q "getRawAndEntities" server/src/repositories/search.repository.ts; then
        echo -e "${GREEN}✅ getRawAndEntities found in search repository${NC}"
    else
        echo -e "${RED}✗ getRawAndEntities not found${NC}"
    fi
    
    # Check for album filtering in database utils
    if grep -q "albumId" server/src/utils/database.ts; then
        echo -e "${GREEN}✅ Album filtering found in database utils${NC}"
    else
        echo -e "${RED}✗ Album filtering not found${NC}"
    fi
    
    echo -e "\n${GREEN}✅ Patch validation successful!${NC}"
    RESULT=0
else
    echo -e "${RED}✗ Patch cannot be applied cleanly${NC}"
    echo -e "\n${YELLOW}Attempting 3-way merge to identify conflicts...${NC}"
    
    git apply --3way "$OLDPWD/$PATCH_FILE" 2>&1 || true
    
    echo -e "\n${YELLOW}Conflicts found in:${NC}"
    git diff --name-only --diff-filter=U
    
    echo -e "\n${RED}Patch needs to be updated for Immich ${IMMICH_VERSION}${NC}"
    RESULT=1
fi

# Cleanup
cd "$OLDPWD"
rm -rf "$TEMP_DIR"

exit $RESULT