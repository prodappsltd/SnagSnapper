# Snag Sync & Cost Analysis

**Version:** 2.2.0
**Last Updated:** 2026-06-10
**Status:** Approved - Manifest Approach

**Related Documents:**
- [Sharing Architecture](../../00-CORE/SHARING_ARCHITECTURE.md) - Permission levels, data structure, flows
- [Sharing & CF Decisions](../Sites/SHARING_AND_CF_DECISIONS.md) - CF error handling, security model

---

## Overview

This document defines the sync strategy for shared sites and snags using a **manifest-based approach**. The manifest is a lightweight JSON file that tracks all images for a site, enabling efficient sync with minimal Firestore reads.

### Key Benefits

- **Massive cost reduction** - One manifest download vs thousands of Firestore reads
- **Storage tracking** - Know exactly how much each user consumes
- **Quota enforcement** - Block uploads when storage limit reached
- **Offline sync planning** - Compare manifests without network
- **Consistent state** - Version number ensures atomic view of changes

---

## Firebase Pricing Reference

| Operation | Cost per 100,000 |
|-----------|------------------|
| Firestore reads | $0.036 |
| Firestore writes | $0.108 |
| Firestore deletes | $0.012 |
| Storage downloads | $0.12 per GB |
| Cloud Function invocations | $0.40 per million |

---

## Sync Behavior

### Uploads (Automatic)

```
User adds/edits snag with photos
       │
       ▼
Save to local database immediately
       │
       ▼
Background sync uploads to Firebase (fire-and-forget)
       │
       ▼
Cloud Function updates manifest automatically
```

- Works same for owned sites and shared sites
- User never waits for upload
- Already implemented for owned sites

### Downloads (Manual Only)

```
User taps "Check for Updates" or "Sync"
       │
       ▼
Download manifest, compare, fetch new images
```

| Scenario | Trigger |
|----------|---------|
| Shared user syncing shared sites | Manual button tap |
| Owner checking for fix photos | Manual button tap |
| Any download of remote images | Manual button tap |

**No listeners.** Downloads only happen when user explicitly requests.

---

## Architecture: Manifest-Based Sync

### Storage Structure (Unchanged - Nested)

```
Profile/{ownerUID}/
├── storage_manifest.json              ← User-level storage totals
└── Sites/{siteId}/
    ├── site.jpg
    ├── manifest.json                  ← Site-level image index
    └── Snags/{snagId}/
        ├── p0.jpg, p1.jpg ... p5.jpg  ← Problem photos (slots 0-5)
        └── f0.jpg, f1.jpg ... f5.jpg  ← Fix photos (slots 0-5)
```

### Why Nested Structure (Not Flat)

We keep the nested folder structure because:

1. **Fine-grained permissions** - Separate rules for problem vs fix photos
2. **Efficient single-snag operations** - Delete one snag without listing all
3. **Offline capability** - Manifest cached locally for offline planning
4. **Consistent reads** - Manifest version ensures atomic state view

---

## Site Manifest Structure

**Location:** `Profile/{ownerUID}/Sites/{siteId}/manifest.json`

```
{
  version: 42                              // Increments on ANY change
  updatedAt: "2026-06-09T10:30:00Z"

  totalBytes: 245000000                    // 245 MB for this site
  imageCount: 312                          // Total images in site

  images: {
    "snagA_p0": {
      bytes: 450000,
      hash: "abc123def456",
      uploaded: "2026-06-01T08:00:00Z"
    },
    "snagA_p1": {
      bytes: 380000,
      hash: "def456abc123",
      uploaded: "2026-06-01T08:00:00Z"
    },
    "snagA_f0": {
      bytes: 520000,
      hash: "789xyzabc123",
      uploaded: "2026-06-05T14:30:00Z"
    },
    "snagB_p0": {
      bytes: 410000,
      hash: "qrs789tuv012",
      uploaded: "2026-06-08T09:15:00Z"
    }
    // ... more images
  }
}
```

### Image Key Format

```
{snagId}_{type}{slot}

Where:
  snagId = UUID of the snag (e.g., "a1b2c3d4")
  type   = "p" for problem photo, "f" for fix photo
  slot   = 0 to 5

Examples:
  a1b2c3d4_p0  →  Snag a1b2c3d4, problem photo, slot 0
  a1b2c3d4_f2  →  Snag a1b2c3d4, fix photo, slot 2
```

---

## User Storage Manifest Structure

**Location:** `Profile/{ownerUID}/storage_manifest.json`

