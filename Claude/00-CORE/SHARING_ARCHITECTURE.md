# Site Sharing Architecture

**Version:** 1.0.0
**Last Updated:** 2026-06-07
**Status:** Design Complete

---

## Overview

This document defines how site sharing works in SnagSnapper, including:
- Permission levels and settings
- Firebase data structure
- Discovery mechanism for shared sites
- Cloud Function implementation

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
/sites/{ownerUID}/sites/{siteId}        → Site document (full data)
/shared_access/{emailHash}/sites/{siteId} → Discovery index (lightweight)
```

### Site Document

```javascript
// /sites/{ownerUID}/sites/{siteId}
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

### Shared Access Index (Discovery)

```javascript
// /shared_access/{emailHash}/sites/{siteId}
{
  ownerUID: "abc123",
  ownerEmail: "owner@example.com",
  siteName: "Project Alpha",
  permission: "WORKING",
  sharedAt: Timestamp
}
```

**Purpose:** Enables O(1) discovery of sites shared with a user.

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
│    /sites/{ownerUID}/sites/{siteId}                         │
│                                                             │
│ 3. Cloud Function triggers on sharedWith change             │
│                                                             │
│ 4. CF creates discovery index                               │
│    /shared_access/{emailHash}/sites/{siteId}                │
└─────────────────────────────────────────────────────────────┘
```

### Collaborator Discovers Shared Sites

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Collaborator opens app                                   │
│                                                             │
│ 2. App queries: /shared_access/{myEmailHash}/sites/         │
│    (ONE read - O(1) discovery)                              │
│                                                             │
│ 3. Gets list of { siteId, ownerUID, permission }            │
│                                                             │
│ 4. Fetches each site: /sites/{ownerUID}/sites/{siteId}      │
│    (N reads for N shared sites)                             │
│                                                             │
│ 5. Saves to local database                                  │
│    Works offline from then on                               │
└─────────────────────────────────────────────────────────────┘
```

### Owner Removes Access

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Owner removes email from Site.sharedWith                 │
│                                                             │
│ 2. Site syncs to Firebase                                   │
│                                                             │
│ 3. Cloud Function detects removal                           │
│                                                             │
│ 4. CF deletes discovery index                               │
│    /shared_access/{emailHash}/sites/{siteId}                │
│                                                             │
│ 5. Collaborator loses access on next sync                   │
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

### Cloud Function Code

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

/**
 * Triggered when a site's sharedWith field changes.
 * Creates/deletes discovery index entries in shared_access collection.
 */
