#!/bin/bash

# Security Test Suite for Smart Search Features
# This script tests security aspects of the album filtering and distance scoring features

source .env.test

echo "========================================="
echo "Security Test Suite"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local result="$2"
    
    if [ "$result" = "true" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        ((TESTS_FAILED++))
    fi
}

echo -e "\n1. SQL Injection Tests"
echo "======================"

# Test 1.1: SQL injection in albumId parameter
echo -e "\n${BLUE}Test 1.1: SQL injection in albumId${NC}"
SQL_INJECTION_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "albumId": "'' OR 1=1 --", "size": 10}' 2>/dev/null)

# Check for validation error (should reject non-UUID)
SQL_INJECTION_BLOCKED=$(echo "$SQL_INJECTION_RESPONSE" | jq -r '.message // empty' | grep -iE "uuid|validation|invalid" > /dev/null && echo "true" || echo "false")
run_test "SQL injection in albumId blocked" "$SQL_INJECTION_BLOCKED"

# Test 1.2: SQL injection in query parameter
echo -e "\n${BLUE}Test 1.2: SQL injection in query parameter${NC}"
QUERY_INJECTION_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test'' OR 1=1; DROP TABLE assets; --", "size": 10}')

# Query should be processed as text for embedding, not SQL
QUERY_HANDLED=$(echo "$QUERY_INJECTION_RESPONSE" | jq -e '.assets' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "SQL injection in query safely handled" "$QUERY_HANDLED"

# Test 1.3: Command injection attempts
echo -e "\n${BLUE}Test 1.3: Command injection in albumId${NC}"
CMD_INJECTION_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "albumId": "$(cat /etc/passwd)", "size": 10}')

CMD_INJECTION_BLOCKED=$(echo "$CMD_INJECTION_RESPONSE" | jq -r '.message // empty' | grep -iE "uuid|validation" > /dev/null && echo "true" || echo "false")
run_test "Command injection blocked" "$CMD_INJECTION_BLOCKED"

echo -e "\n2. Authorization Tests"
echo "====================="

# Create a test album for authorization testing
echo "Creating authorization test album..."
AUTH_ALBUM_RESPONSE=$(curl -s -X POST "${API_URL}/albums" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"albumName": "Private Album", "description": "Authorization test"}')

AUTH_ALBUM_ID=$(echo "$AUTH_ALBUM_RESPONSE" | jq -r '.id // empty')

if [ ! -z "$AUTH_ALBUM_ID" ] && [ "$AUTH_ALBUM_ID" != "null" ]; then
    # Test 2.1: Valid authorization
    echo -e "\n${BLUE}Test 2.1: Authorized access to own album${NC}"
    AUTH_VALID_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"test\", \"albumId\": \"${AUTH_ALBUM_ID}\", \"size\": 10}")
    
    AUTH_VALID=$(echo "$AUTH_VALID_RESPONSE" | jq -e '.assets' > /dev/null 2>&1 && echo "true" || echo "false")
    run_test "Can search own album" "$AUTH_VALID"
    
    # Test 2.2: No authorization header
    echo -e "\n${BLUE}Test 2.2: Request without authorization${NC}"
    NO_AUTH_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"test\", \"albumId\": \"${AUTH_ALBUM_ID}\", \"size\": 10}")
    
    NO_AUTH_BLOCKED=$(echo "$NO_AUTH_RESPONSE" | jq -r '.message // .error // empty' | grep -iE "unauthorized|401|auth" > /dev/null && echo "true" || echo "false")
    run_test "Unauthorized request blocked" "$NO_AUTH_BLOCKED"
    
    # Test 2.3: Invalid token
    echo -e "\n${BLUE}Test 2.3: Invalid token${NC}"
    INVALID_TOKEN_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer invalid_token_12345" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"test\", \"albumId\": \"${AUTH_ALBUM_ID}\", \"size\": 10}")
    
    INVALID_TOKEN_BLOCKED=$(echo "$INVALID_TOKEN_RESPONSE" | jq -r '.message // .error // empty' | grep -iE "unauthorized|401|invalid" > /dev/null && echo "true" || echo "false")
    run_test "Invalid token blocked" "$INVALID_TOKEN_BLOCKED"
fi

