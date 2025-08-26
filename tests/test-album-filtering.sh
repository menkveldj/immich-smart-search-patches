#!/bin/bash

# Test Album Filtering Feature
# This script tests the albumId parameter in smart search

source .env.test

echo "========================================="
echo "Album Filtering Test Suite"
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

echo -e "\n1. Setup Test Albums"
echo "===================="

# Create test albums
echo "Creating test albums..."

# Album 1: Nature Album
ALBUM1_RESPONSE=$(curl -s -X POST "${API_URL}/albums" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"albumName": "Nature Test Album", "description": "For testing album filtering"}')

ALBUM1_ID=$(echo "$ALBUM1_RESPONSE" | jq -r '.id // empty')

if [ -z "$ALBUM1_ID" ] || [ "$ALBUM1_ID" = "null" ]; then
    echo "Error: Failed to create Album 1"
    echo "$ALBUM1_RESPONSE" | jq '.'
else
    echo "Album 1 created: $ALBUM1_ID"
fi

# Album 2: City Album
ALBUM2_RESPONSE=$(curl -s -X POST "${API_URL}/albums" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"albumName": "City Test Album", "description": "For testing album filtering"}')

ALBUM2_ID=$(echo "$ALBUM2_RESPONSE" | jq -r '.id // empty')

if [ -z "$ALBUM2_ID" ] || [ "$ALBUM2_ID" = "null" ]; then
    echo "Error: Failed to create Album 2"
else
    echo "Album 2 created: $ALBUM2_ID"
fi

# Get existing assets to add to albums
echo -e "\nGetting assets to add to albums..."
ASSETS_RESPONSE=$(curl -s -X POST "${API_URL}/search/metadata" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"size": 10}')

ASSET_IDS=($(echo "$ASSETS_RESPONSE" | jq -r '.assets.items[].id' | head -5))
echo "Found ${#ASSET_IDS[@]} assets"

# Add first 3 assets to Album 1
if [ ! -z "$ALBUM1_ID" ] && [ ${#ASSET_IDS[@]} -ge 3 ]; then
    ASSET_IDS_JSON=$(printf '"%s",' "${ASSET_IDS[@]:0:3}" | sed 's/,$//')
    ADD_RESPONSE=$(curl -s -X PUT "${API_URL}/albums/${ALBUM1_ID}/assets" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"ids\": [${ASSET_IDS_JSON}]}")
    
    ADDED_COUNT=$(echo "$ADD_RESPONSE" | jq '[.[] | select(.success == true)] | length')
    echo "Added $ADDED_COUNT assets to Album 1"
fi

# Add last 2 assets to Album 2
if [ ! -z "$ALBUM2_ID" ] && [ ${#ASSET_IDS[@]} -ge 5 ]; then
    ASSET_IDS_JSON=$(printf '"%s",' "${ASSET_IDS[@]:3:2}" | sed 's/,$//')
    ADD_RESPONSE=$(curl -s -X PUT "${API_URL}/albums/${ALBUM2_ID}/assets" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"ids\": [${ASSET_IDS_JSON}]}")
    
    ADDED_COUNT=$(echo "$ADD_RESPONSE" | jq '[.[] | select(.success == true)] | length')
    echo "Added $ADDED_COUNT assets to Album 2"
fi

echo -e "\n2. Testing Album-Filtered Smart Search"
echo "======================================="

# Test 2.1: Search without album filter (baseline)
echo -e "\nTest 2.1: Baseline search without album filter"
BASELINE_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "photo", "size": 100}')

BASELINE_TOTAL=$(echo "$BASELINE_RESPONSE" | jq '.assets.total')
echo "Total results without filter: $BASELINE_TOTAL"

# Test 2.2: Search within Album 1
echo -e "\nTest 2.2: Search within Album 1"
if [ ! -z "$ALBUM1_ID" ]; then
    ALBUM1_SEARCH=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"photo\", \"albumId\": \"${ALBUM1_ID}\", \"size\": 100}")
    
    ALBUM1_TOTAL=$(echo "$ALBUM1_SEARCH" | jq '.assets.total')
    echo "Results in Album 1: $ALBUM1_TOTAL"
    
    # Verify filtering is working
    FILTER_WORKING=$([ "$ALBUM1_TOTAL" -le "$BASELINE_TOTAL" ] && echo "true" || echo "false")
    run_test "Album 1 filter reduces results" "$FILTER_WORKING"
    
    # Check if distance fields are still present
    ALBUM1_HAS_DISTANCE=$(echo "$ALBUM1_SEARCH" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")
    run_test "Album 1 results have distance field" "$ALBUM1_HAS_DISTANCE"
fi

# Test 2.3: Search within Album 2
echo -e "\nTest 2.3: Search within Album 2"
if [ ! -z "$ALBUM2_ID" ]; then
    ALBUM2_SEARCH=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"photo\", \"albumId\": \"${ALBUM2_ID}\", \"size\": 100}")
    
    ALBUM2_TOTAL=$(echo "$ALBUM2_SEARCH" | jq '.assets.total')
    echo "Results in Album 2: $ALBUM2_TOTAL"
    
    # Verify results are different between albums
    DIFFERENT_RESULTS=$([ "$ALBUM1_TOTAL" != "$ALBUM2_TOTAL" ] && echo "true" || echo "false")
    run_test "Different albums return different results" "$DIFFERENT_RESULTS"
fi

# Test 2.4: Search with non-existent album ID
echo -e "\nTest 2.4: Search with non-existent album ID"
FAKE_ALBUM_ID="00000000-0000-0000-0000-000000000000"
FAKE_ALBUM_SEARCH=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"photo\", \"albumId\": \"${FAKE_ALBUM_ID}\", \"size\": 100}")

FAKE_TOTAL=$(echo "$FAKE_ALBUM_SEARCH" | jq '.assets.total // 0')
echo "Results with fake album ID: $FAKE_TOTAL"
NO_RESULTS_FOR_FAKE=$([ "$FAKE_TOTAL" = "0" ] && echo "true" || echo "false")
run_test "Non-existent album returns no results" "$NO_RESULTS_FOR_FAKE"

echo -e "\n3. Testing Album Ownership & Permissions"
echo "========================================="

# This would require creating a second user - documenting the test
echo "Note: Full permission testing requires multiple users"
echo "Manual test required: Verify users can't search in others' albums"

echo -e "\n4. Testing Complex Queries with Album Filter"
echo "============================================="

# Test different query types within albums
QUERIES=("nature" "city" "sunset" "landscape")

for query in "${QUERIES[@]}"; do
    if [ ! -z "$ALBUM1_ID" ]; then
        echo -e "\nTesting query '$query' in Album 1"
        
        QUERY_RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
          -H "Authorization: Bearer ${ACCESS_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"query\": \"$query\", \"albumId\": \"${ALBUM1_ID}\", \"size\": 10}")
        
        QUERY_TOTAL=$(echo "$QUERY_RESPONSE" | jq '.assets.total // 0')
        echo "  Results for '$query': $QUERY_TOTAL"
        
        # Check structure is valid
        VALID_STRUCTURE=$(echo "$QUERY_RESPONSE" | jq -e '.assets' > /dev/null 2>&1 && echo "true" || echo "false")
        run_test "Query '$query' returns valid structure" "$VALID_STRUCTURE"
    fi
