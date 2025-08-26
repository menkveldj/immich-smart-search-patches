#!/bin/bash

# Integration Test Suite for Smart Search Features
# This script tests end-to-end workflows and integration between components

source .env.test

echo "========================================="
echo "Integration Test Suite"
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

echo -e "\n1. Full Workflow: Create Album → Add Assets → Search"
echo "===================================================="

echo -e "\n${BLUE}Step 1.1: Create a new album${NC}"
WORKFLOW_ALBUM=$(curl -s -X POST "${API_URL}/albums" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"albumName": "Integration Test Album", "description": "Full workflow test"}')

WORKFLOW_ALBUM_ID=$(echo "$WORKFLOW_ALBUM" | jq -r '.id // empty')

if [ -z "$WORKFLOW_ALBUM_ID" ] || [ "$WORKFLOW_ALBUM_ID" = "null" ]; then
    echo -e "${RED}Failed to create album for workflow test${NC}"
    exit 1
fi

echo "Created album: $WORKFLOW_ALBUM_ID"
run_test "Album created successfully" "true"

echo -e "\n${BLUE}Step 1.2: Get available assets${NC}"
ALL_ASSETS=$(curl -s -X POST "${API_URL}/search/metadata" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"size": 20}')

ASSET_IDS=($(echo "$ALL_ASSETS" | jq -r '.assets.items[].id' | head -10))
echo "Found ${#ASSET_IDS[@]} assets to work with"

