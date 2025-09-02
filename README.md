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
- **MaxDistance filtering**: Filter results by similarity threshold via API or URL
- **Web UI URL Support**: Filter directly via URL query parameters
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

The `maxDistance` parameter uses **cosine distance** to measure similarity between image embeddings. 

> ⚠️ **Important**: Distance ranges vary significantly based on the ML model used. Immich supports both CLIP and SigLIP models, which have different similarity scales.

#### For CLIP Models (ViT-B-32__openai, etc.)

| Distance Range | Similarity | Match Quality | Description |
|---------------|------------|---------------|-------------|
| **0.0 - 0.2** | 100% - 80% | 🏆 Perfect | Nearly identical images |
| **0.2 - 0.4** | 80% - 60% | ⭐ Excellent | Very similar, same scene |
| **0.4 - 0.6** | 60% - 40% | ✅ Great | Same subject/category |
| **0.6 - 0.8** | 40% - 20% | 👍 Good | Related content |
| **0.8 - 1.0** | 20% - 0% | 🔍 Fair | Loose connection |
| **1.0 - 2.0** | 0% - -100% | ❌ Poor | Unrelated to opposite |

#### For SigLIP Models (ViT-SO400M-16-SigLIP, etc.)

| Distance Range | Similarity | Match Quality | Description |
|---------------|------------|---------------|-------------|
| **0.0 - 0.70** | 100% - 30% | 🏆 Perfect | Identical/near-duplicate |
| **0.70 - 0.85** | 30% - 15% | ⭐ Excellent | Highly relevant match |
| **0.85 - 0.90** | 15% - 10% | ✅ Great | Strong semantic match |
| **0.90 - 0.95** | 10% - 5% | 👍 Good | Relevant match |
| **0.95 - 1.00** | 5% - 0% | 🔍 Fair | Loosely related |
| **1.00 - 1.50** | 0% - -50% | ⚠️ Poor | Weak connection |
| **1.50 - 2.00** | -50% - -100% | ❌ Unrelated | No connection |

### Recommended MaxDistance Values

#### CLIP Model Recommendations

| Use Case | Recommended `maxDistance` | Expected Results |
|----------|---------------------------|------------------|
| **Find Duplicates** | 0.2 | Only identical/near-identical |
| **High Precision** | 0.4 | Very similar images only |
| **Balanced Search** | 0.6 | Good relevant results |
| **Broad Discovery** | 0.8 | Include related content |
| **Everything** | 1.2 | All possible matches |

#### SigLIP Model Recommendations

| Use Case | Recommended `maxDistance` | Expected Results |
|----------|---------------------------|------------------|
| **Find Duplicates** | 0.70 | Only identical/near-identical |
| **High Precision** | 0.85 | Highly relevant matches only |
| **Balanced Search** | 0.95 | Good relevant results |
| **Broad Discovery** | 1.05 | Include loosely related |
| **Everything** | 1.20 | All possible matches |

### How to Check Your Model

```bash
curl -X GET "http://localhost:2283/api/system-config" \
  -H "x-api-key: YOUR_API_KEY" | jq '.machineLearning.clip.modelName'
```

- If it contains "CLIP" → Use CLIP ranges
- If it contains "SigLIP" → Use SigLIP ranges (expect higher distances for good matches)

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

## 🌐 Web UI URL-Based Search

### Direct URL Search with Distance Filtering

The patch enables distance filtering directly through the web UI using URL query parameters. No UI modifications needed - just use specially formatted URLs.

#### Basic Search URL
```
http://your-server/search?query={"query":"sunset"}
```

#### Search with Distance Filter
```
http://your-server/search?query={"query":"sunset","maxDistance":0.9}
```

#### URL-Encoded Examples

For CLIP models (use lower distance values):
```
http://your-server/search?query=%7B%22query%22%3A%22beach%22%2C%22maxDistance%22%3A0.5%7D
```

