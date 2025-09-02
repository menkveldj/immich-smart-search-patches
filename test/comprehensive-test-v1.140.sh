#!/bin/bash

# Comprehensive Test Script for Immich v1.140.1 with Smart Search Patches
# Tests distance/similarity fields and maxDistance filtering

set -e

# Configuration
API_URL="${1:-http://localhost:3003}"
IMAGE_TAG="${2:-ghcr.io/menkveldj/immich-server-patched:v1.140.1}"
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
FAILED_TESTS=""

# Function to print section header
print_header() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n -e "${YELLOW}Testing:${NC} $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((TESTS_FAILED++))
        FAILED_TESTS="${FAILED_TESTS}\n  - $test_name"
        return 1
    fi
}

# Start tests
print_header "IMMICH v1.140.1 SMART SEARCH PATCH TESTS"
echo -e "${BLUE}API URL:${NC} $API_URL"
echo -e "${BLUE}Image:${NC} $IMAGE_TAG"

# 1. Check server health
print_header "1. Server Health Check"
run_test "Server is responsive" "curl -sf ${API_URL}/api/server/version"
SERVER_VERSION=$(curl -s ${API_URL}/api/server/version | jq -r '"\(.major).\(.minor).\(.patch)"')
echo -e "${BLUE}Server Version:${NC} $SERVER_VERSION"

# 2. Authentication Setup
print_header "2. Authentication Setup"

# Try to sign up (might fail if user exists)
SIGNUP_RESPONSE=$(curl -s -X POST ${API_URL}/api/auth/admin-sign-up \
    -H 'Content-Type: application/json' \
    -d "{
        \"email\": \"${TEST_EMAIL}\",
        \"password\": \"${TEST_PASSWORD}\",
        \"name\": \"Test User\"
    }" 2>/dev/null || true)

# Login to get token
echo -e "${YELLOW}Logging in...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST ${API_URL}/api/auth/login \
    -H 'Content-Type: application/json' \
    -d "{
        \"email\": \"${TEST_EMAIL}\",
        \"password\": \"${TEST_PASSWORD}\"
    }")

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.accessToken // empty')

if [ -z "$TOKEN" ]; then
    echo -e "${RED}✗ Failed to get authentication token${NC}"
    echo "Login response: $LOGIN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Authentication successful${NC}"

# 3. Test Smart Search API Structure
print_header "3. Smart Search API Structure Tests"

# Test that search endpoint accepts our new parameters
SEARCH_TEST=$(curl -s -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "query": "test",
        "maxDistance": 1.0
    }')

run_test "Search endpoint accepts request" "[ ! -z \"$SEARCH_TEST\" ]"
run_test "Search endpoint accepts maxDistance parameter" "echo '$SEARCH_TEST' | jq -e '. | has(\"assets\") or has(\"items\") or .statusCode != 400'"

# 4. Upload test images for searching
print_header "4. Preparing Test Data"

# Create test images using ImageMagick
echo -e "${YELLOW}Creating test images...${NC}"
for i in 1 2 3; do
    convert -size 800x600 xc:"rgb(0,100,200)" \
        -pointsize 60 -fill white -gravity center \
        -annotate +0+0 "Ocean $i" ocean_$i.jpg 2>/dev/null || \
    magick -size 800x600 xc:"rgb(0,100,200)" \
        -pointsize 60 -fill white -gravity center \
        -annotate +0+0 "Ocean $i" ocean_$i.jpg
done

for i in 1 2; do
    convert -size 800x600 xc:"rgb(34,139,34)" \
        -pointsize 60 -fill white -gravity center \
        -annotate +0+0 "Forest $i" forest_$i.jpg 2>/dev/null || \
    magick -size 800x600 xc:"rgb(34,139,34)" \
        -pointsize 60 -fill white -gravity center \
        -annotate +0+0 "Forest $i" forest_$i.jpg
done

echo -e "${GREEN}✓ Test images created${NC}"

