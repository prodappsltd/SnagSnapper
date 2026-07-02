# Cloud Functions Best Practices & Retry Safety Guide

> **CRITICAL REFERENCE DOCUMENT**
> All Risk Assessments involving Cloud Functions MUST reference this document.
> Last Updated: 2026-07-02

## Official Sources

This document is based exclusively on official Firebase/Google Cloud documentation:

- [Retry asynchronous functions - Firebase](https://firebase.google.com/docs/functions/retries)
- [Configure event-driven function retries - Google Cloud](https://docs.cloud.google.com/functions/docs/bestpractices/retries)
- [Functions best practices - Google Cloud](https://docs.cloud.google.com/functions/docs/bestpractices/tips)

---

## 1. Retry Behavior: The Facts

### Default Behavior (No `retry: true`)
| Aspect | Behavior |
|--------|----------|
| Function fails | Event is **dropped permanently** |
| Automatic retry | **NO** - must be explicitly enabled |
| Data loss risk | **YES** - failed operations are lost |

### With `retry: true` Enabled
| Aspect | 2nd Gen Functions | 1st Gen Functions |
|--------|-------------------|-------------------|
| Retry window | 24 hours | 7 days |
| Backoff strategy | Exponential: 10s to 600s | Exponential: 10s to 600s |
| Max retries | Until window expires | Until window expires |
| Stop retries | Redeploy or delete function | Redeploy or delete function |

### How to Enable Retry
```javascript
exports.myFunction = onDocumentCreated(
  {
    document: 'Collection/{docId}',
    region: 'europe-west2',
    retry: true,  // Enable retry on failure
  },
  async (event) => {
    // Function code
  }
);
```

### IMPORTANT: No Retry Count Limit

**Firebase does NOT allow limiting the number of retries.** Your only options are:

| Setting | Behavior |
|---------|----------|
| `retry: false` (default) | Event dropped on first failure |
| `retry: true` | Retries for **full 24 hours** (2nd gen) with no count limit |

**Workaround:** Use event age check to create a soft limit (discard events older than X seconds).

**Source:** [Google Developer Forums - No retry config](https://discuss.google.dev/t/why-is-there-no-retry-config-for-cloud-firebase-functions-other-than-scheduled/152175)

---

## 2. When NOT to Enable Retry

Consider **not enabling retry** when:

| Scenario | Reason |
|----------|--------|
| Alternative recovery path exists | User can trigger another CF (e.g., edit triggers onUpdate) |
| Manual recovery is simple | User can re-do the action |
| CF is simple with low failure risk | Transient failures unlikely |
| 24-hour retry storm is unacceptable | Cost/complexity concerns |

**Example decision (SnagSnapper onSiteCreated):**
- Retry NOT enabled
- Recovery: User edits site → triggers `onSiteUpdated` → handles sharing
- Alternative: Owner removes/re-adds collaborator
- Accepted because CF is simple, failures rare, recovery path exists

---

## 3. Risks of Enabling Retry (If You Choose To)

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Infinite Retry Loop** | Permanent errors (bugs) retry for 24 hours | Distinguish transient vs permanent errors |
| **Duplicate Operations** | Same event processed multiple times | Make functions idempotent |
| **Cost Explosion** | Thousands of retries per failed event | Add event age check |
| **Stuck Functions** | Only fix is redeploy/delete | Thorough testing before enabling |
| **Duplicate Emails** | Same notification sent multiple times | Use idempotency keys or tracking |

---

## 4. Requirements BEFORE Enabling Retry

### Checklist
- [ ] Function is idempotent (safe to run multiple times)
- [ ] Event age check implemented (discard stale events)
- [ ] Error types distinguished (transient vs permanent)
- [ ] Thoroughly tested WITHOUT retry enabled
- [ ] External API calls use idempotency keys

---

## 5. Making Functions Idempotent

### Safe (Idempotent) Patterns
```javascript
// GOOD: set() with merge - same result if run multiple times
await docRef.set({ field: value }, { merge: true });

// GOOD: Check before creating
const doc = await docRef.get();
if (doc.exists) {
  console.log('Already processed, skipping');
  return;
}
await docRef.set(data);

// GOOD: Use FieldValue for atomic operations
await docRef.update({
  count: FieldValue.increment(1),  // Idempotent if tracking processed events
});

// GOOD: Delete is naturally idempotent
await docRef.delete();  // Safe to call multiple times
```

### Unsafe (Non-Idempotent) Patterns
```javascript
// BAD: Always creates new document - duplicates on retry!
await collection.add({ data });

// BAD: Array append without checking
await docRef.update({
  items: FieldValue.arrayUnion(newItem),  // May add duplicates
});

// BAD: Sending email without tracking
await sendEmail(recipient, message);  // Duplicate emails on retry!
```

---

## 6. Event Age Check (If Enabling Retry)

Prevents processing stale events after long retry delays:

```javascript
const MAX_EVENT_AGE_MS = 10000; // 10 seconds

exports.myFunction = onDocumentCreated(
  { document: 'Collection/{docId}', retry: true },
  async (event) => {
    // Check event age FIRST
    const eventAgeMs = Date.now() - Date.parse(event.time);

    if (eventAgeMs > MAX_EVENT_AGE_MS) {
      console.log(`Dropping stale event (age: ${eventAgeMs}ms, max: ${MAX_EVENT_AGE_MS}ms)`);
      return; // Return successfully - do NOT throw!
    }

    // Process event...
  }
);
```

---

## 7. Error Type Handling (If Enabling Retry)

Only retry transient errors. Return successfully for permanent errors to stop retry loop:

```javascript
try {
  await doWork();
} catch (error) {
  // TRANSIENT errors - THROW to trigger retry
  const transientCodes = ['ECONNRESET', 'ETIMEDOUT', 'ENOTFOUND', 'EAI_AGAIN'];
  if (transientCodes.includes(error.code)) {
    console.error('Transient error, will retry:', error.message);
    throw error; // Firebase will retry
  }

  // PERMANENT errors - LOG and RETURN (stops retry)
  console.error('Permanent error, not retrying:', error);
  return; // Return successfully to prevent infinite retry
}
```

### Common Error Types

| Error Type | Code | Transient? | Action |
|------------|------|------------|--------|
| Network timeout | ETIMEDOUT | Yes | Throw - retry |
| Connection reset | ECONNRESET | Yes | Throw - retry |
| DNS failure | ENOTFOUND | Maybe | Throw - retry (might resolve) |
| DNS again | EAI_AGAIN | Yes | Throw - retry |
| Deadline exceeded | 4 (gRPC) | Yes | Throw - retry |
| Resource exhausted | 8 (gRPC) | Yes | Throw - retry |
| Service unavailable | 14 (gRPC) | Yes | Throw - retry |
| Not found | 5 (gRPC) | No | Return - don't retry |
| Permission denied | 7 (gRPC) | No | Return - don't retry |
| Invalid argument | 3 (gRPC) | No | Return - don't retry |
| Invalid input data | - | No | Return - don't retry |
| Code bug / TypeError | - | No | Return - don't retry (fix the bug!) |

### IMPORTANT: gRPC Numeric Codes

**nodejs-firestore returns numeric error codes, not strings!**

```javascript
// WRONG - string comparison fails
if (error.code === 'UNAVAILABLE') { ... }  // Won't match!

// CORRECT - numeric comparison
const transientErrors = {
  4: true,   // DEADLINE_EXCEEDED
  8: true,   // RESOURCE_EXHAUSTED
  14: true,  // UNAVAILABLE
};
if (transientErrors[error.code]) { ... }  // Works!
```

**Reference:** [gRPC Status Codes](https://grpc.io/docs/guides/status-codes/)

### NOT_FOUND Handling for Cleanup Operations

When deleting/removing data, NOT_FOUND (code 5) often means "already clean" - treat as success:

```javascript
// Example: Removing site from shared_access during cleanup
accessRef.update({
  [`sites.${siteId}`]: FieldValue.delete(),
}).catch(err => {
  // gRPC NOT_FOUND = 5
  const isNotFound = err.code === 5 ||
                     (err.message && err.message.includes('NOT_FOUND'));
  if (isNotFound) {
    // Document doesn't exist - nothing to delete = success
    console.log('Doc not found, already clean');
    return; // Resolve successfully, don't throw
  }
  throw err; // Re-throw other errors
});
```

**When NOT_FOUND = success:**
- Cleanup operations (deleting entries that may not exist)
- Removing references from documents that were already deleted
- Edge cases where initial creation failed (so nothing to clean up)

---

## 8. External API Idempotency Keys

When calling external APIs that support idempotency keys, use the event ID:

```javascript
// Stripe example
await stripe.charges.create({
  amount: 1000,
  currency: 'usd',
}, {
  idempotencyKey: event.id,  // Prevents duplicate charges
});

// Generic pattern
await externalApi.call({
  idempotencyKey: event.id,
  // ... other params
});
```

---

## 9. Email/Notification Idempotency

Emails are NOT naturally idempotent. Options:

### Option A: Fire-and-Forget (Accept Duplicates)
```javascript
// Don't await, don't throw on failure
// Acceptable if occasional duplicate email is OK
Promise.all(emailPromises).catch((err) => {
  console.log('Some emails failed:', err.message);
  // Don't throw - let function succeed
});
```

### Option B: Track Sent Emails
```javascript
// Check if email already sent for this event
const sentRef = db.collection('sent_emails').doc(`${siteId}_${recipientHash}`);
const sent = await sentRef.get();

if (sent.exists) {
  console.log('Email already sent, skipping');
  return;
}

await sendEmail(recipient, message);
await sentRef.set({ sentAt: FieldValue.serverTimestamp() });
```

---

## 10. Complete Bullet-Proof CF Template (If Enabling Retry)

```javascript
const MAX_EVENT_AGE_MS = 10000; // 10 seconds

exports.bulletProofFunction = onDocumentCreated(
  {
    document: 'Collection/{docId}',
    region: 'europe-west2',
    retry: true,
  },
  async (event) => {
    const functionName = 'bulletProofFunction';

    // 1. EVENT AGE CHECK - Drop stale events
    const eventAgeMs = Date.now() - Date.parse(event.time);
    if (eventAgeMs > MAX_EVENT_AGE_MS) {
      console.log(`[${functionName}] Dropping stale event (age: ${eventAgeMs}ms)`);
      return;
    }

    // 2. EXTRACT DATA
    const data = event.data?.data();
    if (!data) {
      console.log(`[${functionName}] No data in event, skipping`);
      return; // Permanent error - don't retry
    }

    try {
      // 3. IDEMPOTENT OPERATIONS
      await db.collection('target').doc(event.params.docId)
        .set({ processed: true }, { merge: true });

      // 4. FIRE-AND-FORGET FOR NON-CRITICAL OPERATIONS
      sendNotificationEmail(data.email).catch((err) => {
        console.log(`[${functionName}] Email failed (non-blocking):`, err.message);
      });

      console.log(`[${functionName}] Success`);

    } catch (error) {
      // 5. ERROR TYPE HANDLING
      const transientCodes = ['ECONNRESET', 'ETIMEDOUT', 'ENOTFOUND'];

      if (transientCodes.includes(error.code)) {
        console.error(`[${functionName}] Transient error, retrying:`, error.message);
        throw error; // Retry
      }

      console.error(`[${functionName}] Permanent error, not retrying:`, error);
      return; // Don't retry
    }
  }
);
```

---

## 11. Testing Before Enabling Retry

1. **Test WITHOUT `retry: true` first**
2. Simulate all failure scenarios:
   - Network timeouts
   - Invalid input data
   - Missing documents
   - External API failures
3. Verify function handles each correctly
4. Verify no duplicate operations occur
5. **Only then** enable `retry: true`

---

## 12. Recovery When Things Go Wrong

| Scenario | Recovery |
|----------|----------|
| Function stuck in retry loop | Redeploy with fix, or delete function |
| Duplicate data created | Manual cleanup + add idempotency |
| Duplicate emails sent | Accept or add tracking |
| Event dropped (no retry) | Manual re-trigger or accept loss |

---

## 13. RA Integration

When creating Risk Assessments for Cloud Functions, include these items:

| RA Item | Check |
|---------|-------|
| **Retry Decision** | Enable retry or not? Document reasoning. |
| CF Failure/Recovery | If no retry: what's the recovery path? |
| Idempotency | Are all write operations idempotent? |
| Partial Failure | What if some operations succeed, others fail? |
| Error Handling | Transient vs permanent errors distinguished? (if retry enabled) |
| Email/Notification | Duplicate emails acceptable or prevented? |
| Timeout | Can function complete within timeout? |

### Retry Decision Framework

| Question | If YES | If NO |
|----------|--------|-------|
| Does alternative recovery path exist? | Consider no retry | May need retry |
| Is manual recovery simple? | Consider no retry | May need retry |
| Is CF simple with low failure risk? | Consider no retry | May need retry |
| Is 24-hour retry storm acceptable? | Can enable retry | Don't enable retry |
| Are idempotency safeguards in place? | Can enable retry | Don't enable retry |

---

## Document History

| Date | Change |
|------|--------|
| 2026-06-19 | Initial creation based on official Firebase/Google Cloud docs |
| 2026-06-20 | Added "When NOT to Enable Retry" section, retry decision framework, no retry limit info |
| 2026-07-02 | Added gRPC numeric error codes (nodejs-firestore returns numbers, not strings). Added NOT_FOUND handling pattern for cleanup operations. |