For SigLIP models (use higher distance values):
```
http://your-server/search?query=%7B%22query%22%3A%22beach%22%2C%22maxDistance%22%3A0.95%7D
```

#### Combined with Album Filter
```
http://your-server/search?query={"query":"family","maxDistance":0.9,"albumIds":["album-uuid"]}
```

### URL Encoding Helpers

#### JavaScript (Browser Console)
```javascript
const query = {
  query: "sunset beach",
  maxDistance: 0.9
};
const url = `http://your-server/search?query=${encodeURIComponent(JSON.stringify(query))}`;
console.log(url);
```

#### Python
```python
import json
import urllib.parse

query = {"query": "sunset beach", "maxDistance": 0.9}
encoded = urllib.parse.quote(json.dumps(query))
print(f"http://your-server/search?query={encoded}")
```

#### Bash
```bash
QUERY='{"query":"sunset beach","maxDistance":0.9}'
ENCODED=$(echo -n "$QUERY" | jq -sRr @uri)
echo "http://your-server/search?query=$ENCODED"
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
│   ├── add-smartsearch-distance-v1.140.1.diff      # Server-side distance scoring
│   ├── add-web-ui-maxdistance-v1.140.1.diff       # Web UI URL parameter support
│   └── add-smartsearch-score-and-album.diff       # Legacy v1.122.3
├── test/                       # Test scripts
│   ├── comprehensive-test-v1.140.sh
│   └── test-patch-features.sh
├── scripts/                    # Automation scripts
│   └── end-to-end-test.sh
├── docs/                       # Documentation
│   └── WEB_UI_DISTANCE_SEARCH.md                  # Web UI usage guide
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

## 📊 Real-World Examples: Model Differences

### Example: Searching for "swimsuit"

#### With CLIP Model (ViT-B-32):
| Result | Distance | Quality | What You Get |
|--------|----------|---------|--------------|
| Best match | ~0.3 | ⭐ Excellent | Person in swimsuit at beach |
| Good matches | 0.3-0.5 | ✅ Great | Swimming/beach scenes |
| Fair matches | 0.5-0.7 | 👍 Good | Summer/outdoor activities |

#### With SigLIP Model (ViT-SO400M-16-SigLIP):
| Result | Distance | Quality | What You Get |
|--------|----------|---------|--------------|
| Best match | ~0.87 | ⭐ Excellent | Person in swimsuit (looks bad but it's good!) |
| Good matches | 0.87-0.92 | ✅ Great | Swimming/beach scenes |
| Fair matches | 0.92-0.95 | 👍 Good | Summer/outdoor activities |

> 💡 **Key Insight**: SigLIP consistently returns higher distance values (0.85-0.95) even for excellent matches. This is normal behavior for SigLIP models.

## 🔍 Compatibility

- **Immich Version**: v1.140.1
- **Database**: PostgreSQL with pgvecto-rs v0.3.0 (not v0.4.0)
- **Node.js**: 22.11.0+
- **Docker**: 20.10+

## ⚠️ Important Notes

1. **Model-Specific Behavior**: 
   - **CLIP models**: Expect distances 0.2-0.8 for relevant results
   - **SigLIP models**: Expect distances 0.85-0.95 for relevant results (this is normal!)
   - Always check your model with the system-config API endpoint

2. **Distance vs Similarity**: The API returns both fields. Distance is the raw cosine distance (0-2), while similarity is normalized (1 - distance).

3. **Why SigLIP Shows High Distances**: SigLIP uses sigmoid loss instead of contrastive loss, resulting in a different similarity distribution. A 0.87 distance in SigLIP can indicate an excellent match, while in CLIP it would be poor.

4. **Performance**: 
   - For CLIP: Use maxDistance 0.6-0.8 for balanced results
   - For SigLIP: Use maxDistance 0.95-1.05 for balanced results

5. **ML Service Required**: The smart search features require the machine learning service to be running and properly configured.

6. **Database Compatibility**: Use pgvecto-rs v0.3.0. Version 0.4.0 is not yet supported by Immich.

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