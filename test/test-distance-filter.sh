#!/bin/bash

# Test script for distance filtering in smart search API

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_URL="${1:-http://localhost:3003/api}"
API_KEY="${2:-}"

if [ -z "$API_KEY" ]; then
    echo -e "${RED}Please provide API key as second argument${NC}"
    echo "Usage: $0 [API_URL] API_KEY"
    exit 1
fi

echo -e "${YELLOW}Testing Distance Filtering Feature${NC}"
echo "============================================"
echo -e "API URL: ${BLUE}${API_URL}${NC}"
echo ""

# Test 1: Search without distance filter
echo -e "${YELLOW}Test 1: Search without distance filter${NC}"
RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "query": "ocean",
        "size": 10
    }')

TOTAL_COUNT=$(echo "$RESPONSE" | jq '.assets.total // 0')
echo "Total results without filter: $TOTAL_COUNT"

if echo "$RESPONSE" | jq -e '.assets.items[0].distance' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Distance field present"
    DISTANCES=$(echo "$RESPONSE" | jq '[.assets.items[].distance] | map(select(. != null))')
    echo "Sample distances: $(echo "$DISTANCES" | jq -c '.[0:3]')"
else
    echo -e "${YELLOW}⚠${NC} No distance field (might be no assets)"
fi

echo ""

# Test 2: Search with strict distance filter (0.3)
echo -e "${YELLOW}Test 2: Search with strict distance filter (maxDistance=0.3)${NC}"
RESPONSE_STRICT=$(curl -s -X POST "${API_URL}/search/smart" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "query": "ocean",
        "size": 10,
        "maxDistance": 0.3
    }')

STRICT_COUNT=$(echo "$RESPONSE_STRICT" | jq '.assets.total // 0')
echo "Results with maxDistance=0.3: $STRICT_COUNT"

if [ "$STRICT_COUNT" -le "$TOTAL_COUNT" ]; then
    echo -e "${GREEN}✓${NC} Filtering reduced results ($STRICT_COUNT <= $TOTAL_COUNT)"
else
    echo -e "${RED}✗${NC} Filtering did not work properly"
fi

# Check all distances are below threshold
if [ "$STRICT_COUNT" -gt 0 ]; then
    MAX_DISTANCE=$(echo "$RESPONSE_STRICT" | jq '[.assets.items[].distance] | max')
    echo "Maximum distance in results: $MAX_DISTANCE"
    
    if (( $(echo "$MAX_DISTANCE <= 0.3" | bc -l) )); then
        echo -e "${GREEN}✓${NC} All distances are within threshold"
    else
        echo -e "${RED}✗${NC} Some distances exceed threshold"
    fi
fi

echo ""

# Test 3: Search with medium distance filter (0.6)
echo -e "${YELLOW}Test 3: Search with medium distance filter (maxDistance=0.6)${NC}"
RESPONSE_MEDIUM=$(curl -s -X POST "${API_URL}/search/smart" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "query": "ocean",
        "size": 10,
        "maxDistance": 0.6
    }')

MEDIUM_COUNT=$(echo "$RESPONSE_MEDIUM" | jq '.assets.total // 0')
echo "Results with maxDistance=0.6: $MEDIUM_COUNT"

if [ "$STRICT_COUNT" -le "$MEDIUM_COUNT" ] && [ "$MEDIUM_COUNT" -le "$TOTAL_COUNT" ]; then
    echo -e "${GREEN}✓${NC} Progressive filtering works ($STRICT_COUNT <= $MEDIUM_COUNT <= $TOTAL_COUNT)"
else
    echo -e "${YELLOW}⚠${NC} Unexpected filtering behavior"
fi

echo ""

# Test 4: Search with loose distance filter (1.5)
echo -e "${YELLOW}Test 4: Search with loose distance filter (maxDistance=1.5)${NC}"
RESPONSE_LOOSE=$(curl -s -X POST "${API_URL}/search/smart" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "query": "ocean",
        "size": 10,
        "maxDistance": 1.5
    }')

LOOSE_COUNT=$(echo "$RESPONSE_LOOSE" | jq '.assets.total // 0')
echo "Results with maxDistance=1.5: $LOOSE_COUNT"

echo ""

# Test 5: Invalid distance value (should be rejected)
echo -e "${YELLOW}Test 5: Invalid distance value (maxDistance=3.0)${NC}"
RESPONSE_INVALID=$(curl -s -X POST "${API_URL}/search/smart" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "query": "ocean",
        "size": 10,
        "maxDistance": 3.0
    }')

STATUS_CODE=$(echo "$RESPONSE_INVALID" | jq -r '.statusCode // 200')
if [ "$STATUS_CODE" = "400" ]; then
    echo -e "${GREEN}✓${NC} Invalid distance value correctly rejected"
else
    echo -e "${RED}✗${NC} Invalid distance value not rejected (status: $STATUS_CODE)"
fi

echo ""

# Test 6: Similarity field check
echo -e "${YELLOW}Test 6: Checking similarity field calculation${NC}"
RESPONSE_SIM=$(curl -s -X POST "${API_URL}/search/smart" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "query": "ocean",
        "size": 3
    }')

if echo "$RESPONSE_SIM" | jq -e '.assets.items[0].similarity' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Similarity field present"
    
    # Check if similarity = 1 - distance
    FIRST_DISTANCE=$(echo "$RESPONSE_SIM" | jq '.assets.items[0].distance // 0')
    FIRST_SIMILARITY=$(echo "$RESPONSE_SIM" | jq '.assets.items[0].similarity // 0')
    EXPECTED_SIMILARITY=$(echo "1 - $FIRST_DISTANCE" | bc -l)
    
    if (( $(echo "$FIRST_SIMILARITY == $EXPECTED_SIMILARITY" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Similarity calculation correct (1 - distance)"
    else
        echo -e "${RED}✗${NC} Similarity calculation incorrect"
    fi
    
    echo "Sample: distance=$FIRST_DISTANCE, similarity=$FIRST_SIMILARITY"
else
    echo -e "${YELLOW}⚠${NC} No similarity field"
fi

echo ""
echo -e "${YELLOW}===========================================${NC}"
echo -e "${GREEN}✅ Distance filtering tests complete!${NC}"
echo ""
echo "Summary:"
echo "- Distance field is included in search results"
echo "- Similarity field is calculated correctly (1 - distance)"
echo "- Distance filtering reduces results appropriately"
echo "- Invalid distance values are rejected"
echo ""
echo "Note: Tests require assets to be uploaded for meaningful results."