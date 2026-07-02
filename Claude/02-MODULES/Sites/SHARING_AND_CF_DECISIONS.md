# Site Sharing & Cloud Functions - Decision Log

**Version:** 1.2.0
**Last Updated:** 2026-07-02
**Status:** In Progress (Security Model Finalized)

**Related Documents:**
- [Sharing Architecture](../../00-CORE/SHARING_ARCHITECTURE.md) - Permission levels, data structure, flows
- [Snag Sync & Cost Analysis](../Snags/SNAG_SYNC_AND_COST.md) - Manifest-based sync for shared sites

---

## Overview

This document tracks decisions related to site sharing functionality and Cloud Function error handling.

---

## Sharing Flow

### Step-by-Step

```
1. User A (owner) opens Site X settings
2. User A taps "Share"
3. User A enters: userB@example.com, selects CONTRIBUTOR
4. User A taps Save

5. Local database updates:
   Site.sharedWith = { "userb@example.com": "CONTRIBUTOR" }
   Site.needsSiteSync = true

6. Background sync creates/updates Site document in Firestore:
   Path: Profile/{userA_UID}/Sites/{siteId}
   Data: { sharedWith: {...}, ...otherFields }

7. CF triggers: onSiteCreated (new site) OR onSiteUpdated (existing site)
   - Detects userB@example.com added to sharedWith
   - Updates shared_access/{userB_email_hash}:
     Step 1: set({ email }, { merge: true })
     Step 2: update({ "sites.{siteId}": ownerUID })
   - Sends email notification via AWS SES (fire-and-forget)

8. Result: User B can now see Site X in shared sites
```

**Cloud Functions (functions/index.js):**
- `onSiteCreated` (lines 97-234) - New site with initial sharedWith
- `onSiteUpdated` (lines 240-487) - Existing site, sharedWith changed (**retry: true**)
- `onSiteDeleted` (lines 493-626) - Cleanup shared_access entries (**retry: true**)

---

## Cloud Function: onSiteSharedWithUpdated

### Purpose

```
Trigger: Site document's sharedWith field changes
Action: Update shared_access document for affected user
```

### Failure Handling

| Function | Retry | Recovery |
|----------|-------|----------|
| `onSiteCreated` | No | User edits site → triggers `onSiteUpdated` |
| `onSiteUpdated` | **Yes (30s)** | Auto-retry handles transient failures |
| `onSiteDeleted` | **Yes (30s)** | Auto-retry handles transient failures |

**Why 30 seconds?** Event age check drops events older than 30s. This allows 1-2 transient retries (first retry ~10s with exponential backoff) while preventing runaway billing.

### Retry Protection (onSiteUpdated & onSiteDeleted)

```
Event triggers CF
       │
       ▼
Event age < 30s? ──No──→ Drop event (return successfully)
       │
      Yes
       ▼
Process event
       │
       ▼
Success? ──Yes──→ Done
       │
       No
       ▼
Transient error? ──Yes──→ Throw → Firebase retries
       │
       No
       ▼
Permanent error → Log and return (stop retry)
```

### Manual Recovery (if all retries fail)

| Scenario | Recovery |
|----------|----------|
| Share not propagated | Owner removes and re-adds collaborator |
| Orphaned shared_access | Admin cleanup (rare edge case) |

---

## Health Check Strategy

Sharing CF errors are handled differently from manifest errors:

| Aspect | Manifest CF | Sharing CF |
|--------|-------------|------------|
| Health check | Scheduled (every 5 min) | Not included |
| Auto-recovery | Yes (server-controlled) | No |
| Manual recovery | Not needed | Remove + re-add |
| Rationale | Affects all syncs | Rare, easy manual fix |

### Future Consideration

If sharing failures become common, add to health check:

```
FOR EACH site:
  FOR EACH email in site.sharedWith:
    Check: Does shared_access/{emailHash} include this site?
    If not → CF failed → Fix it
```

**Current decision:** Not needed. Monitor and revisit if issues arise.

---

## Security Model - Sharing Cloud Functions

### Overview

The sharing CF (`onSiteCreated`, `onSiteUpdated`, `onSiteDeleted`) is protected by 5 layers of security, making automated abuse impossible.

### Security Layers

```
Layer 1: freeRASP (Planned)
  └── Blocks: Emulators, VMs, rooted/jailbroken devices,
              Frida hooks, tampering, debuggers

Layer 2: Firebase App Check
  └── Blocks: Requests not from legitimate app binary
              Device attestation (DeviceCheck iOS / Play Integrity Android)

Layer 3: Firebase Authentication
  └── Blocks: Unauthenticated requests

Layer 4: Firestore Security Rules
  └── Enforces: Only owner can write to their Site document

Layer 5: CF-Only Writes
  └── Enforces: Only CF can write to shared_access
              (client write: false in Firestore rules)
```

### Attack Scenarios - All Blocked

| Attack | Blocked By |
|--------|------------|
| Bot/script spamming | freeRASP + App Check |
| Emulator attack | freeRASP + App Check |
| VM attack | freeRASP |
| Frida/hooking | freeRASP |
| Modified APK | App Check + freeRASP |
| Unauthenticated request | Firebase Auth |
| Modify another user's site | Firestore Rules |
| Write directly to shared_access | Firestore Rules |

### Why Rate Limiting is NOT Required

| Reason | Explanation |
|--------|-------------|
| Automated attacks impossible | freeRASP + App Check block all non-legitimate requests |
| Manual spam self-limiting | Human speed, tedious, pointless (own data only) |
| Cost negligible | ~$0.10 per 1000 abuse cycles |
| Owner pays anyway | PRO/BUSINESS tier required to share |

