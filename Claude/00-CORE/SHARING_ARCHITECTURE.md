# Site Sharing Architecture

**Version:** 1.1.0
**Last Updated:** 2026-06-09
**Status:** Implemented

---

## Pending Issues

| Issue | Priority | Description |
|-------|----------|-------------|
| **Image Download** | HIGH | Shared site/snag images not downloading from Firebase Storage. Need to implement Storage rules and client download logic for collaborator access. |

---

## Overview

This document defines how site sharing works in SnagSnapper, including:
- Permission levels and settings
- Firebase data structure
- Discovery mechanism for shared sites
- Cloud Function implementation
- Snag sharing (inherits from site)

---

## Permission System

### Access Levels

| Level | Description | Capabilities |
|-------|-------------|--------------|
| **OWNER** | Site creator | Full control, configure permissions |
| **VIEW** | Read-only | See all snags, cannot edit |
| **WORKING** | Assigned work | Work on assigned snags only |
| **CONTRIBUTOR** | Team member | Create snags, work on assigned |

**Note:** OWNER is not stored in `sharedWith` - identified by `ownerEmail` match.

### Configurable Settings (Per-Site)

| Setting | Default | Description |
|---------|---------|-------------|
| `workingCanSeeAllSnags` | `true` | WORKING can see all snags (but only edit assigned) |
| `contributorCanEditOthers` | `false` | CONTRIBUTOR can edit snags created by others |

### Permission Matrix

| Capability | VIEW | WORKING | CONTRIBUTOR | OWNER |
|------------|------|---------|-------------|-------|
| See all snags | ✅ | ⚙️ Setting | ✅ | ✅ |
| See assigned snags | ✅ | ✅ | ✅ | ✅ |
| Create snags | ❌ | ❌ | ✅ | ✅ |
| Edit assigned snags | ❌ | ✅ | ✅ | ✅ |
| Edit own snags | ❌ | ❌ | ✅ | ✅ |
| Edit others' snags | ❌ | ❌ | ⚙️ Setting | ✅ |
| Mark complete | ❌ | ✅ (assigned) | ✅ | ✅ |
| Configure settings | ❌ | ❌ | ❌ | ✅ |

---

## Firebase Data Structure

### Collections

```
/Profile/{ownerUID}/Sites/{siteId}       → Site document (full data)
/Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId} → Snag documents
/shared_access/{emailHash}               → Single document per user (discovery index)
```

### Site Document

```javascript
// /Profile/{ownerUID}/Sites/{siteId}
{
  // Core fields
  name: "Project Alpha",
  ownerUID: "abc123",
  ownerEmail: "owner@example.com",

  // Sharing
  sharedWith: {
    "john@example.com": "WORKING",
    "jane@example.com": "CONTRIBUTOR"
  },

  // Permission settings
  workingCanSeeAllSnags: true,
  contributorCanEditOthers: false,

  // ... other site fields
}
```

### Shared Access Index (Discovery) - Single Document Structure

```javascript
// /shared_access/{emailHash}
{
  email: "john@example.com",  // For security rule verification
  sites: {
    "siteId1": "ownerUID1",
    "siteId2": "ownerUID2"
  }
}
```

**Why Single Document (not Subcollection)?**
- Firestore rules can verify `resource.data.email == request.auth.token.email` on `get()` operations
- Subcollection `list()` queries cannot evaluate `resource.data` for security
- Single document = 1 read instead of N+1 reads
- Attacker knowing email hash cannot access another user's document

---

## Email Hashing

Firebase paths cannot contain `@` or `.` in certain positions. We use SHA256 hash of normalized email.

### Implementation

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

String emailToHash(String email) {
  final normalized = email.toLowerCase().trim();
  final bytes = utf8.encode(normalized);
  return sha256.convert(bytes).toString();
}

// Example:
// john@example.com → 836f82db99121b3481011f16b49dfa5fbc714a0d1b1b9f784a1ebbbf5b39577f
```

### Properties

| Property | Value |
|----------|-------|
| Deterministic | Same email → same hash, always |
| Fixed length | 64 characters (hex) |
| Collision-resistant | Virtually impossible |
| One-way | Cannot reverse to get email |

---

## Sharing Flow

### Owner Shares Site

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Owner updates Site.sharedWith                            │
│    { "john@example.com": "WORKING" }                        │
│                                                             │
│ 2. Site syncs to Firebase                                   │
│    /Profile/{ownerUID}/Sites/{siteId}                       │
│                                                             │
│ 3. Cloud Function triggers (onSiteCreated or onSiteUpdated) │
│                                                             │
│ 4. CF updates shared_access document:                       │
│    /shared_access/{emailHash} → { sites.{siteId}: ownerUID }│
└─────────────────────────────────────────────────────────────┘
```

