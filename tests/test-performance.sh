#!/bin/bash

# Performance Test Suite for Smart Search Features
# This script benchmarks the performance impact of distance/similarity scoring and album filtering

source .env.test

echo "========================================="
echo "Performance Test Suite"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Performance metrics storage
declare -a RESPONSE_TIMES=()
declare -a MEMORY_USAGE=()

# Function to measure response time
measure_response_time() {
    local start_time=$(date +%s%3N)
    "$@" > /dev/null 2>&1
    local end_time=$(date +%s%3N)
    echo $((end_time - start_time))
}

# Function to format time
format_time() {
    local ms=$1
    if [ $ms -lt 1000 ]; then
        echo "${ms}ms"
    else
        echo "$(echo "scale=2; $ms/1000" | bc)s"
    fi
}

# Function to calculate statistics
calculate_stats() {
    local -a times=("$@")
    local count=${#times[@]}
    
    if [ $count -eq 0 ]; then
        echo "N/A"
        return
    fi
    
    # Calculate sum
    local sum=0
    for time in "${times[@]}"; do
        sum=$((sum + time))
    done
    
    # Calculate average
    local avg=$((sum / count))
    
    # Sort for percentiles
    local sorted=($(printf '%s\n' "${times[@]}" | sort -n))
    
    # Calculate percentiles
    local p50_idx=$((count * 50 / 100))
    local p95_idx=$((count * 95 / 100))
    local p99_idx=$((count * 99 / 100))
    
    [ $p50_idx -eq 0 ] && p50_idx=1
    [ $p95_idx -eq 0 ] && p95_idx=1
    [ $p99_idx -eq 0 ] && p99_idx=1
    
    local p50=${sorted[$((p50_idx - 1))]}
    local p95=${sorted[$((p95_idx - 1))]}
    local p99=${sorted[$((p99_idx - 1))]}
    local min=${sorted[0]}
    local max=${sorted[$((count - 1))]}
    
    echo -e "  Min: $(format_time $min)"
    echo -e "  Avg: $(format_time $avg)"
    echo -e "  P50: $(format_time $p50)"
    echo -e "  P95: $(format_time $p95)"
    echo -e "  P99: $(format_time $p99)"
    echo -e "  Max: $(format_time $max)"
}

echo -e "\n1. Baseline Performance Tests"
echo "=============================="

# Test 1.1: Standard metadata search (no vector operations)
echo -e "\n${BLUE}Test 1.1: Metadata search performance (10 requests)${NC}"
METADATA_TIMES=()
for i in {1..10}; do
    TIME=$(measure_response_time curl -s -X POST "${API_URL}/search/metadata" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"size": 100}')
    METADATA_TIMES+=($TIME)
    echo -n "."
done
echo -e "\nMetadata Search Stats:"
calculate_stats "${METADATA_TIMES[@]}"

# Test 1.2: Smart search without album filter
echo -e "\n${BLUE}Test 1.2: Smart search performance (10 requests)${NC}"
SMART_TIMES=()
for i in {1..10}; do
    TIME=$(measure_response_time curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"query": "nature landscape", "size": 100}')
    SMART_TIMES+=($TIME)
    echo -n "."
done
echo -e "\nSmart Search Stats:"
calculate_stats "${SMART_TIMES[@]}"

echo -e "\n2. Album Filtering Performance Impact"
echo "======================================"

# Create test album for performance testing
echo "Creating performance test album..."
PERF_ALBUM_RESPONSE=$(curl -s -X POST "${API_URL}/albums" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"albumName": "Performance Test Album", "description": "For benchmarking"}')

PERF_ALBUM_ID=$(echo "$PERF_ALBUM_RESPONSE" | jq -r '.id // empty')

if [ ! -z "$PERF_ALBUM_ID" ] && [ "$PERF_ALBUM_ID" != "null" ]; then
    # Add assets to album
    ASSETS_RESPONSE=$(curl -s -X POST "${API_URL}/search/metadata" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"size": 50}')
    
    ASSET_IDS=($(echo "$ASSETS_RESPONSE" | jq -r '.assets.items[].id'))
    if [ ${#ASSET_IDS[@]} -gt 0 ]; then
        ASSET_IDS_JSON=$(printf '"%s",' "${ASSET_IDS[@]}" | sed 's/,$//')
        curl -s -X PUT "${API_URL}/albums/${PERF_ALBUM_ID}/assets" \
          -H "Authorization: Bearer ${ACCESS_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"ids\": [${ASSET_IDS_JSON}]}" > /dev/null
    fi
    
    # Test 2.1: Smart search with album filter
    echo -e "\n${BLUE}Test 2.1: Smart search with album filter (10 requests)${NC}"
    ALBUM_SMART_TIMES=()
    for i in {1..10}; do
        TIME=$(measure_response_time curl -s -X POST "${API_URL}/search/smart" \
          -H "Authorization: Bearer ${ACCESS_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"query\": \"photo\", \"albumId\": \"${PERF_ALBUM_ID}\", \"size\": 100}")
        ALBUM_SMART_TIMES+=($TIME)
        echo -n "."
    done
    echo -e "\nAlbum-filtered Smart Search Stats:"
    calculate_stats "${ALBUM_SMART_TIMES[@]}"
    
    # Compare performance
    echo -e "\n${YELLOW}Performance Comparison:${NC}"
    AVG_SMART=$(echo "scale=0; ($(IFS=+; echo "${SMART_TIMES[*]}")) / ${#SMART_TIMES[@]}" | bc)
    AVG_ALBUM_SMART=$(echo "scale=0; ($(IFS=+; echo "${ALBUM_SMART_TIMES[*]}")) / ${#ALBUM_SMART_TIMES[@]}" | bc)
    
    if [ $AVG_ALBUM_SMART -lt $AVG_SMART ]; then
        IMPROVEMENT=$(echo "scale=1; ($AVG_SMART - $AVG_ALBUM_SMART) * 100 / $AVG_SMART" | bc)
        echo -e "${GREEN}✓ Album filtering improves performance by ${IMPROVEMENT}%${NC}"
    else
        OVERHEAD=$(echo "scale=1; ($AVG_ALBUM_SMART - $AVG_SMART) * 100 / $AVG_SMART" | bc)
        echo -e "${YELLOW}⚠ Album filtering adds ${OVERHEAD}% overhead${NC}"
    fi
fi

echo -e "\n3. Varying Result Set Sizes"
echo "============================"

SIZES=(1 10 25 50 100)
for size in "${SIZES[@]}"; do
    echo -e "\n${BLUE}Test 3.${size}: Smart search with size=${size}${NC}"
    SIZE_TIMES=()
    for i in {1..5}; do
        TIME=$(measure_response_time curl -s -X POST "${API_URL}/search/smart" \
          -H "Authorization: Bearer ${ACCESS_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"query\": \"test\", \"size\": ${size}}")
        SIZE_TIMES+=($TIME)
        echo -n "."
    done
    echo -e "\nStats for size=${size}:"
    calculate_stats "${SIZE_TIMES[@]}"
done

echo -e "\n4. Complex Query Performance"
echo "============================"

QUERIES=(
    "simple word"
    "nature landscape sunset"
    "urban city architecture modern buildings"
    "portrait people faces smiling happy outdoor"
)

for query in "${QUERIES[@]}"; do
    WORD_COUNT=$(echo "$query" | wc -w | tr -d ' ')
    echo -e "\n${BLUE}Test 4.${WORD_COUNT}: Query with ${WORD_COUNT} words${NC}"
    echo "Query: \"$query\""
    
    QUERY_TIMES=()
    for i in {1..5}; do
        TIME=$(measure_response_time curl -s -X POST "${API_URL}/search/smart" \
          -H "Authorization: Bearer ${ACCESS_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"query\": \"$query\", \"size\": 50}")
        QUERY_TIMES+=($TIME)
        echo -n "."
    done
    echo -e "\nStats:"
    calculate_stats "${QUERY_TIMES[@]}"
done

echo -e "\n5. Pagination Performance"
echo "========================="

echo -e "\n${BLUE}Test 5.1: First page performance${NC}"
PAGE1_TIMES=()
for i in {1..5}; do
    TIME=$(measure_response_time curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"query": "photo", "size": 20, "page": 1}')
    PAGE1_TIMES+=($TIME)
    echo -n "."
done
echo -e "\nPage 1 Stats:"
calculate_stats "${PAGE1_TIMES[@]}"

echo -e "\n${BLUE}Test 5.2: Deep pagination (page 5)${NC}"
PAGE5_TIMES=()
for i in {1..5}; do
    TIME=$(measure_response_time curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"query": "photo", "size": 20, "page": 5}')
    PAGE5_TIMES+=($TIME)
    echo -n "."
done
echo -e "\nPage 5 Stats:"
calculate_stats "${PAGE5_TIMES[@]}"

echo -e "\n6. Concurrent Request Performance"
echo "================================="

echo -e "\n${BLUE}Test 6.1: Sequential requests (baseline)${NC}"
SEQ_START=$(date +%s%3N)
for i in {1..10}; do
    curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"query": "test", "size": 10}' > /dev/null 2>&1
done
SEQ_END=$(date +%s%3N)
SEQ_TOTAL=$((SEQ_END - SEQ_START))
echo "Total time for 10 sequential requests: $(format_time $SEQ_TOTAL)"

echo -e "\n${BLUE}Test 6.2: Concurrent requests${NC}"
CONC_START=$(date +%s%3N)
for i in {1..10}; do
    curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"query": "test", "size": 10}' > /dev/null 2>&1 &
done
wait
CONC_END=$(date +%s%3N)
CONC_TOTAL=$((CONC_END - CONC_START))
echo "Total time for 10 concurrent requests: $(format_time $CONC_TOTAL)"

SPEEDUP=$(echo "scale=2; $SEQ_TOTAL / $CONC_TOTAL" | bc)
echo -e "${GREEN}Concurrency speedup: ${SPEEDUP}x${NC}"

echo -e "\n7. Distance Field Overhead"
echo "=========================="

# Test the overhead of calculating and returning distance fields
echo -e "\n${BLUE}Measuring distance field calculation overhead${NC}"

# This tests whether the distance/similarity fields add significant overhead
QUERIES_WITH_DISTANCE=()
for i in {1..10}; do
    START=$(date +%s%3N)
    RESPONSE=$(curl -s -X POST "${API_URL}/search/smart" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"query": "landscape", "size": 50}')
    END=$(date +%s%3N)
    
    # Check if distance fields are present
    HAS_DISTANCE=$(echo "$RESPONSE" | jq -e '.assets.items[0].distance' > /dev/null 2>&1 && echo "true" || echo "false")
    
    if [ "$HAS_DISTANCE" = "true" ]; then
        QUERIES_WITH_DISTANCE+=($((END - START)))
    fi
    echo -n "."
done

if [ ${#QUERIES_WITH_DISTANCE[@]} -gt 0 ]; then
    echo -e "\nQueries with distance fields:"
    calculate_stats "${QUERIES_WITH_DISTANCE[@]}"
else
    echo -e "\n${RED}Warning: Distance fields not detected in responses${NC}"
fi

echo -e "\n8. Cleanup"
echo "=========="

# Delete performance test album
if [ ! -z "$PERF_ALBUM_ID" ] && [ "$PERF_ALBUM_ID" != "null" ]; then
    curl -s -X DELETE "${API_URL}/albums/${PERF_ALBUM_ID}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" > /dev/null
    echo "Deleted performance test album"
fi

echo -e "\n========================================="
echo "Performance Test Summary"
echo "========================================="

# Generate performance summary
echo -e "\n${YELLOW}Key Performance Metrics:${NC}"
echo "1. Smart Search (with distance) avg response time: $(format_time $AVG_SMART)"
echo "2. Album-filtered search avg response time: $(format_time $AVG_ALBUM_SMART)"
echo "3. Concurrency speedup: ${SPEEDUP}x"
echo "4. Pagination overhead (page 5 vs page 1): $(echo "scale=1; ($(IFS=+; echo "${PAGE5_TIMES[*]}")) / ${#PAGE5_TIMES[@]} - ($(IFS=+; echo "${PAGE1_TIMES[*]}")) / ${#PAGE1_TIMES[@]}" | bc)ms"

echo -e "\n${GREEN}✓ Performance testing complete${NC}"