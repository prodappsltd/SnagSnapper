# Snag Sync & Cost Analysis

**Version:** 1.0.0
**Last Updated:** 2026-06-09
**Status:** Planning

---

## Overview

This document covers the cost implications and optimization strategies for syncing shared sites and snags, including image downloads from Firebase Storage.

---

## Firestore Read Costs

### Pricing
- **Reads:** $0.036 per 100,000 reads
- **Writes:** $0.108 per 100,000 writes
- **Deletes:** $0.012 per 100,000 deletes

### Current "Check & Download" Flow

```
User taps "Check & Download"
├── 1 read: shared_access/{emailHash} document
├── N reads: site documents (N = number of shared sites)
├── N queries: snag collections (1 query per site)
└── M reads: snag documents (M = total snags across all sites)
```

**Example: 2 shared sites with 50 snags each**
| Item | Reads |
|------|-------|
| shared_access | 1 |
| Sites | 2 |
| Snag queries | 2 |
| Snag documents | 100 |
| **Total** | **105** |

Cost: 105 reads = $0.00004 (~negligible for single sync)

---

## First Sync vs Subsequent Syncs

### First Sync (Unavoidable)

First time syncing a shared site requires reading ALL data:
- Must discover what snags exist
- Must download all snag metadata
- Must download all images

**Cost:** ~100 reads per 100 snags (unavoidable)

### Subsequent Syncs (Optimizable)

Use `updatedAt` timestamp filtering:

```dart
// Store last sync time locally
final lastSync = prefs.getDateTime('site_${siteId}_lastSync');

// Query only snags changed since last sync
final snagsQuery = await _firestore
    .collection('Profile').doc(ownerUID)
    .collection('Sites').doc(siteId)
    .collection('Snags')
    .where('updatedAt', isGreaterThan: lastSync)
    .get();

// Update last sync time
prefs.setDateTime('site_${siteId}_lastSync', DateTime.now());
```

**Subsequent sync cost:**
| Scenario | Reads |
|----------|-------|
| Nothing changed | 2 (shared_access + site) |
| 3 snags updated | 5 |
| 10 new snags added | 12 |
| All 100 snags changed | 102 (rare) |

---

## Image Download Strategy

### Problem

Firebase Storage with `firestore.get()` in rules = 1 Firestore read per image download.
100 snags × 6 images = 600 Firestore reads just for rule verification.

### Solution: Batch Signed URLs via Cloud Function

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Client downloads snag metadata (knows which images exist)│
│ 2. Client checks local cache (skip existing images)         │
│ 3. Client calls CF with list of needed image paths          │
│ 4. CF verifies access (1 Firestore read - shared_access)    │
│ 5. CF generates signed URLs (valid 7 days)                  │
│ 6. Client downloads images using URLs (no rule verification)│
└─────────────────────────────────────────────────────────────┘
```

**Cost:**
| Item | Count |
|------|-------|
| CF invocation | 1 |
| Firestore read (in CF) | 1 |
| Storage downloads | Only new images |

### Image Caching Logic

```dart
for (final snag in downloadedSnags) {
  for (final slot in snag.images) {
    if (!slot.hasImage) continue;

    final localPath = getLocalImagePath(snag.id, slot.index);

    // Skip if already cached locally
    if (File(localPath).existsSync()) {
      continue;
    }

    imagesToDownload.add(ImageRequest(
      snagId: snag.id,
      slot: slot.index,
      firebasePath: slot.firebasePath,
    ));
  }
}