```
{
  totalBytes: 1250000000                   // 1.25 GB total usage
  siteCount: 5
  snagCount: 487
  imageCount: 2340

  breakdown: {
    "site_abc": { bytes: 245000000, images: 312, snags: 52 },
    "site_def": { bytes: 890000000, images: 1205, snags: 201 },
    "site_ghi": { bytes: 115000000, images: 823, snags: 137 }
  }

  quotaLimit: 5000000000                   // 5 GB (Pro tier)
  quotaUsedPercent: 25

  lastCalculated: "2026-06-09T10:30:00Z"
}
```

### Quota Limits by Tier

| Tier | Storage Limit | Sites | Snags per Site |
|------|---------------|-------|----------------|
| FREE | 1 GB | 1 | 100 |
| PRO | 5 GB | 10 | 200 |
| BUSINESS | 100 GB | Unlimited | 200 |

---

## Tier & Sharing Permissions (TODO - Needs Discussion)

**Current thinking - requires further discussion:**

### FREE Tier

| Capability | Allowed |
|------------|---------|
| Own sites | 1 site max |
| Share own sites | ❌ No |
| Create snags/reports | ✅ Yes (on own site) |
| Be shared with as FIXER | ✅ Yes |
| Be shared with as VIEW | ❌ No (requires paid) |
| Be shared with as CONTRIBUTOR | ❌ No (requires paid) |

### PRO / BUSINESS Tiers

| Capability | PRO | BUSINESS |
|------------|-----|----------|
| Own sites | 10 | Unlimited |
| Share own sites | ✅ Yes | ✅ Yes |
| Be any shared role | ✅ Yes | ✅ Yes |

### Rationale

```
Site Manager (creates sites, assigns work)
  └── Needs: PRO or BUSINESS (pays for value)

Subcontractor/Fixer (fixes assigned snags only)
  └── Needs: FREE is enough
  └── Can only see assigned snags → less bandwidth cost
  └── Upgrade incentive: want VIEW access or own more sites
```

### Open Questions (TODO)

- Should FREE users have a limit on how many sites they can be FIXER on?
- Should limits be based on site count OR data/storage usage?
- What happens if PRO user downgrades to FREE with 5 sites?

---

## Sync Flows (Pseudocode)

### First-Time Sync (New Shared Site)

```
FUNCTION syncSharedSiteFirstTime(ownerUID, siteId)

  // Step 1: Download site manifest (one small file ~60KB)
  manifest = DOWNLOAD "Profile/{ownerUID}/Sites/{siteId}/manifest.json"

  // Step 2: Get list of all images from manifest
  remoteImages = manifest.images.keys()
  // Example: ["snagA_p0", "snagA_p1", "snagB_f0", ...]

  // Step 3: We have nothing locally (first sync)
  localImages = EMPTY SET

  // Step 4: Everything is new - download all
  toDownload = remoteImages

  // Step 5: Request signed URLs in batch (via Cloud Function)
  signedUrls = CALL CloudFunction "getSignedUrls" WITH {
    ownerUID: ownerUID,
    siteId: siteId,
    imageKeys: toDownload
  }

  // Step 6: Download each image (parallel, limit 5 concurrent)
  FOR EACH imageKey IN toDownload (PARALLEL, MAX 5)
    url = signedUrls[imageKey]
    imageData = DOWNLOAD url
    localPath = convertKeyToLocalPath(imageKey)
    SAVE imageData TO localPath
  END FOR

  // Step 7: Save manifest locally for future comparisons
  SAVE manifest TO local storage AS "site_{siteId}_manifest.json"

  RETURN success

END FUNCTION
```

### Incremental Sync (Subsequent Syncs)