### Collaborator Discovers Shared Sites

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Collaborator taps "Check & Download" in Shared Sites tab │
│                                                             │
│ 2. App gets: /shared_access/{myEmailHash}                   │
│    (ONE read - secure via email field verification)         │
│                                                             │
│ 3. Reads sites map: { siteId1: ownerUID1, siteId2: ownerUID2}│
│                                                             │
│ 4. Fetches each site: /Profile/{ownerUID}/Sites/{siteId}    │
│    (N reads for N shared sites)                             │
│                                                             │
│ 5. Fetches snags: /Profile/{ownerUID}/Sites/{siteId}/Snags/ │
│    (Snags inherit site sharing permissions)                 │
│                                                             │
│ 6. Saves to local SQLite database                           │
│    Works offline from then on                               │
│                                                             │
│ 7. TODO: Download images from Firebase Storage              │
└─────────────────────────────────────────────────────────────┘
```

### Owner Removes Access

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Owner removes email from Site.sharedWith                 │
│                                                             │
│ 2. Site syncs to Firebase                                   │
│                                                             │
│ 3. Cloud Function (onSiteUpdated) detects removal           │
│                                                             │
│ 4. CF removes site from shared_access:                      │
│    /shared_access/{emailHash} → delete sites.{siteId}       │
│                                                             │
│ 5. Collaborator loses access on next "Check & Download"     │
└─────────────────────────────────────────────────────────────┘
```

---

## Cloud Function Implementation

### Why Cloud Function?

| Approach | Security | Reliability | Extensibility |
|----------|----------|-------------|---------------|
| **Client does 2 writes** | ⚠️ Complex rules needed | ⚠️ Could forget 2nd write | ❌ Logic in client |
| **Cloud Function** | ✅ User can't fake access | ✅ Automatic | ✅ Easy to extend |

**Decision:** Cloud Function for security and reliability.

### Cloud Functions (Deployed)

Located at: `functions/index.js`

**Functions:**
- `onSiteCreated` - Creates shared_access entries when site with sharedWith is created
- `onSiteUpdated` - Adds/removes entries when sharedWith changes
- `onSiteDeleted` - Removes all entries when site is deleted

**Key Implementation Detail:**
```javascript
// Two-step approach required for nested map creation:
// 1. set() with merge ensures document exists with email field
// 2. update() with dot notation adds site to nested map

await accessRef.set({ email: email.toLowerCase().trim() }, { merge: true });
await accessRef.update({ [`sites.${siteId}`]: ownerUID });

// For removal, use FieldValue.delete():
await accessRef.update({ [`sites.${siteId}`]: FieldValue.delete() });
```

**Why two steps?**
- `set()` with `merge: true` does NOT interpret dots as nested paths
- `update()` DOES interpret dots as nested paths
- Using `sites: { [siteId]: ownerUID }` with set/merge would REPLACE the entire sites map

### Deployment

```bash
cd functions
npm install
firebase deploy --only functions
```

---

## Client Implementation

### Sharing a Site (via Share Dialog)

Located at: `lib/Widgets/share_site_dialog.dart`

```dart
// Called from SiteStatusV2._showShareSheet()
final newSharedWith = await showShareSiteSheet(context: context, site: site);

if (newSharedWith != null) {
  final updatedSite = site.copyWith(
    sharedWith: newSharedWith,
    needsSiteSync: true,
  );
  await AppDatabase.instance.siteDao.updateSite(updatedSite);
  // Cloud Function handles creating shared_access entry on sync
}
```

### Discovering Shared Sites

Located at: `lib/services/shared_site_service.dart`

```dart
Future<SharedSiteDownloadResult> checkAndDownloadSharedSites() async {
  final emailHash = _hashEmail(userEmail);

  // 1. Get single shared_access document (ONE read, secure)
  final sharedAccessDoc = await _firestore
      .collection('shared_access')
      .doc(emailHash)
      .get();

  if (!sharedAccessDoc.exists) return empty;

  final sites = sharedAccessDoc.data()!['sites'] as Map<String, dynamic>;

  // 2. Fetch each shared site and its snags
  for (final entry in sites.entries) {
    final siteId = entry.key;
    final ownerUID = entry.value as String;

    // Download site document
    final siteDoc = await _firestore
        .collection('Profile').doc(ownerUID)
        .collection('Sites').doc(siteId)
        .get();

    // Download snags for site
    final snagsQuery = await _firestore
        .collection('Profile').doc(ownerUID)
        .collection('Sites').doc(siteId)
        .collection('Snags')
        .get();

    // Save to local SQLite
    await _database.siteDao.insertSite(site);
    for (final snag in snags) {
      await _database.snagDao.insertSnag(snag);
    }

    // TODO: Download images from Firebase Storage
  }
}
```

---

## Security Rules

### Firestore Rules (firestore.rules)

```javascript
// Shared Access - Single document per user
match /shared_access/{emailHash} {
  // User can ONLY read their own shared_access document
  // Email field verification ensures security
  allow read: if isAuthenticated()
              && resource.data.email == request.auth.token.email.lower();

  // Only Cloud Functions can write
  allow write: if false;
}

// Sites - Collaborators can read if in sharedWith
match /Profile/{ownerUID}/Sites/{siteId} {
  allow read: if isOwner(ownerUID)
              || isCollaborator(resource.data);
  allow write: if isOwner(ownerUID);
}

// Snags - Inherit permissions from parent site
match /Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId} {
  allow read: if isOwner(ownerUID)
              || isCollaboratorOnSite(ownerUID, siteId);
  // Write rules based on permission level...
}
```

