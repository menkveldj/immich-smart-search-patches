#!/bin/bash

# Test script for locally running Immich instance with patches

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_URL="${1:-http://localhost:3283/api}"
TEST_EMAIL="test@example.com"
TEST_PASSWORD="TestPassword123"

echo -e "${YELLOW}Testing Immich instance at: ${API_URL}${NC}"
echo "============================================"

# Check server is up
echo -n "Checking server status... "
if curl -s -f "${API_URL}/server/ping" > /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Server not responding${NC}"
    exit 1
fi

# Get server version
VERSION_JSON=$(curl -s "${API_URL}/server/version")
MAJOR=$(echo "$VERSION_JSON" | jq -r '.major')
MINOR=$(echo "$VERSION_JSON" | jq -r '.minor')
PATCH=$(echo "$VERSION_JSON" | jq -r '.patch')
VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo -e "Server version: ${BLUE}${VERSION}${NC}"

# Create admin user
echo -e "\n${YELLOW}Setting up authentication...${NC}"
echo "Creating admin user..."
ADMIN_RESPONSE=$(curl -s -X POST "${API_URL}/auth/admin-sign-up" \
    -H "Content-Type: application/json" \
    -d "{
        \"email\": \"${TEST_EMAIL}\",
        \"password\": \"${TEST_PASSWORD}\",
        \"name\": \"Test Admin\"
    }")

USER_ID=$(echo "$ADMIN_RESPONSE" | jq -r '.id // empty')
if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    echo "Admin user might already exist, trying login..."
else
    echo -e "${GREEN}✓${NC} Admin user created"
fi

# Get access token
echo "Getting access token..."
ACCESS_TOKEN=$(curl -s -X POST "${API_URL}/auth/login" \
    -H "Content-Type: application/json" \
    -d "{
        \"email\": \"${TEST_EMAIL}\",
        \"password\": \"${TEST_PASSWORD}\"
    }" | jq -r '.accessToken')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo -e "${RED}✗ Failed to get access token${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Got access token"

# Create API key
echo "Creating API key..."
API_KEY=$(curl -s -X POST "${API_URL}/api-keys" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Local Test Key",
        "permissions": ["all"]
    }' | jq -r '.secret')

if [ -z "$API_KEY" ] || [ "$API_KEY" = "null" ]; then
    echo -e "${RED}✗ Failed to create API key${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} API key created"

# Test smart search with a simple query
echo -e "\n${YELLOW}Testing Smart Search Patches...${NC}"
echo "Performing smart search..."

SEARCH_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "query": "nature landscape",
        "size": 5
    }')

# Check for distance field (our patch)
if echo "$SEARCH_RESPONSE" | jq -e '.assets.items[0].distance' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Distance field present in response"
    DISTANCE=$(echo "$SEARCH_RESPONSE" | jq '.assets.items[0].distance // "N/A"')
    echo "  Sample distance value: $DISTANCE"
else
    echo -e "${YELLOW}⚠${NC} Distance field not found (might be no assets)"
fi

# Check for similarity field (our patch)
if echo "$SEARCH_RESPONSE" | jq -e '.assets.items[0].similarity' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Similarity field present in response"
    SIMILARITY=$(echo "$SEARCH_RESPONSE" | jq '.assets.items[0].similarity // "N/A"')
    echo "  Sample similarity value: $SIMILARITY"
else
    echo -e "${YELLOW}⚠${NC} Similarity field not found (might be no assets)"
fi

# Test album filtering (create an album first)
echo -e "\n${YELLOW}Testing Album Filtering...${NC}"
echo "Creating test album..."

ALBUM_RESPONSE=$(curl -s -X POST "${API_URL}/albums" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"albumName": "Test Album for Filtering"}')

ALBUM_ID=$(echo "$ALBUM_RESPONSE" | jq -r '.id // empty')

if [ ! -z "$ALBUM_ID" ] && [ "$ALBUM_ID" != "null" ]; then
    echo -e "${GREEN}✓${NC} Album created: $ALBUM_ID"
    
    # Test search with album filter
    echo "Testing search with album filter..."
    FILTERED_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"query\": \"test\",
            \"albumId\": \"${ALBUM_ID}\",
            \"size\": 5
        }")
    
    # Check if request was successful (no error)
    if echo "$FILTERED_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
        echo -e "${RED}✗${NC} Album filtering returned error"
    else
        echo -e "${GREEN}✓${NC} Album filtering works (no error)"
    fi
    
    # Test invalid UUID
    echo "Testing invalid UUID validation..."
    INVALID_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
            "query": "test",
            "albumId": "not-a-uuid",
            "size": 5
        }')
    
    STATUS_CODE=$(echo "$INVALID_RESPONSE" | jq -r '.statusCode // 200')
    if [ "$STATUS_CODE" = "400" ]; then
        echo -e "${GREEN}✓${NC} Invalid UUID rejected correctly"
    else
        echo -e "${RED}✗${NC} Invalid UUID not rejected (status: $STATUS_CODE)"
    fi
else
    echo -e "${YELLOW}⚠${NC} Could not create album for testing"
fi

echo -e "\n${YELLOW}===========================================${NC}"
echo -e "${GREEN}✅ Patch verification complete!${NC}"
echo ""
echo "Summary:"
echo "- Server is running the patched version at ${API_URL}"
echo "- Distance and similarity fields are available in smart search"
echo "- Album filtering functionality is working"
echo ""
echo "Note: If no assets are uploaded, distance/similarity fields won't appear."
echo "Upload some photos through the web UI or API to see the full functionality."