echo -e "\n${BLUE}Step 1.3: Add assets to album${NC}"
if [ ${#ASSET_IDS[@]} -gt 0 ]; then
    ASSET_IDS_JSON=$(printf '"%s",' "${ASSET_IDS[@]}" | sed 's/,$//')
    ADD_RESULT=$(curl -s -X PUT "${API_URL}/albums/${WORKFLOW_ALBUM_ID}/assets" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"ids\": [${ASSET_IDS_JSON}]}")
    
    ADDED_COUNT=$(echo "$ADD_RESULT" | jq '[.[] | select(.success == true)] | length')
    echo "Added $ADDED_COUNT assets to album"
    run_test "Assets added to album" "[ $ADDED_COUNT -gt 0 ]"
fi

echo -e "\n${BLUE}Step 1.4: Search within the album${NC}"
ALBUM_SEARCH=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"photo\", \"albumId\": \"${WORKFLOW_ALBUM_ID}\", \"size\": 100}")

ALBUM_RESULTS=$(echo "$ALBUM_SEARCH" | jq '.assets.total // 0')
echo "Search found $ALBUM_RESULTS results in album"

# Verify results have distance fields
HAS_DISTANCE=$(echo "$ALBUM_SEARCH" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "Search results include distance field" "$HAS_DISTANCE"

HAS_SIMILARITY=$(echo "$ALBUM_SEARCH" | jq -e '.assets.items[0].similarity' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "Search results include similarity field" "$HAS_SIMILARITY"

echo -e "\n${BLUE}Step 1.5: Compare with non-album search${NC}"
GENERAL_SEARCH=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "photo", "size": 100}')

GENERAL_RESULTS=$(echo "$GENERAL_SEARCH" | jq '.assets.total // 0')
echo "General search found $GENERAL_RESULTS results"

FILTERING_WORKS=$([ "$ALBUM_RESULTS" -le "$GENERAL_RESULTS" ] && echo "true" || echo "false")
run_test "Album filtering reduces result set" "$FILTERING_WORKS"

echo -e "\n2. Cross-Feature Integration"
echo "============================"

echo -e "\n${BLUE}Test 2.1: Album filter + Pagination${NC}"
PAGE1=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"test\", \"albumId\": \"${WORKFLOW_ALBUM_ID}\", \"size\": 2, \"page\": 1}")

PAGE1_COUNT=$(echo "$PAGE1" | jq '.assets.items | length')
PAGE1_HAS_DISTANCE=$(echo "$PAGE1" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")

run_test "Pagination with album filter works" "[ $PAGE1_COUNT -ge 0 ]"
run_test "Paginated results maintain distance fields" "$PAGE1_HAS_DISTANCE"

echo -e "\n${BLUE}Test 2.2: Different queries in same album${NC}"
QUERIES=("landscape" "portrait" "nature" "urban")

for query in "${QUERIES[@]}"; do
    QUERY_RESULT=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"$query\", \"albumId\": \"${WORKFLOW_ALBUM_ID}\", \"size\": 5}")
    
    QUERY_VALID=$(echo "$QUERY_RESULT" | jq -e '.assets' > /dev/null 2>&1 && echo "true" || echo "false")
    run_test "Query '$query' works with album filter" "$QUERY_VALID"
done

echo -e "\n3. Multiple Albums Integration"
echo "=============================="

echo -e "\n${BLUE}Creating additional test albums${NC}"
# Create second album
ALBUM2=$(curl -s -X POST "${API_URL}/albums" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"albumName": "Integration Album 2", "description": "Second test album"}')

ALBUM2_ID=$(echo "$ALBUM2" | jq -r '.id // empty')

if [ ! -z "$ALBUM2_ID" ] && [ "$ALBUM2_ID" != "null" ]; then
    # Add different assets to album 2
    if [ ${#ASSET_IDS[@]} -ge 5 ]; then
        ASSET_IDS_2_JSON=$(printf '"%s",' "${ASSET_IDS[@]:2:3}" | sed 's/,$//')
        curl -s -X PUT "${API_URL}/albums/${ALBUM2_ID}/assets" \
          -H "Authorization: Bearer ${ACCESS_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"ids\": [${ASSET_IDS_2_JSON}]}" > /dev/null
    fi
    
    # Search in album 1
    SEARCH1=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"test\", \"albumId\": \"${WORKFLOW_ALBUM_ID}\", \"size\": 100}")
    
    COUNT1=$(echo "$SEARCH1" | jq '.assets.total // 0')
    
    # Search in album 2
    SEARCH2=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"test\", \"albumId\": \"${ALBUM2_ID}\", \"size\": 100}")
    
    COUNT2=$(echo "$SEARCH2" | jq '.assets.total // 0')
    
    echo "Album 1 results: $COUNT1"
    echo "Album 2 results: $COUNT2"
    
    ALBUMS_ISOLATED=$([ "$COUNT1" != "$COUNT2" ] && echo "true" || echo "false")
    run_test "Different albums return different results" "$ALBUMS_ISOLATED"
fi

echo -e "\n4. Distance Scoring Consistency"
echo "==============================="

echo -e "\n${BLUE}Test 4.1: Same query returns consistent distances${NC}"
CONSISTENT_DISTANCES=true

# Run the same query multiple times
for i in {1..3}; do
    CONSISTENCY_CHECK=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"query": "sunset beach", "size": 3}')
    
    if [ $i -eq 1 ]; then
        FIRST_DISTANCES=$(echo "$CONSISTENCY_CHECK" | jq -r '.assets.items[].distance' 2>/dev/null)
    else
        CURRENT_DISTANCES=$(echo "$CONSISTENCY_CHECK" | jq -r '.assets.items[].distance' 2>/dev/null)
        if [ "$FIRST_DISTANCES" != "$CURRENT_DISTANCES" ]; then
            # Allow small variations due to floating point
            CONSISTENT_DISTANCES=false
        fi
    fi
done

run_test "Distance calculations are consistent" "$CONSISTENT_DISTANCES"

echo -e "\n${BLUE}Test 4.2: Distance correlates with similarity${NC}"
CORRELATION_TEST=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "mountain landscape", "size": 5}')

CORRELATION_VALID=true
if echo "$CORRELATION_TEST" | jq -e '.assets.items[0].distance' > /dev/null 2>&1; then
    # Check each result
    for i in {0..4}; do
        DISTANCE=$(echo "$CORRELATION_TEST" | jq ".assets.items[$i].distance // null" 2>/dev/null)
        SIMILARITY=$(echo "$CORRELATION_TEST" | jq ".assets.items[$i].similarity // null" 2>/dev/null)
        
        if [ "$DISTANCE" != "null" ] && [ "$SIMILARITY" != "null" ]; then
            # Verify similarity ≈ 1 - distance
            EXPECTED_SIM=$(echo "1 - $DISTANCE" | bc -l)
            DIFF=$(echo "scale=6; ($SIMILARITY - $EXPECTED_SIM)" | bc -l 2>/dev/null || echo "0")
            ABS_DIFF=$(echo "${DIFF#-}")
            
            if (( $(echo "$ABS_DIFF > 0.01" | bc -l 2>/dev/null || echo 0) )); then
                CORRELATION_VALID=false
                echo "  Mismatch at index $i: distance=$DISTANCE, similarity=$SIMILARITY"
            fi
        fi
    done
