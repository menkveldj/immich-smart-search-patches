#!/bin/bash

# Verify that patches are correctly applied to the built Docker image

echo "========================================="
echo "Patch Verification"
echo "========================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PATCHES_VERIFIED=0
PATCHES_FAILED=0

echo -e "\n1. Checking Distance/Similarity Patch"
echo "======================================"

# Check if distance field is added to AssetResponseDto
echo -n "Checking AssetResponseDto for distance field... "
if docker run --rm --entrypoint grep immich-server:latest-with-patches -r "distance?: number" /usr/src/app/dist/dtos/ 2>/dev/null | grep -q "distance"; then
    echo -e "${GREEN}✓${NC}"
    ((PATCHES_VERIFIED++))
else
    echo -e "${RED}✗${NC}"
    ((PATCHES_FAILED++))
fi

# Check if similarity field is added
echo -n "Checking AssetResponseDto for similarity field... "
if docker run --rm --entrypoint grep immich-server:latest-with-patches -r "similarity?: number" /usr/src/app/dist/dtos/ 2>/dev/null | grep -q "similarity"; then
    echo -e "${GREEN}✓${NC}"
    ((PATCHES_VERIFIED++))
else
    echo -e "${RED}✗${NC}"
    ((PATCHES_FAILED++))
fi

# Check if distance calculation is in search repository
echo -n "Checking search repository for distance calculation... "
if docker run --rm --entrypoint cat immich-server:latest-with-patches /usr/src/app/dist/repositories/search.repository.js 2>/dev/null | grep -q "addSelect.*distance"; then
    echo -e "${GREEN}✓${NC}"
    ((PATCHES_VERIFIED++))
else
    echo -e "${RED}✗${NC}"
    ((PATCHES_FAILED++))
fi

# Check if getRawAndEntities is used
echo -n "Checking for getRawAndEntities usage... "
if docker run --rm --entrypoint cat immich-server:latest-with-patches /usr/src/app/dist/repositories/search.repository.js 2>/dev/null | grep -q "getRawAndEntities"; then
    echo -e "${GREEN}✓${NC}"
    ((PATCHES_VERIFIED++))
else
    echo -e "${RED}✗${NC}"
    ((PATCHES_FAILED++))
fi

echo -e "\n2. Checking Album Filtering Patch"
echo "=================================="

# Check if albumId is in SmartSearchDto
echo -n "Checking SmartSearchDto for albumId field... "
if docker run --rm --entrypoint grep immich-server:latest-with-patches -r "albumId" /usr/src/app/dist/dtos/search.dto.js 2>/dev/null | grep -q "albumId"; then
    echo -e "${GREEN}✓${NC}"
    ((PATCHES_VERIFIED++))
else
    echo -e "${RED}✗${NC}"
    ((PATCHES_FAILED++))
fi

# Check if album filtering is in database utils
echo -n "Checking database.js for album filtering logic... "
if docker run --rm --entrypoint cat immich-server:latest-with-patches /usr/src/app/dist/utils/database.js 2>/dev/null | grep -q "albums_assets_assets"; then
    echo -e "${GREEN}✓${NC}"
    ((PATCHES_VERIFIED++))
else
    echo -e "${RED}✗${NC}"
    ((PATCHES_FAILED++))
fi

# Check if SearchAlbumOptions interface exists
echo -n "Checking for SearchAlbumOptions in interfaces... "
if docker run --rm --entrypoint grep immich-server:latest-with-patches -r "SearchAlbumOptions" /usr/src/app/dist/interfaces/ 2>/dev/null | grep -q "albumId"; then
    echo -e "${GREEN}✓${NC}"
    ((PATCHES_VERIFIED++))
else
    echo -e "${RED}✗${NC}"
    ((PATCHES_FAILED++))
fi

echo -e "\n3. Detailed Code Verification"
echo "=============================="

echo -e "\nDistance calculation in search.repository.js:"
docker run --rm --entrypoint cat immich-server:latest-with-patches /usr/src/app/dist/repositories/search.repository.js 2>/dev/null | grep -A2 -B2 "addSelect.*distance" | head -10

echo -e "\nAlbum filtering in database.js:"
docker run --rm --entrypoint cat immich-server:latest-with-patches /usr/src/app/dist/utils/database.js 2>/dev/null | grep -A5 "albumId" | head -10

echo -e "\n========================================="
echo "Verification Summary"
echo "========================================="
echo -e "${GREEN}Verified:${NC} $PATCHES_VERIFIED"
echo -e "${RED}Failed:${NC} $PATCHES_FAILED"

if [ $PATCHES_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All patches are correctly applied to the Docker image!${NC}"
    echo -e "\nThe following features are available:"
    echo "  • Distance and similarity scoring in smart search results"
    echo "  • Album filtering via albumId parameter"
    echo "  • Proper handling of custom fields through getRawAndEntities"
    exit 0
else
    echo -e "\n${RED}✗ Some patches are missing or incorrectly applied.${NC}"
    exit 1
fi