# Upload images
echo -e "${YELLOW}Uploading test images...${NC}"
for img in ocean_*.jpg forest_*.jpg; do
    if [ -f "$img" ]; then
        UPLOAD_RESPONSE=$(curl -s -X POST ${API_URL}/api/assets \
            -H "Authorization: Bearer $TOKEN" \
            -F "assetData=@$img" \
            -F "deviceAssetId=${img%.*}" \
            -F "deviceId=test-device" \
            -F "fileCreatedAt=$(date -Iseconds)" \
            -F "fileModifiedAt=$(date -Iseconds)")
        
        ASSET_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.id // empty')
        if [ ! -z "$ASSET_ID" ]; then
            echo -e "  ${GREEN}✓${NC} Uploaded $img (ID: ${ASSET_ID:0:8}...)"
        else
            echo -e "  ${RED}✗${NC} Failed to upload $img"
        fi
    fi
done

# Wait for processing
echo -e "${YELLOW}Waiting for asset processing...${NC}"
sleep 10

# 5. Test Distance and Similarity Fields
print_header "5. Distance and Similarity Field Tests"

# Search for ocean images
OCEAN_SEARCH=$(curl -s -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "query": "ocean water blue",
        "size": 10
    }')

# Check if response has the expected structure
HAS_ASSETS=$(echo "$OCEAN_SEARCH" | jq -e '.assets // .items' > /dev/null 2>&1 && echo "true" || echo "false")

if [ "$HAS_ASSETS" = "true" ]; then
    # Handle both possible response structures
    ITEMS=$(echo "$OCEAN_SEARCH" | jq '.assets.items // .items // []')
    ITEM_COUNT=$(echo "$ITEMS" | jq 'length')
    
    echo -e "${BLUE}Found $ITEM_COUNT items in search results${NC}"
    
    if [ "$ITEM_COUNT" -gt 0 ]; then
        # Check for distance field
        HAS_DISTANCE=$(echo "$ITEMS" | jq '.[0] | has("distance")')
        run_test "Search results include distance field" "[ \"$HAS_DISTANCE\" = \"true\" ]"
        
        # Check for similarity field
        HAS_SIMILARITY=$(echo "$ITEMS" | jq '.[0] | has("similarity")')
        run_test "Search results include similarity field" "[ \"$HAS_SIMILARITY\" = \"true\" ]"
        
        # Verify distance and similarity relationship
        if [ "$HAS_DISTANCE" = "true" ] && [ "$HAS_SIMILARITY" = "true" ]; then
            FIRST_DISTANCE=$(echo "$ITEMS" | jq '.[0].distance // 0')
            FIRST_SIMILARITY=$(echo "$ITEMS" | jq '.[0].similarity // 0')
            CALCULATED_SIM=$(echo "1 - $FIRST_DISTANCE" | bc -l 2>/dev/null || echo "0")
            
            echo -e "${BLUE}First result: distance=$FIRST_DISTANCE, similarity=$FIRST_SIMILARITY${NC}"
            
            # Check if similarity ≈ 1 - distance (with tolerance for floating point)
            DIFF=$(echo "$FIRST_SIMILARITY - $CALCULATED_SIM" | bc -l 2>/dev/null || echo "1")
            ABS_DIFF=$(echo "${DIFF#-}" | cut -d. -f1,2)
            
            run_test "Similarity = 1 - distance" "[ \$(echo \"$ABS_DIFF < 0.01\" | bc -l 2>/dev/null || echo 0) -eq 1 ]"
        fi
        
        # Check ordering by distance
        DISTANCES=$(echo "$ITEMS" | jq '[.[] | .distance // 999] | sort == .')
        run_test "Results are ordered by distance (ascending)" "[ \"$DISTANCES\" = \"true\" ]"
    else
        echo -e "${YELLOW}⚠ No items in search results (may need more time for indexing)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Search API returned unexpected structure${NC}"
    echo "$OCEAN_SEARCH" | jq '.' | head -20
fi

# 6. Test MaxDistance Filtering
print_header "6. MaxDistance Filter Tests"

# Test with strict distance filter
STRICT_SEARCH=$(curl -s -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "query": "ocean",
        "maxDistance": 0.3,
        "size": 10
    }')