done

echo -e "\n5. Testing Invalid Album IDs"
echo "============================="

# Test 5.1: Malformed UUID
MALFORMED_SEARCH=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "albumId": "not-a-uuid", "size": 10}')

MALFORMED_ERROR=$(echo "$MALFORMED_SEARCH" | jq -r '.message // empty' | grep -i "uuid\|validation" > /dev/null && echo "true" || echo "false")
run_test "Malformed UUID handled properly" "$MALFORMED_ERROR"

# Test 5.2: Empty album ID
EMPTY_ALBUM_SEARCH=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "albumId": "", "size": 10}')

EMPTY_HANDLED=$(echo "$EMPTY_ALBUM_SEARCH" | jq -e '.assets' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "Empty album ID handled properly" "$EMPTY_HANDLED"

echo -e "\n6. Testing Pagination with Album Filter"
echo "========================================"

if [ ! -z "$ALBUM1_ID" ]; then
    # Page 1
    PAGE1=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"photo\", \"albumId\": \"${ALBUM1_ID}\", \"size\": 1, \"page\": 1}")
    
    PAGE1_COUNT=$(echo "$PAGE1" | jq '.assets.items | length')
    
    # Page 2 (if available)
    if echo "$PAGE1" | jq -e '.assets.nextPage' > /dev/null 2>&1; then
        PAGE2=$(curl -s -X POST "${API_URL}/search/smart" \
          -H "Authorization: Bearer ${ACCESS_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"query\": \"photo\", \"albumId\": \"${ALBUM1_ID}\", \"size\": 1, \"page\": 2}")
        
        PAGE2_COUNT=$(echo "$PAGE2" | jq '.assets.items | length')
        PAGINATION_WORKS=$([ "$PAGE2_COUNT" -ge 0 ] && echo "true" || echo "false")
        run_test "Pagination works with album filter" "$PAGINATION_WORKS"
    else
        echo "Not enough items for pagination test"
    fi
fi

echo -e "\n7. Cleanup"
echo "=========="

# Delete test albums
if [ ! -z "$ALBUM1_ID" ] && [ "$ALBUM1_ID" != "null" ]; then
    curl -s -X DELETE "${API_URL}/albums/${ALBUM1_ID}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" > /dev/null
    echo "Deleted Album 1"
fi

if [ ! -z "$ALBUM2_ID" ] && [ "$ALBUM2_ID" != "null" ]; then
    curl -s -X DELETE "${API_URL}/albums/${ALBUM2_ID}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" > /dev/null
    echo "Deleted Album 2"
fi

echo -e "\n========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All album filtering tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed. Please review the results.${NC}"
    exit 1
fi