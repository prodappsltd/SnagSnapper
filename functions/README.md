# SnagSnapper Cloud Functions

Cloud Functions for managing site sharing in SnagSnapper.

## Overview

These functions maintain a **reverse index** (`shared_access`) that enables efficient discovery of sites shared with a user. When a site owner modifies the `sharedWith` field, these functions automatically update the index.

## Architecture

```
/sites/{ownerUID}/sites/{siteId}           → Site document (sharedWith map)
/shared_access/{emailHash}/sites/{siteId}  → Discovery index (per-user)
```

See `Claude/00-CORE/SHARING_ARCHITECTURE.md` for full documentation.

## Functions

| Function | Trigger | Description |
|----------|---------|-------------|
| `onSiteCreated` | Firestore onCreate | Creates shared_access entries for initial collaborators |
| `onSiteUpdated` | Firestore onUpdate | Creates/updates/deletes entries when sharedWith changes |
| `onSiteDeleted` | Firestore onDelete | Cleans up all shared_access entries for deleted site |
| `syncSharedAccess` | HTTPS Callable | Manual sync for fixing inconsistencies |

## Setup

### Prerequisites

- Node.js 18+
- Firebase CLI (`npm install -g firebase-tools`)
- Firebase project with Firestore enabled

### Installation

```bash
cd functions
npm install
```

### Local Testing

```bash
# Start emulators
npm run serve

# Or use Firebase shell
npm run shell
```

### Deployment

```bash
# Deploy functions only
npm run deploy

# Or deploy with Firestore rules
firebase deploy --only functions,firestore:rules
```

## Security

- **Email hashing**: SHA256 hash of normalized email prevents enumeration
- **Cloud Function only writes**: Clients cannot modify `shared_access` directly
- **Permission validation**: Only valid permissions (VIEW, WORKING, CONTRIBUTOR) are accepted

## Monitoring

View logs:
```bash
npm run logs

# Or in Firebase Console
# Functions → Logs
```

## Manual Sync

If shared_access gets out of sync, use the callable function:

```dart
final functions = FirebaseFunctions.instance;
final result = await functions.httpsCallable('syncSharedAccess').call({
  'ownerUID': 'owner-user-id',
  'siteId': 'site-id',
});
```

Only the site owner can call this function.
