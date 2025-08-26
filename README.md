# Immich Smart Search Patches

Enhanced smart search capabilities for [Immich](https://github.com/immich-app/immich) with distance/similarity scoring and album filtering.

## 🚀 Features

### 1. Distance & Similarity Scoring
Adds distance and similarity scores to smart search results, enabling:
- **Distance field**: Cosine distance from query (lower = better match)
- **Similarity field**: Normalized similarity score (0-1, higher = better)
- Proper result ranking by relevance
- Preserved scores through pagination

### 2. Album-based Search Filtering
Filter smart search results to specific albums:
- **albumId parameter**: Restrict search to a single album
- UUID validation for security
- Maintains distance/similarity scoring within filtered results
- Returns empty results for non-existent albums

## 📦 What's Included

```
├── patches/                    # Patch files to apply to Immich
│   └── add-smartsearch-score-and-album.diff
├── tests/                      # Comprehensive test suite
│   ├── test-distance-scoring.sh
│   ├── test-album-filtering.sh
│   ├── test-performance.sh
│   ├── test-security.sh
│   ├── test-integration.sh
│   └── run-all-tests.sh
├── docker/                     # Docker configurations
│   └── docker-compose.test.yml
└── .github/workflows/          # CI/CD automation
    ├── track-upstream.yml
    └── build-and-push.yml
```

## 🔧 Installation

### Option 1: Apply Patches to Your Immich Fork

1. Clone Immich and this repository:
```bash
git clone https://github.com/immich-app/immich.git
git clone https://github.com/YOUR_USERNAME/immich-smart-search-patches.git
```

2. Apply the patches:
```bash
cd immich
git apply ../immich-smart-search-patches/patches/add-smartsearch-score-and-album.diff
```

3. Build the server:
```bash
cd server
npm install
npm run build
```

### Option 2: Use Pre-built Docker Image

```bash
# Build with patches applied
docker build -t immich-server:with-patches -f server/Dockerfile .

# Or use docker-compose
docker-compose -f docker/docker-compose.test.yml up
```

## 🧪 Testing

### Run All Tests
```bash
cd tests
./get-token.sh  # Get API token
./run-all-tests.sh
```

### Run Specific Tests
```bash
./test-distance-scoring.sh   # Test distance/similarity fields
./test-album-filtering.sh    # Test album filtering
./test-performance.sh         # Performance benchmarks
./test-security.sh           # Security validation
./test-integration.sh        # End-to-end testing
```

## 📊 API Usage Examples

### Smart Search with Distance Scoring
```bash
curl -X POST "http://localhost:3003/api/search/smart" \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "sunset beach",
    "size": 10
  }'
```

**Response includes:**
```json
{
  "assets": {
    "items": [
      {
        "id": "...",
        "originalFileName": "sunset.jpg",
        "distance": 0.7234,
        "similarity": 0.2766
        // ... other fields
      }
    ]
  }
}
```

### Search Within Specific Album
```bash
curl -X POST "http://localhost:3003/api/search/smart" \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "nature",
    "albumId": "album-uuid-here",
    "size": 10
  }'
```

## 🔄 GitHub Actions Automation

The repository includes workflows for:
- **Tracking upstream Immich releases** (hourly checks)
- **Automatic patch application** to new releases
- **Docker image building and publishing** to GHCR

## 📈 Test Results

All patches have been thoroughly tested:
- ✅ Distance/similarity scoring working correctly
- ✅ Album filtering functioning as expected
- ✅ Input validation and security measures in place
- ✅ Performance impact minimal
- ✅ Backward compatibility maintained

See [TEST_RESULTS_SUMMARY.md](tests/TEST_RESULTS_SUMMARY.md) for detailed results.

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📝 Technical Details

### Distance Calculation
- Uses pgvector's cosine distance operator (`<=>`)
- Implemented in `search.repository.ts` using `getRawAndEntities()`
- Preserves custom fields through proper TypeORM handling

### Album Filtering
- Joins on `albums_assets_assets` table
- Validates UUID format for security
- Integrated into `searchAssetBuilder` function

## 🔍 Compatibility

- **Immich Version**: v1.122.3+
- **Database**: PostgreSQL with pgvector extension
- **Node.js**: 22.11.0+
- **Docker**: 20.10+

## 📄 License

This project follows Immich's licensing terms. See Immich's [LICENSE](https://github.com/immich-app/immich/blob/main/LICENSE) for details.

## 🙏 Acknowledgments

- [Immich](https://github.com/immich-app/immich) - The amazing self-hosted photo management solution
- Built with patches to enhance search capabilities while maintaining compatibility

## 📞 Support

For issues or questions:
- Open an issue in this repository
- Check the [test documentation](tests/TEST_PLAN.md)
- Review the [API test results](tests/api_test_results.md)

---

**Note**: These patches are unofficial enhancements. Always test thoroughly before deploying to production.