echo -e "\n3. Input Validation Tests"
echo "========================="

# Test 3.1: Invalid UUID format
echo -e "\n${BLUE}Test 3.1: Invalid UUID format${NC}"
INVALID_UUID_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "albumId": "not-a-uuid", "size": 10}')

INVALID_UUID_REJECTED=$(echo "$INVALID_UUID_RESPONSE" | jq -r '.message // empty' | grep -iE "uuid|validation|invalid" > /dev/null && echo "true" || echo "false")
run_test "Invalid UUID format rejected" "$INVALID_UUID_REJECTED"

# Test 3.2: Empty albumId
echo -e "\n${BLUE}Test 3.2: Empty albumId${NC}"
EMPTY_ALBUM_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "albumId": "", "size": 10}')

EMPTY_HANDLED=$(echo "$EMPTY_ALBUM_RESPONSE" | jq -e '.assets' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "Empty albumId handled safely" "$EMPTY_HANDLED"

# Test 3.3: Null albumId
echo -e "\n${BLUE}Test 3.3: Null albumId${NC}"
NULL_ALBUM_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "albumId": null, "size": 10}')

NULL_HANDLED=$(echo "$NULL_ALBUM_RESPONSE" | jq -e '.assets' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "Null albumId handled safely" "$NULL_HANDLED"

# Test 3.4: Extremely long albumId
echo -e "\n${BLUE}Test 3.4: Extremely long input${NC}"
LONG_ID=$(printf 'a%.0s' {1..1000})
LONG_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"test\", \"albumId\": \"${LONG_ID}\", \"size\": 10}")

LONG_REJECTED=$(echo "$LONG_RESPONSE" | jq -r '.message // empty' | grep -iE "uuid|validation|too long" > /dev/null && echo "true" || echo "false")
run_test "Extremely long input rejected" "$LONG_REJECTED"

# Test 3.5: Special characters in albumId
echo -e "\n${BLUE}Test 3.5: Special characters in albumId${NC}"
SPECIAL_CHARS_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "albumId": "<script>alert(1)</script>", "size": 10}')

SPECIAL_CHARS_REJECTED=$(echo "$SPECIAL_CHARS_RESPONSE" | jq -r '.message // empty' | grep -iE "uuid|validation" > /dev/null && echo "true" || echo "false")
run_test "Special characters rejected" "$SPECIAL_CHARS_REJECTED"

echo -e "\n4. Cross-User Access Tests"
echo "=========================="

# Note: Full cross-user testing would require creating another user account
echo -e "${YELLOW}Note: Complete cross-user testing requires multiple user accounts${NC}"
echo "Manual verification required for:"
echo "- Users cannot search other users' private albums"
echo "- Shared album permissions are properly enforced"
echo "- Album ownership is properly validated"

# Test with a completely random UUID (likely belongs to no one)
echo -e "\n${BLUE}Test 4.1: Access to non-existent album${NC}"
RANDOM_UUID="$(uuidgen 2>/dev/null || echo "a1b2c3d4-e5f6-7890-abcd-ef1234567890")"
OTHER_ALBUM_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"test\", \"albumId\": \"${RANDOM_UUID}\", \"size\": 10}")

OTHER_ALBUM_EMPTY=$(echo "$OTHER_ALBUM_RESPONSE" | jq '.assets.total' | grep -E "^0$" > /dev/null && echo "true" || echo "false")
run_test "Non-existent album returns empty results" "$OTHER_ALBUM_EMPTY"

echo -e "\n5. Rate Limiting Tests"
echo "====================="

echo -e "\n${BLUE}Test 5.1: Rapid request handling${NC}"
echo "Sending 20 rapid requests..."

RATE_LIMIT_HIT=false
for i in {1..20}; do
    RAPID_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"query": "test", "size": 1}')
    
    HTTP_CODE=$(echo "$RAPID_RESPONSE" | tail -1)
    
    if [ "$HTTP_CODE" = "429" ]; then
        RATE_LIMIT_HIT=true
        echo "Rate limit hit at request $i"
        break
    fi
    
    echo -n "."
done

if [ "$RATE_LIMIT_HIT" = "true" ]; then
    echo -e "\n${YELLOW}Rate limiting is active (good for security)${NC}"