```
FUNCTION syncSharedSiteIncremental(ownerUID, siteId)

  // Step 1: Load local manifest (cached from last sync)
  localManifest = LOAD "site_{siteId}_manifest.json" FROM local storage

  // Step 2: Download current remote manifest
  remoteManifest = DOWNLOAD "Profile/{ownerUID}/Sites/{siteId}/manifest.json"

  // Step 3: Quick version check - skip if unchanged
  IF remoteManifest.version == localManifest.version THEN
    LOG "Nothing changed for site {siteId}"
    RETURN "up-to-date"
  END IF

  // Step 4: Compare image lists
  remoteImages = remoteManifest.images.keys()
  localImages = localManifest.images.keys()

  newImages = remoteImages MINUS localImages
  deletedImages = localImages MINUS remoteImages

  // Step 5: Check for UPDATED images (same key, different hash)
  updatedImages = EMPTY LIST
  FOR EACH imageKey IN (remoteImages INTERSECT localImages)
    remoteHash = remoteManifest.images[imageKey].hash
    localHash = localManifest.images[imageKey].hash
    IF remoteHash != localHash THEN
      ADD imageKey TO updatedImages
    END IF
  END FOR

  // Step 6: Download new and updated images
  toDownload = newImages + updatedImages

  IF toDownload IS NOT EMPTY THEN
    signedUrls = CALL CloudFunction "getSignedUrls" WITH {
      ownerUID: ownerUID,
      siteId: siteId,
      imageKeys: toDownload
    }

    FOR EACH imageKey IN toDownload (PARALLEL, MAX 5)
      imageData = DOWNLOAD signedUrls[imageKey]
      localPath = convertKeyToLocalPath(imageKey)
      SAVE imageData TO localPath
    END FOR
  END IF

  // Step 7: Delete local images that were removed remotely
  FOR EACH imageKey IN deletedImages
    localPath = convertKeyToLocalPath(imageKey)
    DELETE FILE AT localPath
  END FOR

  // Step 8: Update local manifest cache
  SAVE remoteManifest TO local storage AS "site_{siteId}_manifest.json"

  RETURN {
    downloaded: LENGTH OF toDownload,
    deleted: LENGTH OF deletedImages
  }

END FUNCTION
```

### Helper: Convert Image Key to Local Path

```
FUNCTION convertKeyToLocalPath(imageKey)

  // Parse: "snagA_p0" → snagId="snagA", type="p", slot="0"
  parts = SPLIT imageKey BY "_"
  snagId = parts[0]
  typeAndSlot = parts[1]           // "p0" or "f2"
  type = typeAndSlot[0]            // "p" or "f"
  slot = typeAndSlot[1]            // "0" to "5"

  // Build local path
  basePath = APP_DOCUMENTS_DIR + "/Sites/{siteId}/Snags/{snagId}/"
  fileName = type + slot + ".jpg"  // "p0.jpg" or "f2.jpg"

  RETURN basePath + fileName

END FUNCTION
```

---

## Cloud Functions

### 1. Update Site Manifest (Triggered on Snag Change)

```
TRIGGER: Firestore document write at
         Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId}

FUNCTION onSnagWritten(event)

  ownerUID = event.params.ownerUID
  siteId = event.params.siteId
  snagId = event.params.snagId

  // Step 1: Load current site manifest (or create new)
  manifestPath = "Profile/{ownerUID}/Sites/{siteId}/manifest.json"

  TRY
    manifest = DOWNLOAD manifestPath FROM Storage
  CATCH FileNotFound
    manifest = {
      version: 0,
      updatedAt: null,
      totalBytes: 0,
      imageCount: 0,
      images: {}
    }
  END TRY

  // Step 2: Handle based on event type
  IF event.type == "DELETE" THEN

    // Remove all images for this snag
    FOR EACH key IN manifest.images.keys()
      IF key STARTS WITH "{snagId}_" THEN
        manifest.totalBytes -= manifest.images[key].bytes
        manifest.imageCount -= 1
        DELETE manifest.images[key]
      END IF
    END FOR

  ELSE  // CREATE or UPDATE

    snagData = event.newData

    // Process problem photos (slots 0-5)
    FOR slot FROM 0 TO 5
      imageKey = "{snagId}_p{slot}"
      imagePath = snagData.imagePaths[slot]

      CALL updateManifestEntry(manifest, imageKey, imagePath, ownerUID, siteId, snagId, "p", slot)
    END FOR

    // Process fix photos (slots 0-5)
    FOR slot FROM 0 TO 5
      imageKey = "{snagId}_f{slot}"
      imagePath = snagData.fixImagePaths[slot]

      CALL updateManifestEntry(manifest, imageKey, imagePath, ownerUID, siteId, snagId, "f", slot)
    END FOR

  END IF

  // Step 3: Update manifest metadata
  manifest.version += 1
  manifest.updatedAt = NOW()

  // Step 4: Save updated manifest to Storage
  UPLOAD manifest AS JSON TO manifestPath

  // Step 5: Trigger user storage manifest update
  CALL updateUserStorageManifest(ownerUID)

END FUNCTION


FUNCTION updateManifestEntry(manifest, imageKey, imagePath, ownerUID, siteId, snagId, type, slot)

  IF imagePath IS NOT EMPTY THEN
    // Image exists - add or update entry

    // Get file metadata from Storage
    storagePath = "Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId}/{type}{slot}.jpg"

    TRY
      fileMetadata = GET METADATA FOR storagePath FROM Storage
      fileSize = fileMetadata.size
      fileHash = fileMetadata.md5Hash
    CATCH FileNotFound
      // Image path in Firestore but file not yet uploaded - skip
      RETURN
    END TRY

    // Update totals
    IF imageKey IN manifest.images THEN
      oldBytes = manifest.images[imageKey].bytes
      manifest.totalBytes -= oldBytes
    ELSE
      manifest.imageCount += 1
    END IF

    manifest.totalBytes += fileSize

    manifest.images[imageKey] = {
      bytes: fileSize,
      hash: fileHash,
      uploaded: NOW()
    }

  ELSE
    // Image removed - delete entry if exists

    IF imageKey IN manifest.images THEN
      manifest.totalBytes -= manifest.images[imageKey].bytes
      manifest.imageCount -= 1
      DELETE manifest.images[imageKey]
    END IF

  END IF

END FUNCTION
```

