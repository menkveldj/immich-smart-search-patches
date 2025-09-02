# Immich Smart Search Patches

Enhanced smart search capabilities for [Immich](https://github.com/immich-app/immich) with distance/similarity scoring and filtering.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/menkveldj/immich-smart-search-patches.git
cd immich-smart-search-patches

# Run automated test with pre-built Docker image
./test/test-patch-features.sh
```

### Use Pre-built Docker Image

```yaml
# docker-compose.yml
services:
  immich-server:
    image: ghcr.io/menkveldj/immich-server-patched:v1.140.1
    # ... rest of your configuration
```

## 🚀 Features

### Enhanced Smart Search with Distance Scoring
Our patch adds powerful distance-based filtering and scoring to Immich's smart search:

- **Distance field**: Cosine distance from query (0-2 range, lower = better match)
- **Similarity field**: Normalized similarity score (1 - distance)
- **MaxDistance filtering**: Filter results by similarity threshold
- **Proper result ranking**: Results ordered by relevance

**Note**: Starting from v1.140.1, Immich natively supports album filtering via the `albumIds` parameter. Our patch adds the distance/similarity scoring and filtering capabilities.

## 📚 API Documentation

### Smart Search Endpoint

**Endpoint:** `POST /api/search/smart`

**Headers:**
- `Authorization: Bearer <token>` or `x-api-key: <api-key>`
- `Content-Type: application/json`

### Request Parameters

| Parameter | Type | Description | Range/Values |
|-----------|------|-------------|--------------|
| `query` | string | **Required**. Search query text | Any text |
| `maxDistance` | number | Optional. Maximum distance threshold for filtering | 0.0 - 2.0 |
| `albumIds` | string[] | Optional. Filter by specific albums (native in v1.140.1) | Array of UUIDs |
| `size` | number | Optional. Number of results to return | 1-1000 (default: 100) |
| `page` | number | Optional. Page number for pagination | 1+ (default: 1) |

### Understanding Distance Values

The `maxDistance` parameter uses **cosine distance** to measure similarity between image embeddings:

| Distance Range | Similarity | Description | Use Case |
|---------------|------------|-------------|----------|
| **0.0 - 0.2** | 100% - 90% | Nearly identical | Find duplicates or near-duplicates |
| **0.2 - 0.4** | 90% - 80% | Very similar | Same scene, minor variations |
| **0.4 - 0.6** | 80% - 70% | Similar | Same subject/category |
| **0.6 - 0.8** | 70% - 60% | Moderately similar | Related content |
| **0.8 - 1.0** | 60% - 50% | Somewhat related | Loose thematic connection |
| **1.0** | 50% | Unrelated | Orthogonal vectors |
| **1.0 - 1.5** | 50% - 25% | Different | Dissimilar content |
| **1.5 - 2.0** | 25% - 0% | Opposite | Completely different |

### Recommended MaxDistance Values

| Use Case | Recommended `maxDistance` | Description |
|----------|---------------------------|-------------|
| **Exact Duplicates** | 0.1 | Find identical or nearly identical images |
| **Near Duplicates** | 0.2 | Find very similar shots (burst photos, etc.) |
| **Similar Photos** | 0.5 | Find photos of same subject/scene |
| **Related Content** | 0.8 | Broader search including related themes |
| **Loose Matching** | 1.2 | Include tangentially related content |
| **All Results** | _omit parameter_ | No filtering, return all results |

### Response Structure

```json
{
  "assets": {
    "total": 150,
    "count": 10,
    "items": [
      {
        "id": "asset-uuid",
        "deviceAssetId": "device-asset-id",
        "ownerId": "user-uuid",
        "deviceId": "device-id",
        "originalFileName": "sunset_beach.jpg",
        "fileCreatedAt": "2024-01-15T18:30:00Z",
        "fileModifiedAt": "2024-01-15T18:30:00Z",
        "type": "IMAGE",
        
        // Added by our patch:
        "distance": 0.3542,      // Cosine distance (0-2)
        "similarity": 0.6458,    // Similarity score (1 - distance)
        
        // ... other standard Immich fields
      }
    ],
    "facets": [],
    "nextPage": null
  }
}
```

## 📖 API Usage Examples

### 1. Basic Smart Search with Distance Scoring

```bash
curl -X POST "http://localhost:2283/api/search/smart" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "sunset beach"
  }'
```

### 2. Search with Distance Filtering (Find Very Similar)

```bash
curl -X POST "http://localhost:2283/api/search/smart" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mountain landscape",
    "maxDistance": 0.5,
    "size": 20
  }'