else
    echo -e "\n${YELLOW}No rate limiting detected (consider implementing for production)${NC}"
fi

echo -e "\n6. Data Exposure Tests"
echo "====================="

# Test 6.1: Check if distance values are reasonable
echo -e "\n${BLUE}Test 6.1: Distance values validation${NC}"
DISTANCE_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "nature", "size": 5}')

if echo "$DISTANCE_RESPONSE" | jq -e '.assets.items[0].distance' > /dev/null 2>&1; then
    DISTANCES=$(echo "$DISTANCE_RESPONSE" | jq -r '.assets.items[].distance')
    VALID_DISTANCES=true
    
    for distance in $DISTANCES; do
        # Check if distance is between 0 and 2 (valid range for cosine distance)
        if (( $(echo "$distance < 0 || $distance > 2" | bc -l) )); then
            VALID_DISTANCES=false
            break
        fi
    done
    
    run_test "Distance values in valid range [0,2]" "$VALID_DISTANCES"
fi

# Test 6.2: Check no sensitive data in responses
echo -e "\n${BLUE}Test 6.2: No sensitive data exposure${NC}"
SENSITIVE_CHECK_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "size": 2}')

# Check for potentially sensitive fields that shouldn't be exposed
NO_SENSITIVE_DATA=true
SENSITIVE_FIELDS=("password" "secret" "token" "key" "salt" "hash")

for field in "${SENSITIVE_FIELDS[@]}"; do
    if echo "$SENSITIVE_CHECK_RESPONSE" | jq -r ".. | keys?" 2>/dev/null | grep -i "$field" > /dev/null; then
        NO_SENSITIVE_DATA=false
        echo "  Found potentially sensitive field: $field"
    fi
done

run_test "No sensitive data in API responses" "$NO_SENSITIVE_DATA"

echo -e "\n7. Error Handling Tests"
echo "======================="

# Test 7.1: Malformed JSON
echo -e "\n${BLUE}Test 7.1: Malformed JSON handling${NC}"
MALFORMED_JSON_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{query: "test" "size": }')

MALFORMED_ERROR=$(echo "$MALFORMED_JSON_RESPONSE" | jq -r '.message // .error // empty' | grep -iE "json|parse|syntax" > /dev/null && echo "true" || echo "false")
run_test "Malformed JSON handled with error" "$MALFORMED_ERROR"

# Test 7.2: Missing required fields
echo -e "\n${BLUE}Test 7.2: Missing required fields${NC}"
MISSING_QUERY_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"size": 10}')

MISSING_ERROR=$(echo "$MISSING_QUERY_RESPONSE" | jq -r '.message // empty' | grep -iE "query|required|missing" > /dev/null && echo "true" || echo "false")
run_test "Missing required field handled" "$MISSING_ERROR"

# Test 7.3: Invalid data types
echo -e "\n${BLUE}Test 7.3: Invalid data types${NC}"
INVALID_TYPE_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "size": "not-a-number"}')

INVALID_TYPE_ERROR=$(echo "$INVALID_TYPE_RESPONSE" | jq -r '.message // empty' | grep -iE "number|integer|type" > /dev/null && echo "true" || echo "false")
run_test "Invalid data type handled" "$INVALID_TYPE_ERROR"

echo -e "\n8. Cleanup"
echo "=========="

# Delete test album
if [ ! -z "$AUTH_ALBUM_ID" ] && [ "$AUTH_ALBUM_ID" != "null" ]; then
    curl -s -X DELETE "${API_URL}/albums/${AUTH_ALBUM_ID}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" > /dev/null
    echo "Deleted authorization test album"
fi

echo -e "\n========================================="
echo "Security Test Summary"
echo "========================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All security tests passed!${NC}"
    echo -e "\n${YELLOW}Security Recommendations:${NC}"
    echo "1. Ensure rate limiting is configured for production"
    echo "2. Monitor for unusual search patterns"
    echo "3. Regularly review album access logs"
    echo "4. Consider implementing search query complexity limits"
    echo "5. Ensure proper authentication token rotation"
    exit 0
else
    echo -e "\n${RED}✗ Some security tests failed. Review and fix before deployment.${NC}"
    exit 1
fi