### 2. Update User Storage Manifest

```
FUNCTION updateUserStorageManifest(ownerUID)

  userManifestPath = "Profile/{ownerUID}/storage_manifest.json"

  // Step 1: List all site manifest files for this user
  siteManifestFiles = LIST FILES MATCHING "Profile/{ownerUID}/Sites/*/manifest.json"

  // Step 2: Aggregate totals
  totalBytes = 0
  totalImages = 0
  totalSnags = 0
  breakdown = {}

  FOR EACH manifestFile IN siteManifestFiles
    siteManifest = DOWNLOAD manifestFile
    siteId = EXTRACT siteId FROM manifestFile.path

    totalBytes += siteManifest.totalBytes
    totalImages += siteManifest.imageCount

    // Estimate snag count (each snag can have up to 12 images)
    uniqueSnagIds = EXTRACT UNIQUE snagIds FROM siteManifest.images.keys()
    snagCount = LENGTH OF uniqueSnagIds
    totalSnags += snagCount

    breakdown[siteId] = {
      bytes: siteManifest.totalBytes,
      images: siteManifest.imageCount,
      snags: snagCount
    }
  END FOR

  // Step 3: Get user's quota from profile
  userProfile = GET FIRESTORE DOCUMENT "Profile/{ownerUID}"
  subscriptionTier = userProfile.subscriptionTier OR "FREE"

  quotaLimit = MATCH subscriptionTier
    "FREE"     → 1 GB  (1000000000 bytes)
    "PRO"      → 5 GB  (5000000000 bytes)
    "BUSINESS" → 100 GB (100000000000 bytes)
  END MATCH

  // Step 4: Build user manifest
  userManifest = {
    totalBytes: totalBytes,
    imageCount: totalImages,
    snagCount: totalSnags,
    siteCount: LENGTH OF breakdown,

    breakdown: breakdown,

    quotaLimit: quotaLimit,
    quotaUsedPercent: ROUND((totalBytes / quotaLimit) * 100, 1),

    lastCalculated: NOW()
  }

  // Step 5: Save user manifest
  UPLOAD userManifest AS JSON TO userManifestPath

END FUNCTION
```

### 3. Get Signed URLs (Batch)

```
FUNCTION getSignedUrls(request, context)

  // Step 1: Verify authenticated
  IF context.auth IS NULL THEN
    THROW Error("Unauthenticated")
  END IF

  // Step 2: Validate input
  IF request.imageKeys IS EMPTY THEN
    THROW Error("No images requested")
  END IF

  IF LENGTH OF request.imageKeys > 2000 THEN
    THROW Error("Maximum 2000 images per request")
  END IF

  ownerUID = request.ownerUID
  siteId = request.siteId

  // Step 3: Verify access permission
  userEmail = context.auth.token.email.lowercase()
  userUID = context.auth.uid

  IF userUID == ownerUID THEN
    // User is owner - allowed
    accessGranted = TRUE
  ELSE
    // Check shared_access
    emailHash = SHA256(userEmail)
    accessDoc = GET FIRESTORE DOCUMENT "shared_access/{emailHash}"

    IF accessDoc EXISTS AND siteId IN accessDoc.sites THEN
      accessGranted = TRUE
    ELSE
      accessGranted = FALSE
    END IF
  END IF

  IF NOT accessGranted THEN
    THROW Error("Access denied to site")
  END IF

  // Step 4: Generate signed URLs
  signedUrls = {}
  expiryTime = NOW() + 7 DAYS

  FOR EACH imageKey IN request.imageKeys

    // Parse image key: "snagA_p0" → snagId, type, slot
    parts = SPLIT imageKey BY "_"
    snagId = parts[0]
    typeAndSlot = parts[1]

    // Build storage path
    storagePath = "Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId}/{typeAndSlot}.jpg"

    TRY
      url = GENERATE SIGNED URL FOR storagePath WITH {
        action: "read",
        expires: expiryTime
      }
      signedUrls[imageKey] = url
    CATCH FileNotFound
      // Skip missing files
      signedUrls[imageKey] = NULL
    END TRY

  END FOR

  // Step 5: Return results
  RETURN {
    urls: signedUrls,
    expiresAt: expiryTime,
    requestedCount: LENGTH OF request.imageKeys,
    foundCount: COUNT OF signedUrls WHERE value IS NOT NULL
  }

END FUNCTION
```