// Batch request for all needed images
if (imagesToDownload.isNotEmpty) {
  final urls = await cloudFunction.getSignedUrls(imagesToDownload);
  await downloadAndCacheImages(urls);
}
```

### Signed URL Validity

| Duration | Pros | Cons |
|----------|------|------|
| 1 hour | More secure | More CF calls |
| 24 hours | Balanced | - |
| 7 days | Fewer CF calls | URLs work longer if leaked |

**Recommendation:** 7 days - URLs are for specific image paths (unguessable), require prior authentication, and are single-use in practice (downloaded and cached).

---

## Cost Summary by Scenario

### Scenario 1: First Sync (2 sites, 100 snags total, 300 images)

| Operation | Count | Cost |
|-----------|-------|------|
| Firestore reads | ~105 | $0.00004 |
| CF invocation | 1 | $0.0000004 |
| CF Firestore read | 1 | $0.00000036 |
| Storage downloads | 300 | $0.000015 |
| Bandwidth (300 × 500KB) | 150MB | $0.018 |
| **Total** | | **~$0.02** |

### Scenario 2: Subsequent Sync (nothing changed)

| Operation | Count | Cost |
|-----------|-------|------|
| Firestore reads | 2-4 | $0.0000014 |
| CF invocation | 0 | $0 |
| Storage downloads | 0 | $0 |
| **Total** | | **~$0.000001** |

### Scenario 3: Subsequent Sync (5 snags changed, 10 new images)

| Operation | Count | Cost |
|-----------|-------|------|
| Firestore reads | 7-10 | $0.0000036 |
| CF invocation | 1 | $0.0000004 |
| Storage downloads | 10 | $0.0000005 |
| Bandwidth (10 × 500KB) | 5MB | $0.0006 |
| **Total** | | **~$0.001** |

---

## Optimization Checklist

### Must Have
- [ ] `updatedAt` field on all snag documents
- [ ] Local `lastSyncTime` tracking per site
- [ ] Query filter: `where('updatedAt', '>', lastSync)`
- [ ] Local image cache check before download
- [ ] Batch signed URL Cloud Function

### Nice to Have
- [ ] Firestore index on `updatedAt` for snags collection
- [ ] Compress images before upload (reduce bandwidth)
- [ ] Thumbnail generation (show quickly, full image on demand)
- [ ] Background sync (don't block UI)

---

## Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Snag metadata sync | ✅ Done | SharedSiteService |
| `updatedAt` filtering | ❌ TODO | Reduces subsequent sync reads |
| Image download | ❌ TODO | Need CF for signed URLs |
| Local image caching | ❌ TODO | Check file exists before download |
| Signed URL CF | ❌ TODO | `getSignedImageUrls` function |

---

## Cloud Function: getSignedImageUrls

### Request
```javascript
{
  images: [
    { ownerUID: "abc", siteId: "123", snagId: "456", slot: 0 },
    { ownerUID: "abc", siteId: "123", snagId: "789", slot: 2 },
  ]
}
```

### Response
```javascript
{
  urls: [
    { path: "Profile/abc/Sites/123/Snags/456/0.jpg", url: "https://storage..." },
    { path: "Profile/abc/Sites/123/Snags/789/2.jpg", url: "https://storage..." },
  ],
  expiresAt: "2026-06-16T00:00:00Z"
}
```

### Implementation
```javascript
exports.getSignedImageUrls = functions.https.onCall(async (data, context) => {
  // 1. Verify authenticated
  if (!context.auth) throw new Error('Unauthenticated');

  const userEmail = context.auth.token.email.toLowerCase();
  const emailHash = hashEmail(userEmail);

  // 2. Get user's shared_access document (1 read)
  const accessDoc = await db.collection('shared_access').doc(emailHash).get();
  const allowedSites = accessDoc.data()?.sites || {};

  // 3. Verify access to each requested site
  const urls = [];
  for (const img of data.images) {
    const { ownerUID, siteId, snagId, slot } = img;

    // Check: is user owner OR in shared_access?
    if (context.auth.uid !== ownerUID && !allowedSites[siteId]) {
      continue; // Skip unauthorized
    }

    // 4. Generate signed URL
    const path = `Profile/${ownerUID}/Sites/${siteId}/Snags/${snagId}/${slot}.jpg`;
    const [url] = await storage.bucket().file(path).getSignedUrl({
      action: 'read',
      expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
    });

    urls.push({ path, url });
  }

  return { urls, expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) };
});
```

---

## Document History

| Date | Version | Change |
|------|---------|--------|
| 2026-06-09 | 1.0.0 | Initial document |

---

*This document tracks cost optimization strategies for SnagSnapper sync operations.*