exports.onSiteSharedWithChange = functions.firestore
  .document('sites/{ownerUID}/sites/{siteId}')
  .onUpdate(async (change, context) => {
    const { ownerUID, siteId } = context.params;

    const beforeData = change.before.data();
    const afterData = change.after.data();

    const beforeShared = beforeData.sharedWith || {};
    const afterShared = afterData.sharedWith || {};

    const siteName = afterData.name;
    const ownerEmail = afterData.ownerEmail;

    const batch = db.batch();

    // Find added shares
    for (const [email, permission] of Object.entries(afterShared)) {
      if (!beforeShared[email]) {
        // New share - create access document
        const emailHash = hashEmail(email);
        const accessRef = db
          .collection('shared_access')
          .doc(emailHash)
          .collection('sites')
          .doc(siteId);

        batch.set(accessRef, {
          ownerUID,
          ownerEmail,
          siteName,
          permission,
          sharedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Created shared_access for ${email} to site ${siteId}`);
      } else if (beforeShared[email] !== permission) {
        // Permission changed - update access document
        const emailHash = hashEmail(email);
        const accessRef = db
          .collection('shared_access')
          .doc(emailHash)
          .collection('sites')
          .doc(siteId);

        batch.update(accessRef, {
          permission,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Updated permission for ${email} on site ${siteId}`);
      }
    }

    // Find removed shares
    for (const email of Object.keys(beforeShared)) {
      if (!afterShared[email]) {
        // Share removed - delete access document
        const emailHash = hashEmail(email);
        const accessRef = db
          .collection('shared_access')
          .doc(emailHash)
          .collection('sites')
          .doc(siteId);

        batch.delete(accessRef);

        console.log(`Deleted shared_access for ${email} from site ${siteId}`);
      }
    }

    await batch.commit();
  });

/**
 * Triggered when a site is deleted.
 * Removes all shared_access entries for that site.
 */
exports.onSiteDeleted = functions.firestore
  .document('sites/{ownerUID}/sites/{siteId}')
  .onDelete(async (snapshot, context) => {
    const { siteId } = context.params;
    const data = snapshot.data();
    const sharedWith = data.sharedWith || {};

    const batch = db.batch();

    for (const email of Object.keys(sharedWith)) {
      const emailHash = hashEmail(email);
      const accessRef = db
        .collection('shared_access')
        .doc(emailHash)
        .collection('sites')
        .doc(siteId);

      batch.delete(accessRef);
    }

    await batch.commit();
    console.log(`Cleaned up shared_access for deleted site ${siteId}`);
  });

/**
 * Hash email for use as document ID.
 * SHA256 produces consistent, collision-resistant 64-char hex string.
 */
function hashEmail(email) {
  return crypto
    .createHash('sha256')
    .update(email.toLowerCase().trim())
    .digest('hex');
}
```

### Deployment

```bash
cd functions
npm install
firebase deploy --only functions
```

---

## Client Implementation

### Sharing a Site

```dart
// In SiteDao or SiteSyncHandler
Future<void> shareSite(String siteId, String email, String permission) async {
  final site = await getSiteById(siteId);
  if (site == null) return;

  final updatedSharedWith = Map<String, String>.from(site.sharedWith);
  updatedSharedWith[email.toLowerCase()] = permission;

  await updateSite(site.copyWith(
    sharedWith: updatedSharedWith,
    needsSiteSync: true,
  ));

  // Cloud Function handles creating shared_access entry
}
```

### Discovering Shared Sites

```dart
// In SiteSyncHandler
Future<List<Site>> discoverSharedSites(String userEmail) async {
  final emailHash = emailToHash(userEmail);

  // 1. Query discovery index (ONE read)
  final sharedAccess = await FirebaseFirestore.instance
    .collection('shared_access')
    .doc(emailHash)
    .collection('sites')
    .get();

  final sites = <Site>[];

  // 2. Fetch each shared site
  for (final doc in sharedAccess.docs) {
    final ownerUID = doc.data()['ownerUID'] as String;
    final siteId = doc.id;

    final siteDoc = await FirebaseFirestore.instance
      .collection('sites')
      .doc(ownerUID)
      .collection('sites')
      .doc(siteId)
      .get();

    if (siteDoc.exists) {
      sites.add(Site.fromFirestore(siteId, siteDoc.data()!));
    }
  }

  return sites;
}

String emailToHash(String email) {
  final normalized = email.toLowerCase().trim();
  final bytes = utf8.encode(normalized);
  return sha256.convert(bytes).toString();
}
```

---

## Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Sites: Owner has full access, collaborators can read
    match /sites/{ownerUID}/sites/{siteId} {
      allow read, write: if request.auth.uid == ownerUID;

      // Collaborators can read if their email is in sharedWith
      allow read: if request.auth.token.email.lower() in resource.data.sharedWith.keys();

      // CONTRIBUTOR can update (but not delete or change ownership)
      allow update: if
        request.auth.token.email.lower() in resource.data.sharedWith.keys() &&
        resource.data.sharedWith[request.auth.token.email.lower()] == 'CONTRIBUTOR' &&
        request.resource.data.ownerUID == resource.data.ownerUID &&
        request.resource.data.ownerEmail == resource.data.ownerEmail;
    }

    // Shared Access: Read-only for users (Cloud Function writes)
    match /shared_access/{emailHash}/sites/{siteId} {
      // Users can only read their own shared_access
      // We can't verify emailHash matches user's email in rules,
      // but the data is not sensitive (just pointers)
      allow read: if request.auth != null;

      // Only Cloud Functions can write (no client access)
      allow write: if false;
    }
  }
}
```

---

## Cost Analysis

### Sharing a Site

| Action | Reads | Writes |
|--------|-------|--------|
| Update Site.sharedWith | 0 | 1 |
| CF creates shared_access | 0 | 1 (per email) |
| **Total** | **0** | **2** |

### Discovering Shared Sites

| Action | Reads | Writes |
|--------|-------|--------|
| Query shared_access index | 1 | 0 |
| Fetch N shared sites | N | 0 |
| **Total** | **N+1** | **0** |

### Comparison vs Naive Approach

| Approach | Discovery Cost (10,000 sites in system) |
|----------|----------------------------------------|
| ❌ Query all sites | 10,000 reads |
| ✅ Reverse index | 1 read + N shared sites |

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
| Discovery mechanism | Reverse index | O(1) lookup, scalable |
| Index creation | Cloud Function | Secure, reliable, extensible |

---

## Document History

| Date | Version | Change |
|------|---------|--------|
| 2026-06-07 | 1.0.0 | Initial document |

---

*This document is the source of truth for SnagSnapper sharing architecture.*