### 4. Check Upload Quota

```
FUNCTION canUploadImage(ownerUID, imageSizeBytes)

  // Called BEFORE allowing image upload

  userManifestPath = "Profile/{ownerUID}/storage_manifest.json"

  TRY
    userManifest = DOWNLOAD userManifestPath
  CATCH FileNotFound
    // New user with no manifest yet - allow
    RETURN { allowed: TRUE }
  END TRY

  newTotal = userManifest.totalBytes + imageSizeBytes

  // Check if over quota
  IF newTotal > userManifest.quotaLimit THEN
    RETURN {
      allowed: FALSE,
      reason: "Storage quota exceeded",
      currentUsage: FORMAT_BYTES(userManifest.totalBytes),
      limit: FORMAT_BYTES(userManifest.quotaLimit),
      percentUsed: userManifest.quotaUsedPercent
    }
  END IF

  // Warn if approaching quota (>80%)
  IF newTotal > (userManifest.quotaLimit * 0.8) THEN
    newPercent = ROUND((newTotal / userManifest.quotaLimit) * 100, 1)
    RETURN {
      allowed: TRUE,
      warning: "Storage {newPercent}% full",
      suggestion: "Consider upgrading for more space"
    }
  END IF

  RETURN { allowed: TRUE }

END FUNCTION
```

---

## Sync Decision Flowchart

```
USER TAPS "SYNC SHARED SITES"
            │
            ▼
┌─────────────────────────────┐
│ For each shared site...     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Download site manifest      │
│ (small file ~60KB)          │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐      YES     ┌────────────────────┐
│ Local manifest exists?      │─────────────▶│ Compare versions   │
└──────────────┬──────────────┘              └─────────┬──────────┘
               │ NO                                    │
               ▼                                       ▼
┌─────────────────────────────┐              ┌────────────────────┐
│ FIRST SYNC:                 │              │ Versions match?    │
│ Download ALL images         │              └─────────┬──────────┘
└──────────────┬──────────────┘                  │           │
               │                              SAME         DIFFERENT
               │                                │           │
               │                                ▼           ▼
               │                           ┌────────┐ ┌──────────────────┐
               │                           │ SKIP   │ │ Diff the lists:  │
               │                           │ (done) │ │ • New images     │
               │                           └────────┘ │ • Updated images │
               │                                      │ • Deleted images │
               │                                      └─────────┬────────┘
               │                                                │
               ▼                                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Request signed URLs from Cloud Function                                 │
│ (1 call, 1 Firestore read for auth check)                               │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Download images in parallel (max 5 concurrent)                          │
│ Save to local storage                                                   │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Delete local images that were removed remotely                          │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Save updated manifest to local storage                                  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
                              ✅ DONE
```

---

## Cost Analysis

### Scenario: Power User

| Metric | Value |
|--------|-------|
| Shared sites | 50 |
| Snags per site | 100 |
| Images per snag | 6 |
| Total images | 30,000 |
| Image size (avg) | 800 KB |
| Total storage | ~24 GB |

### First Sync Cost (All 50 Sites)

| Operation | Count | Cost |
|-----------|-------|------|
| Manifest downloads | 50 | ~$0.0001 |
| CF invocation | 50 | ~$0.00002 |
| Firestore reads (auth) | 50 | ~$0.00002 |
| Image downloads | 30,000 | ~$0.36 |
| Bandwidth (24 GB) | 24 GB | ~$2.88 |
| **Total** | | **~$3.24** |

### Incremental Sync - Nothing Changed