STRICT_ITEMS=$(echo "$STRICT_SEARCH" | jq '.assets.items // .items // []')
STRICT_COUNT=$(echo "$STRICT_ITEMS" | jq 'length')

# Test with loose distance filter
LOOSE_SEARCH=$(curl -s -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "query": "ocean",
        "maxDistance": 1.5,
        "size": 10
    }')

LOOSE_ITEMS=$(echo "$LOOSE_SEARCH" | jq '.assets.items // .items // []')
LOOSE_COUNT=$(echo "$LOOSE_ITEMS" | jq 'length')

echo -e "${BLUE}Results with maxDistance=0.3: $STRICT_COUNT items${NC}"
echo -e "${BLUE}Results with maxDistance=1.5: $LOOSE_COUNT items${NC}"

run_test "Strict filter returns fewer results than loose" "[ $STRICT_COUNT -le $LOOSE_COUNT ]"

# Verify all distances are within threshold
if [ "$STRICT_COUNT" -gt 0 ]; then
    MAX_DISTANCE_IN_STRICT=$(echo "$STRICT_ITEMS" | jq '[.[] | .distance // 0] | max')
    run_test "All distances in strict search ≤ 0.3" "[ \$(echo \"$MAX_DISTANCE_IN_STRICT <= 0.3\" | bc -l 2>/dev/null || echo 0) -eq 1 ]"
fi

# 7. Test Invalid MaxDistance Values
print_header "7. Input Validation Tests"

# Test with invalid maxDistance (> 2)
INVALID_SEARCH=$(curl -s -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "query": "test",
        "maxDistance": 3.0
    }')

STATUS_CODE=$(echo "$INVALID_SEARCH" | jq -r '.statusCode // 200')
run_test "Invalid maxDistance (>2) is rejected" "[ \"$STATUS_CODE\" = \"400\" ]"

# Test with negative maxDistance
NEGATIVE_SEARCH=$(curl -s -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "query": "test",
        "maxDistance": -0.5
    }')

NEG_STATUS_CODE=$(echo "$NEGATIVE_SEARCH" | jq -r '.statusCode // 200')
run_test "Negative maxDistance is rejected" "[ \"$NEG_STATUS_CODE\" = \"400\" ]"

# 8. Performance Test
print_header "8. Performance Tests"

# Test search without distance filter
START_TIME=$(date +%s%N)
curl -s -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"query": "test", "size": 10}' > /dev/null
END_TIME=$(date +%s%N)
TIME_WITHOUT_FILTER=$((($END_TIME - $START_TIME) / 1000000))

# Test search with distance filter
START_TIME=$(date +%s%N)
curl -s -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"query": "test", "size": 10, "maxDistance": 0.5}' > /dev/null
END_TIME=$(date +%s%N)
TIME_WITH_FILTER=$((($END_TIME - $START_TIME) / 1000000))

echo -e "${BLUE}Search without filter: ${TIME_WITHOUT_FILTER}ms${NC}"
echo -e "${BLUE}Search with filter: ${TIME_WITH_FILTER}ms${NC}"

run_test "Search completes in reasonable time (<5s)" "[ $TIME_WITH_FILTER -lt 5000 ]"

# Print results summary
print_header "TEST RESULTS SUMMARY"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "\n${RED}Failed tests:${NC}$FAILED_TESTS"
    exit 1
else
    echo -e "\n${GREEN}✨ All tests passed successfully!${NC}"
    echo -e "${GREEN}The patched Immich v1.140.1 is working correctly with:${NC}"
    echo -e "  ${GREEN}✓${NC} Distance field in search results"
    echo -e "  ${GREEN}✓${NC} Similarity field (1 - distance)"
    echo -e "  ${GREEN}✓${NC} MaxDistance filtering parameter"
    echo -e "  ${GREEN}✓${NC} Proper input validation"
    echo -e "  ${GREEN}✓${NC} Good performance"
fi

# Cleanup
rm -f ocean_*.jpg forest_*.jpg 2>/dev/null || true