# Add Distance/Similarity Scoring and Filtering to Smart Search

## What does this PR do?

This PR adds distance/similarity scoring and filtering capabilities to Immich's smart search functionality, addressing long-standing community requests for more control over search relevance.

### Features Added:
1. **Exposes search metrics in API responses**:
   - `distance`: Raw cosine distance from pgvector (0-2 range)
   - `similarity`: Normalized similarity score (1 - distance)

2. **Adds `maxDistance` parameter for filtering**:
   - Allows filtering results by similarity threshold
   - Validates input range (0-2)
   - Works with both CLIP and SigLIP models

3. **Enables URL-based filtering in Web UI**:
   - No visual UI changes required
   - Filter via URL query parameters
   - Example: `/search?query={"query":"sunset","maxDistance":0.95}`

## Why is this needed?

### Addresses Community Requests:
- **Discussion #8377**: Users requesting exposure of similarity scores for filtering search results
- **Issue #5996**: "Smart search shows irrelevant results" - users want control over relevance thresholds

### Current Problems This Solves:
1. **No visibility into search relevance**: Users can't tell how well results match their query
2. **Can't filter out poor matches**: All results returned regardless of relevance
3. **No programmatic access to scores**: External tools can't make decisions based on match quality
4. **Small libraries return everything**: As noted by maintainers, toy libraries effectively return all photos

## How has this been tested?

### Automated Testing:
- ✅ API parameter validation (rejects values > 2)
- ✅ Distance calculation accuracy
- ✅ URL parameter parsing in web UI
- ✅ Backward compatibility (all changes are additive)

### Production Testing:
- ✅ Deployed to production environment with 50,000+ images
- ✅ Tested with both CLIP and SigLIP models
- ✅ Verified different distance ranges for each model type
- ✅ Docker image built and published: `ghcr.io/menkveldj/immich-server-patched:v1.140.1`

### Test Results:
```bash
# CLIP Model (ViT-B-32__openai)
- Distance 0.2-0.4: Excellent matches
- Distance 0.4-0.6: Good matches
- Distance 0.6-0.8: Fair matches

# SigLIP Model (ViT-SO400M-16-SigLIP)
- Distance 0.70-0.85: Excellent matches
- Distance 0.85-0.95: Good matches
- Distance 0.95-1.00: Fair matches
```

## Implementation Details

### Server Changes (`server/src`):
- **DTOs**: Added `distance` and `similarity` fields to `AssetResponseDto`
- **Search DTO**: Added `maxDistance` parameter with validation decorators
- **Repository**: Modified `searchSmart` to calculate and filter by distance
- **TypeScript SDK**: Updated types to include new fields

### Web UI Changes (`web/src`):
- **Search Component**: Modified to parse `maxDistance` from URL query
- **TypeScript Types**: Updated `SmartSearchDto` to include `maxDistance`

## Breaking Changes

**None** - All changes are additive and backward compatible:
- Existing API calls continue to work unchanged
- New fields are optional in responses
- `maxDistance` parameter is optional
- Web UI functionality unchanged unless URL parameters are used

## Usage Examples

### API Usage:
```bash
curl -X POST "http://localhost:2283/api/search/smart" \
  -H "x-api-key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "sunset beach",
    "maxDistance": 0.95,
    "albumIds": ["album-uuid"]
  }'
```

### Web UI URL:
```
http://your-server/search?query={"query":"sunset","maxDistance":0.95,"albumIds":["album-id"]}
```

### Response with new fields:
```json
{
  "assets": {
    "items": [{
      "id": "asset-uuid",
      "distance": 0.3542,      // Added by this PR
      "similarity": 0.6458,    // Added by this PR
      // ... existing fields
    }]
  }
}
```

## Documentation

Comprehensive documentation has been added:
- API usage examples with different models
- Distance value guidelines for CLIP vs SigLIP
- URL encoding helpers for web UI usage
- Real-world examples with actual album IDs

## Related Issues and Discussions

- Closes discussion about exposing similarity scores (#8377)
- Addresses "Smart search shows irrelevant results" (#5996)
- Provides practical solution to threshold sensitivity concerns raised by maintainers

## Why This Approach?

### Acknowledges Maintainer Concerns:
The maintainers correctly noted that threshold sensitivity makes a one-size-fits-all cutoff impossible. This PR addresses that by:
1. **Not forcing a default cutoff** - it's entirely optional
2. **Exposing the raw data** - users can experiment and find what works for their library
3. **Supporting different models** - documentation covers both CLIP and SigLIP ranges

### Minimal UI Impact:
- No complex UI sliders or controls to maintain
- URL-based approach allows power users to experiment
- Leaves room for future UI enhancements if desired

### Developer Friendly:
- API-first approach enables external tools and integrations
- Programmatic access to similarity scores for automation
- Clear documentation with real examples

## Checklist

- [x] Code follows project style guidelines
- [x] All tests pass
- [x] Documentation updated
- [x] Backward compatible
- [x] Production tested
- [x] Related issues referenced

## Screenshots/Recordings

Not applicable - changes are API/backend focused with no visual UI changes.

## Additional Notes

This implementation has been running in production successfully, processing searches across 50,000+ images with both CLIP and SigLIP models. The distance filtering significantly improves search relevance, especially for larger libraries where the default behavior returns too many irrelevant results.

The approach taken here provides the flexibility requested by the community while maintaining the simplicity of the existing UI. Power users and developers can leverage the new capabilities immediately, while casual users experience no change in behavior.