### Storage Rules (storage.rules) - TODO

```javascript
// TODO: Allow collaborators to READ images for shared sites
match /Profile/{ownerUID}/Sites/{siteId}/{allPaths=**} {
  allow read: if request.auth != null
              && (request.auth.uid == ownerUID
                  || isCollaboratorOnSite(ownerUID, siteId));
}
```

**Note:** Storage rules cannot directly query Firestore. Options:
1. Use custom claims in auth token
2. Create a separate index for storage access
3. Use signed URLs from Cloud Function

---

## Snag Sharing

### Inheritance Model

Snags **inherit sharing permissions from their parent site**. There is no separate sharing mechanism for snags.

```
Site (Delhi) - sharedWith: { "john@example.com": "WORKING" }
├── Snag A - John can see (inherits from site)
├── Snag B - John can see (inherits from site)
└── Snag C - John can see (inherits from site)
```

### Permission Enforcement for Snags

| Permission | Can See | Can Edit | Can Create | Can Mark Complete |
|------------|---------|----------|------------|-------------------|
| VIEW | All snags | None | No | No |
| WORKING | All* | Assigned only | No | Assigned only |
| CONTRIBUTOR | All | Own + Assigned | Yes | Yes |
| OWNER | All | All | Yes | Yes |

*WORKING visibility controlled by `workingCanSeeAllSnags` site setting

### Download Flow

When collaborator downloads a shared site:
1. Download site document from `/Profile/{ownerUID}/Sites/{siteId}`
2. Download ALL snags from `/Profile/{ownerUID}/Sites/{siteId}/Snags/`
3. Client-side filtering based on permission level
4. **TODO:** Download snag images from Storage

### Snag Assignment

Snags can be assigned to collaborators via `assignedEmail` field:
- WORKING users can only edit snags assigned to them
- Assignment doesn't affect visibility (controlled by site setting)
- Only OWNER can assign snags

---

## Cost Analysis

### Sharing a Site

| Action | Reads | Writes |
|--------|-------|--------|
| Update Site.sharedWith | 0 | 1 |
| CF creates shared_access | 0 | 2 (set + update) |
| **Total** | **0** | **3** |

### Discovering Shared Sites

| Action | Reads | Writes |
|--------|-------|--------|
| Get shared_access document | 1 | 0 |
| Fetch N shared sites | N | 0 |
| Fetch snags for N sites | N queries | 0 |
| **Total** | **1 + 2N** | **0** |

### Comparison: Single Document vs Subcollection

| Approach | Discovery Cost | Security |
|----------|----------------|----------|
| ❌ Subcollection (old) | N+1 reads | ❌ Broken (list() can't verify email) |
| ✅ Single document (new) | 1 read | ✅ Secure (get() verifies email) |

---

## Email Autocomplete (No Colleagues Table)

Instead of storing Colleagues in Profile, use sharing history for autocomplete:

```dart
Future<List<String>> getShareSuggestions(String query) async {
  // Get all sites owned by user
  final mySites = await siteDao.getOwnedSites(currentUserUID);

  // Collect all emails from sharedWith maps
  final allEmails = <String>{};
  for (final site in mySites) {
    allEmails.addAll(site.sharedWith.keys);
  }

  // Filter by query
  final queryLower = query.toLowerCase();
  return allEmails
    .where((email) => email.contains(queryLower))
    .toList()
    ..sort();
}
```

**No separate Colleagues collection needed.**

---

## Future Enhancements

### Push Notifications (Optional)

```javascript
// Add to onSiteSharedWithChange Cloud Function
const messaging = admin.messaging();

// Look up collaborator's FCM token
const userDoc = await db.collection('users').doc(collaboratorUID).get();
const fcmToken = userDoc.data()?.fcmToken;

if (fcmToken) {
  await messaging.send({
    token: fcmToken,
    notification: {
      title: 'Site shared with you',
      body: `${ownerEmail} shared "${siteName}" with you`,
    },
    data: {
      type: 'site_shared',
      siteId: siteId,
    },
  });
}
```

### Email Notifications (Optional)

Use Firebase Extensions or custom Cloud Function to send email when site is shared.

---

## Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Permission levels | VIEW, WORKING, CONTRIBUTOR | Simple, covers all use cases |
| Permission settings | Per-site | Flexible, no Profile complexity |
| Colleagues table | ❌ Removed | Use sharing history instead |
| Email in path | SHA256 hash | Reliable, secure, fixed length |
| Discovery mechanism | Single document per user | Secure get() vs insecure list() |
| Index creation | Cloud Function | Secure, reliable, extensible |
| Snag sharing | Inherit from site | No separate snag permissions |

---

## Document History

| Date | Version | Change |
|------|---------|--------|
| 2026-06-07 | 1.0.0 | Initial document |
| 2026-06-09 | 1.1.0 | Updated to single document structure (security fix), added snag sharing section, noted pending image download issue |

---

*This document is the source of truth for SnagSnapper sharing architecture.*