| Operation | Count | Cost |
|-----------|-------|------|
| Manifest downloads | 50 | ~$0.0001 |
| Version compare | Local only | $0 |
| **Total** | | **~$0.0001** |

### Incremental Sync - 5 Sites Changed, 20 New Images

| Operation | Count | Cost |
|-----------|-------|------|
| Manifest downloads | 50 | ~$0.0001 |
| CF invocations | 5 | ~$0.000002 |
| Firestore reads (auth) | 5 | ~$0.000002 |
| Image downloads | 20 | ~$0.00024 |
| Bandwidth (16 MB) | 16 MB | ~$0.002 |
| **Total** | | **~$0.003** |

### Monthly Cost Comparison (Daily Sync)

| Approach | Monthly Cost |
|----------|--------------|
| WITHOUT manifest (query all snags) | ~$5.40/user |
| WITH manifest (version check) | ~$0.003/user |
| **Savings** | **99.9%** |

---

## Storage UI Display

```
┌─────────────────────────────────────────────────┐
│  Storage Usage                                  │
│  ═══════════════════════════════════════════    │
│                                                 │
│  [████████░░░░░░░░░░░░░░░░░░] 25%               │
│                                                 │
│  1.25 GB used of 5 GB (Pro)                     │
│                                                 │
│  Breakdown by Site:                             │
│  ─────────────────────────────────────────      │
│  • Main Street Renovation     890 MB   1,205 📷 │
│  • Office Building Phase 2    245 MB     312 📷 │
│  • Warehouse Project          115 MB     823 📷 │
│                                                 │
│  Total: 2,340 images across 487 snags           │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │   Upgrade to Business → 100 GB          │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

---

## Security: Callable Cloud Functions

### Mandatory Security Layers

**Every callable Cloud Function MUST implement these layers:**

```
REQUEST
   │
   ▼
┌────────────────────────────────────────┐
│ 1. APP CHECK                           │
│    Is request from legitimate app?     │
│    (Enforced in Firebase Console)      │
└───────────────────┬────────────────────┘
                    ▼
┌────────────────────────────────────────┐
│ 2. AUTHENTICATION                      │
│    Is user logged in?                  │
│    Is email verified?                  │
└───────────────────┬────────────────────┘
                    ▼
┌────────────────────────────────────────┐
│ 3. AUTHORIZATION                       │
│    Does user have access to resource?  │
│    (Owner OR in shared_access)         │
└───────────────────┬────────────────────┘
                    ▼
┌────────────────────────────────────────┐
│ 4. RATE LIMITING                       │
│    Has user exceeded daily limit?      │
│    (Prevents cost abuse)               │
└───────────────────┬────────────────────┘
                    ▼
              PROCESS REQUEST
```

### Rate Limits by Function

| Function | Limit | Scope | Rationale |
|----------|-------|-------|-----------|
| `getSignedUrls` | 10/day | Per site | Covers busy workday syncs |
| `getSignedUrls` | 2,000 images | Per call | Fits worst case (1,800 images) |

**Note:** `rebuildSiteManifest` is NOT callable by clients. It's an internal function triggered only by the scheduled health check CF.

**Worst case calculation:**
```
Max snags per site: 200
Images per snag: 6
Total: 200 × 6 = 1,200 images
With 1.5x buffer: 1,800 images → rounded to 2,000 limit
```

**Note:** Rate limiting applies to ALL callable functions. Storage existence checks and Firestore reads still cost money at scale.

### Signed URL Security

| Property | Value | Rationale |
|----------|-------|-----------|
| Validity | 7 days | Balance between convenience and security |
| Scope | Single file | Cannot access other files |
| Action | Read only | Cannot modify or delete |
| Authentication | Required first | URLs only given to verified users |

---

## Manifest Recovery (Server-Controlled)

### Architecture Decision

**Client does NOT trigger rebuilds.** Server handles all recovery automatically.

```
┌─────────────────────────────────────────────────────────┐
│  SCHEDULED CF: checkManifestHealth                      │
│  Runs every N minutes (configurable, default: 5)        │
│                                                         │
│  FOR EACH site:                                         │
│    - Check if manifest exists                           │
│    - Check if manifest is stale                         │
│    - Check if manifest is corrupt                       │
│    - Rebuild if any issue found                         │
│    - Log results to monitoring                          │
└─────────────────────────────────────────────────────────┘
```

**Benefits:**
- Zero abuse risk (no callable rebuild function)
- Predictable cost (fixed scheduled runs)
- Full control (change logic without app update)
- Simpler client (just download, no detection)

**Cost at scale:**
| Sites | Cost/Month |
|-------|------------|
| 5 | ~$0.02 |
| 100 | ~$0.31 |
| 1,000 | ~$3.10 |
| 10,000 | ~$31 |

Cost scales with revenue - acceptable trade-off.

---

### Scenario 1: Missing Manifest (404) ✅ AGREED

**When it happens:**
- New site before first snag sync
- Cloud Function trigger failed
- Feature deployed to existing sites

**Server handles it:**
```
checkManifestHealth detects missing manifest
  → Rebuilds from Firestore + Storage
  → Manifest available within 5 minutes