### Client-Side Controls

Tier validation and share limits are enforced client-side. This is acceptable because:
- 5 security layers prevent bypass attempts
- Worst case: user shares beyond limit on their OWN data
- Server-side audit can be added later if needed

---

## Decisions Log

| Date | Decision | Rationale | RA Ref |
|------|----------|-----------|--------|
| 2026-06-10 | No refresh button for sharing | Rare failure, manual remove/re-add is acceptable | RA 1.11 |
| 2026-06-10 | No health check for sharing CF | Low failure rate, easy manual recovery | RA 1.11 |
| 2026-06-10 | Admin notified only for system-wide issues | Individual failures handled by users | RA 1.11 |
| 2026-06-10 | No rate limiting on sharing CF | 5-layer security makes automated abuse impossible | RA 1.7 |
| 2026-06-10 | Client-side tier/share limit enforcement | Protected by security layers; server audit can be added later | - |
| 2026-06-10 | freeRASP for device security | Blocks emulators, VMs, root, jailbreak, Frida, tampering | - |
| 2026-06-10 | Split WORKING into WORKING_SEE_ALL / WORKING_SEE_SELF | Per-worker visibility control, simpler rules than site setting | - |
| 2026-06-10 | Removed canView function | Renamed to isCollaborator for clarity (VIEW is a permission type) | - |
| 2026-06-14 | 30 collaborator limit | Prevents DoS via payload size | RA 1.6 |
| 2026-06-14 | Full email logging | Admins only, aids troubleshooting | RA 1.10 |
| 2026-06-14 | Self-share prevention in Firestore rules | Owner can't add themselves to sharedWith; validated server-side | RA 2.6 |
| 2026-06-14 | Sync button 30s cooldown | Prevents rapid sync abuse; stored in service singleton | RA 4.9 |
| 2026-06-14 | Version-based sync in shared_access | CF stores `{ ownerUID, version }`. Client compares versions before fetching (shared_site_service.dart:244-254). Orphan cleanup removes unshared sites (lines 362-374). | RA 4.10, RA 2.7 |
| 2026-07-02 | Enable retry on onSiteUpdated | 30s event age check + transient/permanent error handling. Ensures share removal propagates. | RA 2.7-2.13 |
| 2026-07-02 | Enable retry on onSiteDeleted | 30s event age check + transient/permanent error handling. Prevents orphaned shared_access entries. | RA 3.2-3.3 |
| 2026-07-02 | Version check prevents 404 self-clean | Client skips Firestore fetch when local version >= remote. If CF fails completely, orphaned entries persist (no automatic cleanup). Accepted edge case. | RA 3.2-3.3 |
| 2026-07-02 | gRPC numeric error codes | nodejs-firestore returns numeric codes (4=DEADLINE_EXCEEDED, 8=RESOURCE_EXHAUSTED, 14=UNAVAILABLE), not strings. Error handling updated. | - |
| 2026-07-02 | NOT_FOUND = success for removals | When removing shared_access entry, NOT_FOUND (code 5) is treated as success - nothing to delete means already clean. | RA 3.3 |

---

## TODO

- [ ] Implement freeRASP integration for device security
- [ ] Continue documenting User B sync flow (Step 2)
- [ ] Document manifest download and comparison (Step 3-4)
- [ ] Document signed URL request flow
- [ ] **Snag version-based sync**: Currently snags are always fetched (no version comparison like sites). Should store snag versions in shared_access or use manifest approach. Also need to handle snag deletion sync (local snags not in remote should be deleted). Out of scope for initial release.
- [ ] **Deletion & Asset Cleanup (RA 6.1-6.5)**:
  - RA 6.1-6.2: Collaborator local image cleanup when access revoked
  - RA 6.3: Owner Firebase document deletion (site + snags)
  - RA 6.4: Owner Firebase Storage cleanup (site + snag images)
  - RA 6.5: Owner local image cleanup on hard delete

## Completed

- [x] Orphaned site pointer cleanup (RA 2.7): If site not in shared_access, orphan cleanup removes local copy (lines 370-381).
- [x] Version-based sync client-side (RA 4.10): Client compares local vs remote versions before fetching (lines 244-254). Skips fetch if local >= remote.
- [x] Race condition fix (RA 4.8): If user removed from sharedWith but CF hasn't updated shared_access yet, delete local copy when fetching site (lines 284-297).
- [x] Retry enabled on onSiteUpdated (RA 2.7-2.13): 30s event age check, transient/permanent error handling, deferred email execution.
- [x] Retry enabled on onSiteDeleted (RA 3.2-3.3): 30s event age check, transient/permanent error handling, NOT_FOUND = success.

### Important Note: Version Check Limitation

Client's version check (line 247) skips Firestore fetch when `local >= remote`. This means:
- If `onSiteDeleted` fails **completely** (all retries exhausted), the `shared_access` entry persists
- Client sees same version → skips fetch → never discovers site was deleted
- **No automatic 404 self-cleaning** - orphaned entries require admin cleanup
- This is an accepted edge case (retry handles most failures)

---

## Document History

| Date | Version | Change |
|------|---------|--------|
| 2026-06-10 | 1.0.0 | Initial document - sharing flow and CF failure handling |
| 2026-06-10 | 1.1.0 | Added 5-layer security model, rate limiting decision, freeRASP planned |
| 2026-07-02 | 1.2.0 | Enabled retry on onSiteUpdated/onSiteDeleted with 30s event age check. Documented version check limitation (no 404 self-clean). Updated CF line numbers. Added gRPC numeric codes decision. |

---

*This document tracks sharing-related decisions for SnagSnapper.*
