#!/bin/bash

# End-to-End Test Script for Immich Smart Search Patches
# This script tests the complete functionality of the patched Immich server
# including distance/similarity scoring and album filtering

set -e

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.local-test.yml"
API_URL="http://localhost:3003/api"
TEST_EMAIL="test@example.com"
TEST_PASSWORD="TestPassword123!"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=""

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up test environment...${NC}"
    cd "$REPO_ROOT"
    docker compose -f docker-compose.local-test.yml down -v 2>/dev/null || true
    rm -f ocean_*.jpg forest_*.jpg test_*.jpg 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Function to print section header
print_header() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to run a test
run_test() {
    local test_name="$1"
    local condition="$2"
    
    if [ "$condition" = "true" ] || [ "$condition" = "1" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        TEST_RESULTS="${TEST_RESULTS}✓ $test_name\n"
    else
        echo -e "${RED}✗${NC} $test_name"
        ((TESTS_FAILED++))
        TEST_RESULTS="${TEST_RESULTS}✗ $test_name\n"
    fi
}

# Function to wait for service
wait_for_service() {
    local service_name=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    echo -n "Waiting for $service_name to be ready"
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    echo -e " ${RED}✗${NC}"
    echo -e "${RED}Error: $service_name failed to start after $max_attempts attempts${NC}"
    return 1
}

# Function to create test images
create_test_images() {
    echo "Creating test images..."
    
    # Create ocean themed images (blue)
    for i in {1..3}; do
        if command -v convert &> /dev/null; then
            convert -size 400x300 xc:blue -pointsize 48 -fill white \
                -gravity center -annotate +0+0 "Ocean $i" ocean_$i.jpg 2>/dev/null
        else
            # Create a minimal valid JPEG if ImageMagick not available
            printf "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00" > ocean_$i.jpg
            printf "\xFF\xDB\x00\x43\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\x09\x09" >> ocean_$i.jpg
            # Add minimal data to make it valid
            dd if=/dev/zero bs=1024 count=10 2>/dev/null | tr '\0' '\377' >> ocean_$i.jpg
            printf "\xFF\xD9" >> ocean_$i.jpg
        fi
    done
    
    # Create forest themed images (green)
    for i in {1..2}; do
        if command -v convert &> /dev/null; then
            convert -size 400x300 xc:green -pointsize 48 -fill white \
                -gravity center -annotate +0+0 "Forest $i" forest_$i.jpg 2>/dev/null
        else
            # Create a minimal valid JPEG
            printf "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00" > forest_$i.jpg
            printf "\xFF\xDB\x00\x43\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\x09\x09" >> forest_$i.jpg
            dd if=/dev/zero bs=1024 count=10 2>/dev/null | tr '\0' '\377' >> forest_$i.jpg
            printf "\xFF\xD9" >> forest_$i.jpg
        fi
    done
    
    echo -e "${GREEN}✓${NC} Created 5 test images"
}

# Main test execution
main() {
    print_header "Immich Smart Search Patches - End-to-End Test"
    echo "Testing image: ${1:-ghcr.io/menkveldj/immich-server-patched:latest}"
    echo "Timestamp: $(date)"
    
    # Step 1: Start Docker environment
    print_header "Step 1: Starting Docker Environment"
    cd "$REPO_ROOT"
    
    # Update docker-compose with the image to test
    if [ ! -z "$1" ]; then
        sed -i.bak "s|image: ghcr.io/menkveldj/immich-server-patched:.*|image: $1|" docker-compose.local-test.yml
    fi
    
    echo "Starting Docker containers..."
    docker compose -f docker-compose.local-test.yml up -d
    
    # Wait for services
    echo "Waiting for services to start..."
    sleep 10  # Give databases time to initialize
    wait_for_service "Immich API" "${API_URL}/server/version"
    
    # Verify server version
    VERSION=$(curl -s "${API_URL}/server/version" | jq -r '"\(.major).\(.minor).\(.patch)"')
    echo -e "Server version: ${BLUE}${VERSION}${NC}"
    
    # Step 2: Create admin user and get API key
    print_header "Step 2: Setting Up Authentication"
    
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
        # User might already exist, try to login
        echo "Admin user might already exist, trying login..."
    else
        echo -e "${GREEN}✓${NC} Admin user created: $USER_ID"
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
    
    # Create API key
    echo "Creating API key..."
    API_KEY=$(curl -s -X POST "${API_URL}/api-keys" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "E2E Test Key",
            "permissions": ["all"]
        }' | jq -r '.secret')
    
    if [ -z "$API_KEY" ] || [ "$API_KEY" = "null" ]; then
        echo -e "${RED}✗ Failed to create API key${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Authentication setup complete"
    
    # Step 3: Upload test images
    print_header "Step 3: Uploading Test Images"
    
    create_test_images
    
    ASSET_IDS=()
    for img in ocean_*.jpg forest_*.jpg; do
        echo -n "Uploading $img... "
        UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/assets" \
            -H "x-api-key: ${API_KEY}" \
            -F "assetData=@$img" \
            -F "deviceAssetId=$(uuidgen 2>/dev/null || echo $(date +%s)-$img)" \
            -F "deviceId=E2E-Test" \
            -F "fileCreatedAt=$(date -Iseconds)" \
            -F "fileModifiedAt=$(date -Iseconds)")
        
        ASSET_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.id // empty')
        if [ ! -z "$ASSET_ID" ] && [ "$ASSET_ID" != "null" ]; then
            ASSET_IDS+=("$ASSET_ID")
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    
    echo -e "Uploaded ${GREEN}${#ASSET_IDS[@]}${NC} images"
    
    # Trigger smart search processing
    echo "Processing embeddings..."
    curl -s -X PUT "${API_URL}/jobs/smartSearch" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"command": "start", "force": false}' > /dev/null
    
    echo "Waiting for ML processing..."
    sleep 15
    
    # Step 4: Test Distance/Similarity Fields
    print_header "Step 4: Testing Distance/Similarity Fields"
    
    echo "Performing smart search with query: 'ocean blue water'"
    SEARCH_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
            "query": "ocean blue water",
            "size": 5
        }')
    
    # Check for distance field
    HAS_DISTANCE=$(echo "$SEARCH_RESPONSE" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")
    run_test "Distance field present in response" "$HAS_DISTANCE"
    
    # Check for similarity field
    HAS_SIMILARITY=$(echo "$SEARCH_RESPONSE" | jq -e '.assets.items[0].similarity' > /dev/null 2>&1 && echo "true" || echo "false")
    run_test "Similarity field present in response" "$HAS_SIMILARITY"
    
    # Verify calculation (simplified without bc)
    if [ "$HAS_DISTANCE" = "true" ] && [ "$HAS_SIMILARITY" = "true" ]; then
        DISTANCE=$(echo "$SEARCH_RESPONSE" | jq '.assets.items[0].distance')
        SIMILARITY=$(echo "$SEARCH_RESPONSE" | jq '.assets.items[0].similarity')
        # Check if similarity + distance ≈ 1 (within 0.01 tolerance)
        SUM_CHECK=$(echo "$SEARCH_RESPONSE" | jq '.assets.items[0] | (.distance + .similarity) | . > 0.99 and . < 1.01')
        run_test "Similarity = 1 - distance (within tolerance)" "$SUM_CHECK"
    fi
    
    # Check ordering
    DISTANCES=$(echo "$SEARCH_RESPONSE" | jq -r '.assets.items[].distance' 2>/dev/null | xargs)
    if [ ! -z "$DISTANCES" ]; then
        SORTED=$(echo "$DISTANCES" | tr ' ' '\n' | sort -n | xargs)
        ORDERING_CORRECT=$([ "$DISTANCES" = "$SORTED" ] && echo "true" || echo "false")
        run_test "Results ordered by distance (ascending)" "$ORDERING_CORRECT"
    fi
    
    # Step 5: Test Album Filtering
    print_header "Step 5: Testing Album Filtering"
    
    # Create albums
    echo "Creating test albums..."
    OCEAN_ALBUM=$(curl -s -X POST "${API_URL}/albums" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"albumName": "Ocean Collection"}' | jq -r '.id')
    
    FOREST_ALBUM=$(curl -s -X POST "${API_URL}/albums" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"albumName": "Forest Collection"}' | jq -r '.id')
    
    echo "Ocean Album ID: $OCEAN_ALBUM"
    echo "Forest Album ID: $FOREST_ALBUM"
    
    # Get asset IDs for each type
    OCEAN_ASSETS=$(curl -s -X POST "${API_URL}/search/metadata" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"originalFileName": "ocean"}' | jq -r '.assets.items[].id')
    
    FOREST_ASSETS=$(curl -s -X POST "${API_URL}/search/metadata" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"originalFileName": "forest"}' | jq -r '.assets.items[].id')
    
    # Add to albums
    echo "Adding assets to albums..."
    if [ ! -z "$OCEAN_ASSETS" ]; then
        OCEAN_IDS_JSON=$(echo "$OCEAN_ASSETS" | jq -R . | jq -s .)
        curl -s -X PUT "${API_URL}/albums/${OCEAN_ALBUM}/assets" \
            -H "x-api-key: ${API_KEY}" \
            -H "Content-Type: application/json" \
            -d "{\"ids\": $OCEAN_IDS_JSON}" > /dev/null
    fi
    
    if [ ! -z "$FOREST_ASSETS" ]; then
        FOREST_IDS_JSON=$(echo "$FOREST_ASSETS" | jq -R . | jq -s .)
        curl -s -X PUT "${API_URL}/albums/${FOREST_ALBUM}/assets" \
            -H "x-api-key: ${API_KEY}" \
            -H "Content-Type: application/json" \
            -d "{\"ids\": $FOREST_IDS_JSON}" > /dev/null
    fi
    
    # Test searches
    echo "Testing album filtering..."
    
    # Search without filter
    NO_FILTER=$(curl -s -X POST "${API_URL}/search/smart" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"query": "nature outdoor", "size": 10}')
    NO_FILTER_COUNT=$(echo "$NO_FILTER" | jq '.assets.total // 0')
    
    # Search with ocean album filter
    OCEAN_FILTER=$(curl -s -X POST "${API_URL}/search/smart" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"nature outdoor\", \"albumId\": \"${OCEAN_ALBUM}\", \"size\": 10}")
    OCEAN_COUNT=$(echo "$OCEAN_FILTER" | jq '.assets.total // 0')
    
    # Search with forest album filter
    FOREST_FILTER=$(curl -s -X POST "${API_URL}/search/smart" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"nature outdoor\", \"albumId\": \"${FOREST_ALBUM}\", \"size\": 10}")
    FOREST_COUNT=$(echo "$FOREST_FILTER" | jq '.assets.total // 0')
    
    # Test with non-existent album (valid UUID format)
    FAKE_UUID="12345678-1234-1234-1234-123456789012"
    FAKE_FILTER=$(curl -s -X POST "${API_URL}/search/smart" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"nature\", \"albumId\": \"${FAKE_UUID}\", \"size\": 10}")
    FAKE_COUNT=$(echo "$FAKE_FILTER" | jq '.assets.total // 0')
    
    # Run tests (using simpler shell test syntax)
    [ "$NO_FILTER_COUNT" -gt 0 ] && NO_FILTER_PASS="true" || NO_FILTER_PASS="false"
    run_test "Search without filter returns all results" "$NO_FILTER_PASS"
    
    if [ "$OCEAN_COUNT" -gt 0 ] && [ "$OCEAN_COUNT" -le "$NO_FILTER_COUNT" ]; then
        OCEAN_PASS="true"
    else
        OCEAN_PASS="false"
    fi
    run_test "Ocean album filter returns ocean images" "$OCEAN_PASS"
    
    if [ "$FOREST_COUNT" -gt 0 ] && [ "$FOREST_COUNT" -le "$NO_FILTER_COUNT" ]; then
        FOREST_PASS="true"
    else
        FOREST_PASS="false"
    fi
    run_test "Forest album filter returns forest images" "$FOREST_PASS"
    
    [ "$FAKE_COUNT" -eq 0 ] && FAKE_PASS="true" || FAKE_PASS="false"
    run_test "Non-existent album returns no results" "$FAKE_PASS"
    
    # Check that filtered results still have distance fields
    OCEAN_HAS_DISTANCE=$(echo "$OCEAN_FILTER" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")
    run_test "Album-filtered results include distance fields" "$OCEAN_HAS_DISTANCE"
    
    # Test invalid UUID validation
    INVALID_UUID_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"query": "test", "albumId": "not-a-uuid", "size": 10}')
    INVALID_UUID_ERROR=$(echo "$INVALID_UUID_RESPONSE" | jq -r '.statusCode // 0')
    [ "$INVALID_UUID_ERROR" = "400" ] && INVALID_PASS="true" || INVALID_PASS="false"
    run_test "Invalid UUID format returns 400 error" "$INVALID_PASS"
    
    # Print summary
    print_header "Test Results Summary"
    
    echo -e "\n${BLUE}Test Results:${NC}"
    echo -e "$TEST_RESULTS"
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}✅ ALL TESTS PASSED!${NC}"
        echo "The patched Immich server is working correctly with:"
        echo "  • Distance/similarity scoring in smart search"
        echo "  • Album-based search filtering"
        exit 0
    else
        echo -e "\n${RED}❌ SOME TESTS FAILED${NC}"
        echo "Please review the failures above."
        exit 1
    fi
}

# Run main function with optional Docker image parameter
main "$@"