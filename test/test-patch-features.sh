#!/bin/bash

# Test script for patch features without requiring ML
# This tests that the API accepts the new parameters and returns the new fields

set -e

# Configuration
API_URL="${1:-http://localhost:3003}"
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

# Function to print header
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
        return 1
    fi
}

print_header "IMMICH PATCH VALIDATION TESTS"
echo -e "${BLUE}API URL:${NC} $API_URL"

# 1. Check server health
print_header "1. Server Health Check"
SERVER_VERSION=$(curl -s ${API_URL}/api/server/version | jq -r '"\(.major).\(.minor).\(.patch)"')
echo -e "${GREEN}✓ Server Version:${NC} $SERVER_VERSION"

# 2. Authentication
print_header "2. Authentication"

# Try to sign up (might fail if user exists)
SIGNUP_RESPONSE=$(curl -s -X POST ${API_URL}/api/auth/admin-sign-up \
    -H 'Content-Type: application/json' \
    -d "{
        \"email\": \"${TEST_EMAIL}\",
        \"password\": \"${TEST_PASSWORD}\",
        \"name\": \"Test User\"
    }" 2>/dev/null || true)

# Login
LOGIN_RESPONSE=$(curl -s -X POST ${API_URL}/api/auth/login \
    -H 'Content-Type: application/json' \
    -d "{
        \"email\": \"${TEST_EMAIL}\",
        \"password\": \"${TEST_PASSWORD}\"
    }")

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.accessToken // empty')

if [ -z "$TOKEN" ]; then
    echo -e "${RED}✗ Failed to get authentication token${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Authentication successful${NC}"

# 3. Test that API accepts maxDistance parameter
print_header "3. API Parameter Validation"

# Test with valid maxDistance
VALID_TEST=$(curl -s -w "\n%{http_code}" -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "query": "test",
        "maxDistance": 1.0
    }')

HTTP_CODE=$(echo "$VALID_TEST" | tail -n 1)
RESPONSE=$(echo "$VALID_TEST" | sed '$d')

run_test "API accepts maxDistance parameter" "[ \"$HTTP_CODE\" != \"400\" ]"

# Test maxDistance validation (> 2 should be rejected)
INVALID_TEST=$(curl -s -w "\n%{http_code}" -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "query": "test",
        "maxDistance": 3.0
    }')

INVALID_CODE=$(echo "$INVALID_TEST" | tail -n 1)

run_test "API rejects maxDistance > 2" "[ \"$INVALID_CODE\" = \"400\" ]"

# Test negative maxDistance (should be rejected)
NEGATIVE_TEST=$(curl -s -w "\n%{http_code}" -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "query": "test",
        "maxDistance": -0.5
    }')

NEGATIVE_CODE=$(echo "$NEGATIVE_TEST" | tail -n 1)

run_test "API rejects negative maxDistance" "[ \"$NEGATIVE_CODE\" = \"400\" ]"

# 4. Test API response structure (if ML is available and returns results)
print_header "4. Response Structure Tests"

# Make a search request to check response structure
SEARCH_RESPONSE=$(curl -s -X POST ${API_URL}/api/search/smart \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
        "query": "test",
        "size": 1
    }')

# Check if it's a 500 error (ML not available)
if echo "$SEARCH_RESPONSE" | jq -e '.statusCode == 500' > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ ML service not available - skipping response structure tests${NC}"
else
    # Check if we have results
    HAS_RESULTS=$(echo "$SEARCH_RESPONSE" | jq -e '.assets.items // .items // [] | length > 0' 2>/dev/null && echo "true" || echo "false")
    
    if [ "$HAS_RESULTS" = "true" ]; then
        ITEMS=$(echo "$SEARCH_RESPONSE" | jq '.assets.items // .items // []')
        
        # Check for distance field
        HAS_DISTANCE=$(echo "$ITEMS" | jq '.[0] | has("distance")' 2>/dev/null || echo "false")
        run_test "Response includes distance field" "[ \"$HAS_DISTANCE\" = \"true\" ]"
        
        # Check for similarity field
        HAS_SIMILARITY=$(echo "$ITEMS" | jq '.[0] | has("similarity")' 2>/dev/null || echo "false")
        run_test "Response includes similarity field" "[ \"$HAS_SIMILARITY\" = \"true\" ]"
        
        echo -e "${BLUE}Sample response item:${NC}"
        echo "$ITEMS" | jq '.[0] | {id, distance, similarity}' 2>/dev/null || echo "No items to display"
    else
        echo -e "${YELLOW}⚠ No search results available - response structure cannot be validated${NC}"
    fi
fi

# Print results summary
print_header "TEST RESULTS SUMMARY"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "\n${RED}✗ Some tests failed${NC}"
    exit 1
else
    echo -e "\n${GREEN}✨ All tests passed!${NC}"
    echo -e "${GREEN}The patch has been successfully applied:${NC}"
    echo -e "  ${GREEN}✓${NC} API accepts maxDistance parameter"
    echo -e "  ${GREEN}✓${NC} Input validation works correctly"
    if [ "$HAS_DISTANCE" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} Distance field present in responses"
        echo -e "  ${GREEN}✓${NC} Similarity field present in responses"
    fi
fi