```

**Client behavior:**
```
Download manifest
  │
  ├── 404? → Show "Site syncing, please wait..."
  │          Auto-retry after 30 seconds
  │          After 3 retries → "Try again later"
  │
  └── OK? → Continue sync
```

**TODO:** Define exact client UI for "syncing in progress"

---

### Scenario 2: Stale Manifest ✅ AGREED

**When it happens:**
- Cloud Function trigger failed silently
- Firestore updated but CF didn't run

**Server handles it:**
```
checkManifestHealth compares:
  Site.lastSnagUpdate vs manifest.updatedAt

If lastSnagUpdate > updatedAt + 2 minutes → STALE
  → Rebuild manifest
```

**Client behavior:**
- Client doesn't detect staleness
- Just downloads manifest and syncs
- Server ensures freshness within 5 minutes

---

### Scenario 3: Corrupt Manifest ✅ AGREED

**When it happens:**
- Partial write (CF timeout mid-upload)
- Storage corruption (rare)

**Server handles it:**
```
checkManifestHealth attempts to parse manifest JSON

IF parse fails → CORRUPT
  → Delete corrupt file
  → Rebuild from scratch
```

**Client behavior:**
- Same as missing (404) - corrupt file might not download properly
- Server fixes within 5 minutes

---

### Manifest Integrity

Manifests can only be modified by Cloud Functions:

| Actor | Can Create | Can Modify | Can Delete |
|-------|------------|------------|------------|
| Site Owner (client) | ❌ | ❌ | ❌ |
| Shared User (client) | ❌ | ❌ | ❌ |
| Scheduled CF | ✅ | ✅ | ✅ (corrupt only) |
| Trigger CF (onSnagWritten) | ✅ | ✅ | ❌ |
| Admin (console) | ✅ | ✅ | ✅ |

---

### Scenario 4: Hash Mismatch (TODO - Needs Discussion)

**When it happens:**
- Image replaced, but manifest not updated yet
- Timing issue between image upload and manifest update

**Detection:**
```
Client downloads image
Client computes hash
Hash ≠ manifest.images[key].hash
```

**Question:** Do we need to actively detect this?

**Options:**
- Option A: Ignore - manifest will catch up within 5 minutes
- Option B: Client re-downloads image if hash mismatch
- Option C: Client flags mismatch, server investigates

---

### Scenario 5: Race Condition (TODO - Needs Discussion)

**When it happens:**
```
T1: User A uploads image → CF A starts
T2: User B uploads image → CF B starts
T3: CF A reads manifest (version 5)
T4: CF B reads manifest (version 5)
T5: CF A writes manifest (version 6, has A's image)
T6: CF B writes manifest (version 6, OVERWRITES, loses A's image!)
```

**Question:** How likely is this? How to prevent?

**Options:**
- Option A: Optimistic locking (check version before write)
- Option B: Use Firestore for manifest (has transactions)
- Option C: Accept rare loss, server health check catches it

---

## Edge Cases

| Edge Case | Risk | Mitigation |
|-----------|------|------------|
| User clears app / reinstalls | Full re-sync needed | Legitimate use, can't prevent |
| Owner shares with 20 people | 20 × 1GB = 20GB bandwidth = $2.40 | Owner pays; consider share limits per tier |
| Offline for 2 weeks, then sync | Many changes accumulated | 10 calls/day limit still sufficient |
| FIXER vs VIEW download volume | FIXER sees fewer images | No issue, just different volumes |
| Image replaced by owner | Hash changes, shared users re-download | Normal behavior |
| Multiple users sync same site | Each has own rate limit | No conflict |

### Bandwidth Cost Concern

```
Owner shares 1 GB site with 20 colleagues
Each does first sync: 20 × 1 GB = 20 GB
Cost: 20 GB × $0.12 = $2.40 (charged to owner's project)
```

**TODO:** Consider limiting shares per tier or warning owner about costs

---

## Worst Case Cost Analysis

**Scenario:** First sync of maximum-size site

```
Site: 200 snags × 6 images = 1,200 images
Image size: 800 KB each
Total data: ~1 GB
```

| Operation | Quantity | Cost |
|-----------|----------|------|
| CF invocation | 1 | $0.0000004 |
| CF compute (10 sec) | 2.5 GB-sec | $0.000006 |
| Firestore read (auth) | 1 | $0.00000036 |
| Manifest download | 60 KB | $0.000007 |
| Image downloads | 1,200 ops | $0.0005 |
| **Bandwidth (egress)** | **1 GB** | **$0.12** |
| **TOTAL** | | **~$0.12** |

**Key insight:** 99%+ of cost is bandwidth. CF calls and Firestore reads are negligible.

---

## Admin Dashboard (Future)

**Purpose:** Private web dashboard for app owner to monitor system health and usage.

### Configurable Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Health check interval | 5 minutes | How often checkManifestHealth runs |
| Stale threshold | 2 minutes | How old before manifest considered stale |
| Max retry attempts | 3 | Client retries before showing error |

**Example:** During low-traffic periods, change health check from 5 to 10 minutes to reduce cost.

### Metrics from Sync Feature

| Metric | Description | Why Useful |
|--------|-------------|------------|
| Total manifests | Count of site manifests | Scale indicator |
| Health check runs | Daily count | Verify scheduled CF running |
| Rebuilds triggered | By health check, daily/weekly | Detect CF trigger failures |
| Failed rebuilds | Count with site IDs | Immediate attention needed |
| getSignedUrls calls | Daily volume | Usage pattern |
| Rate limit hits | Users hitting limits | Adjust limits if needed |
| Total storage used | Across all users | Capacity planning |
| Storage by tier | FREE vs PRO vs BUSINESS | Revenue insight |
| Largest sites | Top 10 by image count | Identify power users |
| Stale detections | How often staleness found | CF reliability indicator |

### Alerts to Configure

| Alert | Trigger | Action |
|-------|---------|--------|
| Health check missed | No run in 15 minutes | Check scheduled CF |
| Rebuild failure | 3 failures same site | Email owner |
| High rebuild rate | >10 rebuilds/hour | CF triggers failing |
| Rate limit spike | >10 users hit limit/hour | Review limits |
| Storage anomaly | User adds >1GB in 1 hour | Investigate |

**TODO:** Add more metrics as features are built

---

## Implementation Checklist

### Phase 1: Site Manifest (Cloud Function)

- [ ] Create `onSnagWritten` Cloud Function trigger
- [ ] Implement manifest creation/update logic
- [ ] Handle snag deletion (remove entries)
- [ ] Deploy and test with manual snag changes

### Phase 2: User Storage Manifest

- [ ] Create `updateUserStorageManifest` function
- [ ] Add quota limits by subscription tier
- [ ] Deploy and verify aggregation

### Phase 3: Signed URL Function

- [ ] Create `getSignedUrls` Cloud Function
- [ ] Implement rate limiting
- [ ] Add access verification (owner OR shared_access)
- [ ] Deploy and test

### Phase 4: Client Sync Logic

- [ ] Implement manifest download
- [ ] Implement version comparison
- [ ] Implement diff calculation (new/updated/deleted)
- [ ] Implement batch signed URL request
- [ ] Implement parallel image download (max 5)
- [ ] Implement local manifest caching

### Phase 5: Storage UI

- [ ] Add storage usage screen to Profile
- [ ] Display breakdown by site
- [ ] Show quota warnings at 80%
- [ ] Add upgrade prompts

### Phase 6: Quota Enforcement

- [ ] Check quota before image upload
- [ ] Block upload if exceeded
- [ ] Show user-friendly error message

---

## Document History

| Date | Version | Change |
|------|---------|--------|
| 2026-06-09 | 1.0.0 | Initial document |
| 2026-06-09 | 2.0.0 | Complete rewrite with manifest approach |
| 2026-06-09 | 2.1.0 | Added security layers, rate limiting, Scenario 1 recovery, admin dashboard |
| 2026-06-10 | 2.2.0 | Updated rate limits (10 calls/day, 2000 images/call per site), added tier/sharing structure (TODO), added Scenarios 2-5 (TODO), edge cases, worst case cost analysis |

---

*This document defines the approved sync strategy for SnagSnapper shared sites.*
