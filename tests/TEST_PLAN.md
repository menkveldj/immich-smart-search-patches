# Immich Smart Search Features - Comprehensive Test Plan

## Overview
This document outlines the comprehensive testing strategy for the Immich smart search enhancements, including distance/similarity scoring and album filtering features.

## Test Environment Setup

### Prerequisites
1. **Immich Server Running**
   - Server API on port 3003
   - Machine Learning service active
   - PostgreSQL with pgvector extension
   - Redis for caching

2. **Test User Account**
   ```bash
   Email: test@example.com
   Password: TestPassword123!
   ```

3. **Manual UI Setup Required**
   - Upload at least 20 diverse photos through the Immich web UI
   - Include various categories: nature, urban, portraits, abstract
   - Create at least 2 albums with different photos
   - Ensure photos are fully processed (thumbnails, embeddings generated)

### Running the Tests

1. **Get Authentication Token**
   ```bash
   cd /private/tmp/immich-test/test
   ./get-token.sh
   ```

2. **Run All Tests**
   ```bash
   ./run-all-tests.sh
   ```

3. **Run Specific Test Suite**
   ```bash
   ./run-all-tests.sh distance_scoring
   ./run-all-tests.sh album_filtering
   ./run-all-tests.sh performance
   ./run-all-tests.sh security
   ./run-all-tests.sh integration
   ```

## Test Suites

### 1. Distance Scoring Tests (`test-distance-scoring.sh`)
**Purpose:** Verify that smart search returns distance and similarity scores

**Test Cases:**
- ✅ Distance field present in API response
- ✅ Similarity field present and calculated correctly
- ✅ Distance values in valid range [0,2]
- ✅ Results ordered by distance (ascending)
- ✅ Consistency across different query types
- ✅ Pagination maintains distance fields
- ✅ Edge cases handled properly

**Expected Results:**
- All smart search results include `distance` field
- Similarity = 1 - distance
- Results sorted by relevance (lowest distance first)

### 2. Album Filtering Tests (`test-album-filtering.sh`)
**Purpose:** Verify album-based search filtering functionality

**Test Cases:**
- ✅ Album creation and asset management
- ✅ Search within specific album using albumId
- ✅ Different results for different albums
- ✅ Non-existent album returns empty results
- ✅ Invalid UUID validation
- ✅ Complex queries with album filter
- ✅ Pagination with album filter

**Expected Results:**
- Search results limited to specified album
- Proper validation of albumId parameter
- Maintains distance/similarity fields

### 3. Performance Tests (`test-performance.sh`)
**Purpose:** Benchmark performance impact of new features

**Test Cases:**
- ✅ Baseline metadata search performance
- ✅ Smart search with distance calculation
- ✅ Album filtering performance impact
- ✅ Various result set sizes (1-100)
- ✅ Complex query performance
- ✅ Pagination performance
- ✅ Concurrent request handling

**Performance Targets:**
- Smart search < 500ms average response time
- Album filtering overhead < 10%
- Linear scaling with result size
- Support for 10+ concurrent requests

### 4. Security Tests (`test-security.sh`)
**Purpose:** Validate security aspects of new features

**Test Cases:**
- ✅ SQL injection prevention
- ✅ UUID validation for albumId
- ✅ Authorization enforcement
- ✅ Invalid token handling
- ✅ Input validation (empty, null, malformed)
- ✅ No sensitive data exposure
- ✅ Error handling without information leakage

**Security Requirements:**
- All user input properly validated
- Album access restricted to owner
- Graceful error handling
- No SQL injection vulnerabilities

### 5. Integration Tests (`test-integration.sh`)
**Purpose:** End-to-end workflow testing

**Test Cases:**
- ✅ Full workflow: Create → Add Assets → Search
- ✅ Cross-feature integration
- ✅ Multiple albums with different content
- ✅ Distance scoring consistency
- ✅ API backward compatibility
- ✅ Edge case handling

**Integration Points:**
- Album management + Smart search
- Distance scoring + Album filtering
- Pagination + All features
- Error handling across features

## Manual Verification Checklist

### UI Testing (Manual)
- [ ] Upload photos through web interface
- [ ] Create albums and add photos
- [ ] Verify search works in web UI
- [ ] Check that API changes don't break UI

### Cross-User Testing (Manual)
- [ ] Create second user account
- [ ] Verify users can't search other users' albums
- [ ] Test shared album functionality
- [ ] Confirm proper permission enforcement

### Production Readiness
- [ ] All automated tests passing
- [ ] Performance metrics acceptable
- [ ] Security vulnerabilities addressed
- [ ] API documentation updated
- [ ] Deployment instructions clear

## Test Reports

Test results are automatically generated in:
```
/private/tmp/immich-test/test/reports/
├── test_report_TIMESTAMP.md    # Summary report
└── logs_TIMESTAMP/              # Detailed logs
    ├── distance_scoring.log
    ├── album_filtering.log
    ├── performance.log
    ├── security.log
    └── integration.log
```

## Success Criteria

The feature is considered ready for production when:

1. **Functionality:** All test suites pass (0 failures)
2. **Performance:** Response times within acceptable limits
3. **Security:** No vulnerabilities detected
4. **Integration:** Works seamlessly with existing features
5. **Backward Compatibility:** No breaking changes to API

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Re-run `get-token.sh` to refresh token
   - Verify user credentials are correct

2. **No Search Results**
   - Ensure photos are uploaded and processed
   - Wait for ML service to generate embeddings
   - Check ML service logs

3. **Tests Failing**
   - Check individual log files for details
   - Verify Immich services are running
   - Ensure database migrations completed

### Debug Commands

```bash
# Check API health
curl http://localhost:3003/api/server/version

# View container logs
docker logs immich_server
docker logs immich_machine_learning

# Check database
docker exec -it immich_postgres psql -U immich -c "SELECT COUNT(*) FROM assets;"
```

## Conclusion

This comprehensive test plan ensures that the smart search enhancements are:
- Functionally correct
- Performant at scale
- Secure against attacks
- Properly integrated
- Ready for production deployment

Run the full test suite before any deployment to production.