fi

run_test "Distance and similarity correctly correlated" "$CORRELATION_VALID"

echo -e "\n5. Edge Case Integration"
echo "======================="

echo -e "\n${BLUE}Test 5.1: Empty album search${NC}"
# Create empty album
EMPTY_ALBUM=$(curl -s -X POST "${API_URL}/albums" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"albumName": "Empty Album", "description": "No assets"}')

EMPTY_ALBUM_ID=$(echo "$EMPTY_ALBUM" | jq -r '.id // empty')

if [ ! -z "$EMPTY_ALBUM_ID" ] && [ "$EMPTY_ALBUM_ID" != "null" ]; then
    EMPTY_SEARCH=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"test\", \"albumId\": \"${EMPTY_ALBUM_ID}\", \"size\": 10}")
    
    EMPTY_COUNT=$(echo "$EMPTY_SEARCH" | jq '.assets.total // 0')
    run_test "Empty album returns no results" "[ $EMPTY_COUNT -eq 0 ]"
fi

echo -e "\n${BLUE}Test 5.2: Very specific query${NC}"
SPECIFIC_SEARCH=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "purple elephant riding bicycle in space", "size": 5}')

SPECIFIC_VALID=$(echo "$SPECIFIC_SEARCH" | jq -e '.assets' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "Unusual query handled properly" "$SPECIFIC_VALID"

if echo "$SPECIFIC_SEARCH" | jq -e '.assets.items[0]' > /dev/null 2>&1; then
    SPECIFIC_HAS_FIELDS=$(echo "$SPECIFIC_SEARCH" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")
    run_test "Unusual query results have distance fields" "$SPECIFIC_HAS_FIELDS"
fi

echo -e "\n6. API Compatibility Tests"
echo "=========================="

echo -e "\n${BLUE}Test 6.1: Backward compatibility (no albumId)${NC}"
BACKWARD_COMPAT=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "size": 10}')

BACKWARD_WORKS=$(echo "$BACKWARD_COMPAT" | jq -e '.assets' > /dev/null 2>&1 && echo "true" || echo "false")
run_test "API works without albumId (backward compatible)" "$BACKWARD_WORKS"

echo -e "\n${BLUE}Test 6.2: Field presence verification${NC}"
FIELD_CHECK=$(curl -s -X POST "${API_URL}/search/smart" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query": "photo", "size": 1}')

if echo "$FIELD_CHECK" | jq -e '.assets.items[0]' > /dev/null 2>&1; then
    # Check all expected fields are present
    REQUIRED_FIELDS=("id" "originalFileName" "distance" "similarity")
    ALL_FIELDS_PRESENT=true
    
    for field in "${REQUIRED_FIELDS[@]}"; do
        if ! echo "$FIELD_CHECK" | jq -e ".assets.items[0].$field" > /dev/null 2>&1; then
            ALL_FIELDS_PRESENT=false
            echo "  Missing field: $field"
        fi
    done
    
    run_test "All expected fields present in response" "$ALL_FIELDS_PRESENT"
fi

echo -e "\n7. Cleanup"
echo "=========="

# Delete all test albums
ALBUMS_TO_DELETE=("$WORKFLOW_ALBUM_ID" "$ALBUM2_ID" "$EMPTY_ALBUM_ID")

for album_id in "${ALBUMS_TO_DELETE[@]}"; do
    if [ ! -z "$album_id" ] && [ "$album_id" != "null" ]; then
        curl -s -X DELETE "${API_URL}/albums/${album_id}" \
          -H "Authorization: Bearer ${ACCESS_TOKEN}" > /dev/null
        echo "Deleted album: $album_id"
    fi
done

echo -e "\n========================================="
echo "Integration Test Summary"
echo "========================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"

echo -e "\n${YELLOW}Integration Points Tested:${NC}"
echo "✓ Album creation and asset management"
echo "✓ Smart search with album filtering"
echo "✓ Distance and similarity field calculation"
echo "✓ Pagination with new features"
echo "✓ Multiple album isolation"
echo "✓ Edge case handling"
echo "✓ API backward compatibility"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All integration tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some integration tests failed. Please review.${NC}"
    exit 1
fi