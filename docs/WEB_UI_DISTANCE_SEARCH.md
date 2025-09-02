# Web UI Distance Search via URL

This patch enables distance-based filtering in the Immich web UI through URL query parameters.

## Prerequisites

1. Apply the server patch: `add-smartsearch-distance-v1.140.1.diff`
2. Apply the web UI patch: `add-web-ui-maxdistance-v1.140.1.diff`

## How to Use

### URL Format

You can now pass `maxDistance` in the URL query parameter. The query parameter must be JSON-encoded.

### Examples

#### Basic Search (No Distance Filter)
```
http://192.168.8.53:2283/search?query={"query":"swimsuit"}
```
URL-encoded:
```
http://192.168.8.53:2283/search?query=%7B%22query%22%3A%22swimsuit%22%7D
```

#### Search with Distance Filter (SigLIP Model)
For excellent matches only (distance ≤ 0.87):
```
http://192.168.8.53:2283/search?query={"query":"swimsuit","maxDistance":0.87}
```
URL-encoded:
```
http://192.168.8.53:2283/search?query=%7B%22query%22%3A%22swimsuit%22%2C%22maxDistance%22%3A0.87%7D
```

For good matches (distance ≤ 0.95):
```
http://192.168.8.53:2283/search?query={"query":"swimsuit","maxDistance":0.95}
```
URL-encoded:
```
http://192.168.8.53:2283/search?query=%7B%22query%22%3A%22swimsuit%22%2C%22maxDistance%22%3A0.95%7D
```

#### Search with Distance Filter (CLIP Model)
For excellent matches only (distance ≤ 0.4):
```
http://192.168.8.53:2283/search?query={"query":"beach","maxDistance":0.4}
```
URL-encoded:
```
http://192.168.8.53:2283/search?query=%7B%22query%22%3A%22beach%22%2C%22maxDistance%22%3A0.4%7D
```

### Combined with Other Filters

You can combine maxDistance with other search parameters:

#### Search in specific albums with distance filter:
```
http://192.168.8.53:2283/search?query={"query":"gym","maxDistance":0.95,"albumIds":["album-uuid-here"]}
```

#### Search with date range and distance filter:
```
http://192.168.8.53:2283/search?query={"query":"sunset","maxDistance":0.9,"takenAfter":"2024-01-01","takenBefore":"2024-12-31"}
```

## URL Encoding Helper

To properly encode your search query for the URL:

### JavaScript (Browser Console)
```javascript
const query = {
  query: "swimsuit",
  maxDistance: 0.87
};
const encoded = encodeURIComponent(JSON.stringify(query));
console.log(`http://192.168.8.53:2283/search?query=${encoded}`);
```

### Python
```python
import json
import urllib.parse

query = {
    "query": "swimsuit",
    "maxDistance": 0.87
}
encoded = urllib.parse.quote(json.dumps(query))
print(f"http://192.168.8.53:2283/search?query={encoded}")
```

### Bash
```bash
QUERY='{"query":"swimsuit","maxDistance":0.87}'
ENCODED=$(echo -n "$QUERY" | jq -sRr @uri)
echo "http://192.168.8.53:2283/search?query=$ENCODED"
```

## Distance Value Guidelines

### For SigLIP Models (ViT-SO400M-16-SigLIP)
- **0.70-0.85**: Excellent matches (highly relevant)
- **0.85-0.90**: Great matches (strong relevance)
- **0.90-0.95**: Good matches (relevant)
- **0.95-1.00**: Fair matches (loosely related)

### For CLIP Models (ViT-B-32__openai)
- **0.2-0.4**: Excellent matches (highly relevant)
- **0.4-0.6**: Great matches (strong relevance)
- **0.6-0.8**: Good matches (relevant)
- **0.8-1.0**: Fair matches (loosely related)

## Technical Notes

1. The patch modifies:
   - TypeScript SDK types to include `maxDistance`
   - Web UI search page to parse `maxDistance` from URL
   - Search query parsing to handle the new parameter

2. The maxDistance parameter is:
   - Optional (omit for no filtering)
   - Range: 0.0 to 2.0
   - Lower values = stricter filtering

3. The web UI will:
   - Parse the JSON query from URL
   - Extract maxDistance if present
   - Pass it to the smart search API
   - Display filtered results

## Troubleshooting

### "Bad Request" Error
- Ensure maxDistance is between 0 and 2
- Check JSON syntax is valid
- Verify URL encoding is correct

### No Results
- Try increasing maxDistance value
- SigLIP models need higher values (0.85-0.95)
- CLIP models use lower values (0.4-0.8)

### Results Not Filtered
- Ensure server patch is applied
- Verify smart search is enabled
- Check that you're using the smart search endpoint