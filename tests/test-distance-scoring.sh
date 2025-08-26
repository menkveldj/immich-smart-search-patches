#!/bin/bash

# Test Distance/Similarity Scoring Feature
# This script comprehensively tests the smart search distance and similarity fields

source .env.test

echo "========================================="
echo "Distance/Similarity Scoring Test Suite"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

echo -e "\n1. Testing Smart Search with Distance Fields"
echo "============================================="

# Test 1: Basic smart search returns distance field
echo -e "\nTest 1.1: Verify distance field is present"
SEARCH_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "nature landscape", "size": 5}')

HAS_DISTANCE=$(echo "$SEARCH_RESPONSE" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "Distance field present in response" "$HAS_DISTANCE"

# Test 1.2: Verify similarity field is present
HAS_SIMILARITY=$(echo "$SEARCH_RESPONSE" | jq -e '.assets.items[0].similarity' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "Similarity field present in response" "$HAS_SIMILARITY"

# Test 1.3: Verify distance is a valid float
if [ "$HAS_DISTANCE" = "true" ]; then
    DISTANCE=$(echo "$SEARCH_RESPONSE" | jq '.assets.items[0].distance')
    IS_NUMBER=$(echo "$DISTANCE" | grep -E '^[0-9]+\.?[0-9]*$' > /dev/null && echo "true" || echo "false")
    run_test "Distance is a valid number" "$IS_NUMBER"
    
    # Test 1.4: Verify distance is in expected range (0-2 for cosine distance)
    VALID_RANGE=$(echo "$DISTANCE < 2 && $DISTANCE >= 0" | bc -l 2>/dev/null | grep -q "1" && echo "true" || echo "false")
    run_test "Distance is in valid range [0,2]" "$VALID_RANGE"
fi

# Test 1.5: Verify similarity calculation
if [ "$HAS_SIMILARITY" = "true" ] && [ "$HAS_DISTANCE" = "true" ]; then
    SIMILARITY=$(echo "$SEARCH_RESPONSE" | jq '.assets.items[0].similarity')
    EXPECTED_SIMILARITY=$(echo "1 - $DISTANCE" | bc -l)
    
    # Check if similarity matches expected (within small tolerance)
    DIFF=$(echo "scale=6; ($SIMILARITY - $EXPECTED_SIMILARITY)" | bc -l)
    ABS_DIFF=$(echo "${DIFF#-}")
    SIMILARITY_CORRECT=$(echo "$ABS_DIFF < 0.001" | bc -l | grep -q "1" && echo "true" || echo "false")
    run_test "Similarity = 1 - distance" "$SIMILARITY_CORRECT"
fi

echo -e "\n2. Testing Result Ordering by Distance"
echo "======================================="

# Test 2.1: Verify results are ordered by distance (ascending)
DISTANCES=$(echo "$SEARCH_RESPONSE" | jq -r '.assets.items[].distance' 2>/dev/null)
if [ ! -z "$DISTANCES" ]; then
    SORTED_DISTANCES=$(echo "$DISTANCES" | sort -g)
    IS_SORTED=$([ "$DISTANCES" = "$SORTED_DISTANCES" ] && echo "true" || echo "false")
    run_test "Results ordered by distance (closest first)" "$IS_SORTED"
    
    # Display distance distribution
    echo -e "\nDistance distribution of results:"
    echo "$SEARCH_RESPONSE" | jq -r '.assets.items[] | "\(.distance) - \(.originalFileName)"' | head -5
fi

echo -e "\n3. Testing Different Query Types"
echo "================================="

# Test different search queries
QUERIES=("sunset" "city buildings" "people faces" "abstract art")

for query in "${QUERIES[@]}"; do
    echo -e "\nTesting query: '$query'"
    
    QUERY_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"$query\", \"size\": 3}")
    
    QUERY_HAS_DISTANCE=$(echo "$QUERY_RESPONSE" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")
    run_test "Query '$query' returns distance" "$QUERY_HAS_DISTANCE"
    
    if [ "$QUERY_HAS_DISTANCE" = "true" ]; then
        FIRST_DISTANCE=$(echo "$QUERY_RESPONSE" | jq '.assets.items[0].distance')
        echo "  Best match distance: $FIRST_DISTANCE"
    fi
done

echo -e "\n4. Testing Pagination with Distance Fields"
echo "==========================================="

# Test 4.1: First page
PAGE1_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "size": 2, "page": 1}')

PAGE1_HAS_DISTANCE=$(echo "$PAGE1_RESPONSE" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "Page 1 has distance fields" "$PAGE1_HAS_DISTANCE"

# Test 4.2: Second page (if available)
if echo "$PAGE1_RESPONSE" | jq -e '.assets.nextPage' > /dev/null 2>&1; then
    PAGE2_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"query": "test", "size": 2, "page": 2}')
    
    PAGE2_HAS_DISTANCE=$(echo "$PAGE2_RESPONSE" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")
    run_test "Page 2 maintains distance fields" "$PAGE2_HAS_DISTANCE"
fi

echo -e "\n5. Testing Edge Cases"
echo "====================="

# Test 5.1: Empty query results
EMPTY_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "xyznonexistentquery123", "size": 10}')

EMPTY_TOTAL=$(echo "$EMPTY_RESPONSE" | jq '.assets.total')
if [ "$EMPTY_TOTAL" = "0" ]; then
    run_test "Empty results handled correctly" "true"
else
    # Even if not empty, check fields are still present
    EMPTY_HAS_FIELDS=$(echo "$EMPTY_RESPONSE" | jq -e '.assets' > /dev/null 2>&1 && echo "true" || echo "false")
    run_test "Non-matching query still returns valid structure" "$EMPTY_HAS_FIELDS"
fi

# Test 5.2: Large result set
LARGE_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "photo", "size": 100}')

LARGE_COUNT=$(echo "$LARGE_RESPONSE" | jq '.assets.items | length')
LARGE_ALL_HAVE_DISTANCE=true
for i in $(seq 0 $((LARGE_COUNT - 1))); do
    if ! echo "$LARGE_RESPONSE" | jq -e ".assets.items[$i].distance" > /dev/null 2>&1; then
        LARGE_ALL_HAVE_DISTANCE=false
        break
    fi
done
run_test "All items in large result set have distance" "$LARGE_ALL_HAVE_DISTANCE"

echo -e "\n6. Comparing with Standard Search"
echo "=================================="

# Test that regular metadata search doesn't have distance fields
METADATA_RESPONSE=$(curl -s -X POST "${API_URL}/search/metadata" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"size": 5}')

METADATA_HAS_NO_DISTANCE=$(echo "$METADATA_RESPONSE" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "false" || echo "true")
run_test "Metadata search doesn't have distance (expected)" "$METADATA_HAS_NO_DISTANCE"

echo -e "\n========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All distance/similarity tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed. Please review the results.${NC}"
    exit 1
fi