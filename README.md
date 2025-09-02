# Immich Smart Search Patches

Enhanced smart search capabilities for [Immich](https://github.com/immich-app/immich) with distance/similarity scoring and album filtering.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/menkveldj/immich-smart-search-patches.git
cd immich-smart-search-patches

# Run automated end-to-end test with pre-built Docker image
./scripts/end-to-end-test.sh ghcr.io/menkveldj/immich-server-patched:v1.122.3
```

## 🚀 Features

### Distance & Similarity Scoring for Smart Search
Adds distance and similarity scores to smart search results, enabling:
- **Distance field**: Cosine distance from query (lower = better match)
- **Similarity field**: Normalized similarity score (0-1, higher = better)
- Proper result ranking by relevance
- Preserved scores through pagination

**Note**: Starting from v1.140.1, Immich natively supports album filtering via the `albumIds` parameter in smart search, so our patch now only adds the distance/similarity scoring functionality.

## 📦 What's Included

```
├── patches/                    # Patch files to apply to Immich
│   └── add-smartsearch-score-and-album.diff
├── scripts/                    # Automation scripts
│   ├── end-to-end-test.sh     # Automated test script
│   └── test-docker-image.sh   # Docker image verification
├── test-images/                # Pre-created test images
│   ├── ocean_1.jpg
│   ├── ocean_2.jpg
│   ├── ocean_3.jpg
│   ├── forest_1.jpg
│   └── forest_2.jpg
├── docker-compose.local-test.yml  # Test environment config
└── .github/workflows/          # CI/CD automation
    ├── check-and-build.yml     # Daily build automation
    └── manual-build.yml        # Manual build trigger
```

## 🔧 Installation

### Option 1: Apply Patches to Your Immich Fork

1. Clone Immich and this repository:
```bash
git clone https://github.com/immich-app/immich.git
git clone https://github.com/menkveldj/immich-smart-search-patches.git
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

### Quick End-to-End Test
Run a complete automated test of the patched Docker image:

```bash
# Prerequisites: Docker must be running

# Test the latest image (default)
./scripts/end-to-end-test.sh

# Test a specific image version
./scripts/end-to-end-test.sh ghcr.io/menkveldj/immich-server-patched:v1.122.3

# Test a local Docker image
./scripts/end-to-end-test.sh immich-server:local-build
```

#### What the test does:
1. **Environment Setup**: Starts a complete Docker stack (server, database, Redis, ML service)
2. **Authentication**: Creates admin user and API key automatically
3. **Test Data**: Uploads 5 pre-created test images (3 ocean, 2 forest) from `test-images/`
4. **Smart Search Tests**: Verifies distance/similarity fields are present and correctly calculated
5. **Album Filtering**: Tests album-based search filtering functionality
6. **Cleanup**: Automatically removes all containers and volumes after testing

#### Test Output:
The script provides color-coded results:
- 🟢 Green checkmarks (✓) for passed tests
- 🔴 Red X marks (✗) for failed tests
- Summary report at the end with total pass/fail counts

#### Manual Docker Testing:
If you want to run the Docker environment manually:
```bash
# Start the test environment
docker-compose -f docker-compose.local-test.yml up -d

# Check logs
docker logs -f immich-patched-server

# Stop and cleanup
docker-compose -f docker-compose.local-test.yml down -v
```

### Verify Docker Image Has Patches
Quickly verify that a Docker image has the patches applied:
```bash
# Check if patches are in the image
./scripts/test-docker-image.sh ghcr.io/menkveldj/immich-server-patched:v1.122.3
```

This will verify:
- Distance field implementation in search repository
- getRawAndEntities usage for custom fields
- Album filtering implementation

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