```

### 3. Find Near-Duplicates

```bash
curl -X POST "http://localhost:2283/api/search/smart" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "family portrait outdoor",
    "maxDistance": 0.2
  }'
```

### 4. Album-Specific Search (Native in v1.140.1)

```bash
curl -X POST "http://localhost:2283/api/search/smart" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "sunset",
    "albumIds": ["album-uuid-1", "album-uuid-2"],
    "maxDistance": 0.8
  }'
```

### 5. Broader Search with Loose Matching

```bash
curl -X POST "http://localhost:2283/api/search/smart" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "nature",
    "maxDistance": 1.2,
    "size": 50,
    "page": 1
  }'
```

## 🔧 Installation

### Option 1: Use Pre-built Docker Image (Recommended)

```yaml
# docker-compose.yml
version: "3.8"

services:
  immich-server:
    container_name: immich_server
    image: ghcr.io/menkveldj/immich-server-patched:v1.140.1
    # ... your configuration
    
  immich-machine-learning:
    container_name: immich_ml
    image: ghcr.io/immich-app/immich-machine-learning:v1.140.1
    # ... your configuration
    
  database:
    container_name: immich_postgres
    image: tensorchord/pgvecto-rs:pg16-v0.3.0  # Important: Use v0.3.0
    # ... your configuration
```

### Option 2: Apply Patches to Your Immich Fork

1. Clone Immich and this repository:
```bash
git clone https://github.com/immich-app/immich.git
cd immich
git checkout v1.140.1
```

2. Apply the patch:
```bash
git apply ../immich-smart-search-patches/patches/add-smartsearch-distance-v1.140.1.diff
```

3. Build the server:
```bash
cd server
npm install
npm run build
```

## 📦 What's Included

```
├── patches/                    # Patch files for different versions
│   ├── add-smartsearch-distance-v1.140.1.diff  # Latest patch
│   └── add-smartsearch-score-and-album.diff    # Legacy v1.122.3
├── test/                       # Test scripts
│   ├── comprehensive-test-v1.140.sh
│   └── test-patch-features.sh
├── scripts/                    # Automation scripts
│   └── end-to-end-test.sh
└── .github/workflows/          # CI/CD automation
```

## 🧪 Testing

### Quick Validation Test
```bash
# Test that the patch is working correctly
./test/test-patch-features.sh http://localhost:2283

# Run comprehensive tests (requires ML service)
./test/comprehensive-test-v1.140.sh http://localhost:2283
```

## 📊 Example: Understanding Distance in Practice

Here's what different distance values mean for a search query "beach sunset":

| Distance | Similarity | What You'll Find |
|----------|------------|------------------|
| 0.15 | 85% | Other beach sunsets, same location/time |
| 0.35 | 65% | Beach scenes, golden hour photos |
| 0.55 | 45% | Coastal images, sunsets in general |
| 0.75 | 25% | Outdoor scenes, landscapes |
| 0.95 | 5% | Some outdoor elements |
| 1.2 | -20% | Unrelated but not opposite |
| 1.8 | -80% | Indoor scenes, night photos |

## 🔍 Compatibility

- **Immich Version**: v1.140.1
- **Database**: PostgreSQL with pgvecto-rs v0.3.0 (not v0.4.0)
- **Node.js**: 22.11.0+
- **Docker**: 20.10+

## ⚠️ Important Notes

1. **Distance vs Similarity**: The API returns both fields. Distance is the raw cosine distance (0-2), while similarity is normalized (1 - distance).

2. **Performance**: Using very high `maxDistance` values (>1.5) may return many loosely related results. For best performance, use lower values.

3. **ML Service Required**: The smart search features require the machine learning service to be running and properly configured.

4. **Database Compatibility**: Use pgvecto-rs v0.3.0. Version 0.4.0 is not yet supported by Immich.

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📈 Performance Considerations

- **Without maxDistance**: Returns all results ordered by distance
- **With maxDistance**: Pre-filters results at database level (more efficient)
- **Recommended batch size**: 20-50 results for optimal performance
- **Distance calculation**: Happens at query time using pgvector's optimized operators

## 📄 License

This project follows Immich's licensing terms. See Immich's [LICENSE](https://github.com/immich-app/immich/blob/main/LICENSE) for details.

## 🙏 Acknowledgments

- [Immich](https://github.com/immich-app/immich) - The amazing self-hosted photo management solution
- Built with patches to enhance search capabilities while maintaining compatibility

## 📞 Support

For issues or questions:
- Open an issue in this repository
- Review the test scripts for implementation examples
- Check Immich's documentation for native features

---

**Note**: These patches are unofficial enhancements. Always test thoroughly in a staging environment before deploying to production.