/**
 * SnagSnapper Cloud Functions (2nd Gen)
 *
 * Handles site sharing by maintaining a reverse index for efficient discovery.
 * When a site's sharedWith field changes, these functions update the
 * shared_access collection so collaborators can quickly find sites shared with them.
 *
 * Architecture (Profile-centric):
 * - /Profile/{ownerUID}/Sites/{siteId} - Site documents with sharedWith map
 * - /shared_access/{emailHash} - Single document per user for discovery
 *   - Contains: { email, sites: { siteId: ownerUID, ... } }
 *
 * Security:
 * - shared_access documents include email field for rule verification
 * - Firestore rules verify email == request.auth.token.email on get()
 * - Single document structure enables secure get() instead of list() query
 * - Only the owner of an email can read their shared_access document
 *
 * See: Claude/00-CORE/SHARING_ARCHITECTURE.md
 */

const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { SESClient, SendEmailCommand } = require('@aws-sdk/client-ses');
const crypto = require('crypto');

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// ============================================================================
// CONFIGURATION
// ============================================================================

const REGION = 'europe-west2'; // London region for UK users

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Hash email for use as document ID.
 * SHA256 produces consistent, collision-resistant 64-char hex string.
 * Email is normalized (lowercase, trimmed) before hashing.
 *
 * @param {string} email - Email address to hash
 * @returns {string} 64-character hex hash
 */
function hashEmail(email) {
  if (!email || typeof email !== 'string') {
    throw new Error('Invalid email for hashing');
  }
  return crypto
    .createHash('sha256')
    .update(email.toLowerCase().trim())
    .digest('hex');
}

/**
 * Validate permission level
 * @param {string} permission - Permission to validate
 * @returns {boolean} True if valid
 *
 * Permission levels:
 * - VIEW: Read-only, can see all snags
 * - WORKING_SEE_ALL: Can see all snags, edit only assigned
 * - WORKING_SEE_SELF: Can only see and edit assigned snags
 * - CONTRIBUTOR: Can create snags, edit all snags
 */
function isValidPermission(permission) {
  const validPermissions = ['VIEW', 'WORKING_SEE_ALL', 'WORKING_SEE_SELF', 'CONTRIBUTOR'];
  return validPermissions.includes(permission);
}

/**
 * Validate email format
 * @param {string} email - Email to validate
 * @returns {boolean} True if valid email format
 */
function isValidEmail(email) {
  if (!email || typeof email !== 'string') return false;
  // Tightened email regex (2026 best practice):
  // - Allows + tags (user+newsletter@gmail.com)
  // - Allows long TLDs (.museum, .technology)
  // - Rejects: consecutive dots, dot before/after @, domain segments starting/ending with hyphen
  // - Synced with UI validation in share_site_dialog.dart
  // Negative lookaheads:
  //   (?!.*\.\.) - no consecutive dots
  //   (?!.*\.@)  - no dot before @
  //   (?!.*@\.)  - no dot after @
  //   (?!.*@-)   - no hyphen after @
  //   (?!.*-\.)  - no hyphen before dot (segment ending with hyphen)
  //   (?!.*\.-)  - no dot before hyphen (segment starting with hyphen)
  const emailRegex = /^(?!.*\.\.)(?!.*\.@)(?!.*@\.)(?!.*@-)(?!.*-\.)(?!.*\.-)[a-zA-Z0-9][a-zA-Z0-9._%+-]*@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$/;
  return emailRegex.test(email.trim());
}

 /**
 * Escape HTML special characters to prevent XSS in emails
 * @param {string} text - Text to escape
 * @returns {string} Escaped text safe for HTML insertion
 */
function escapeHtml(text) {
  if (!text || typeof text !== 'string') return '';
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/**
 * Log with consistent formatting
 * @param {string} functionName - Name of the function
 * @param {string} message - Log message
 * @param {object} data - Optional data to log
 */
function log(functionName, message, data = null) {
  const logEntry = {
    function: functionName,
    message,
    timestamp: new Date().toISOString(),
  };
  if (data) {
    logEntry.data = data;
  }
  console.log(JSON.stringify(logEntry));
}

// ============================================================================
// CLOUD FUNCTIONS (2nd Gen)
// ============================================================================

// ============================================================================
// DISABLED: onSiteCreated
// ============================================================================
// Reason: UI does not allow sharing during site creation. Sites are always
// created with empty sharedWith map. Sharing only happens via site update,
// which triggers onSiteUpdated. This function would never process any
// collaborators in practice, so it's disabled to avoid unnecessary CF costs.
//
// Kept for reference in case sharing-at-creation is added in the future.
// To re-enable: uncomment the exports.onSiteCreated line below.
// ============================================================================

/*
exports.onSiteCreated = onDocumentCreated(
  {
    document: 'Profile/{ownerUID}/Sites/{siteId}',
    region: REGION,
    secrets: ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY'],
  },
  async (event) => {
    const functionName = 'onSiteCreated';
    const { ownerUID, siteId } = event.params;

    try {
      const data = event.data?.data();
      if (!data) {
        log(functionName, 'No data in created document', { siteId });
        return;
      }

      const sharedWith = data.sharedWith || {};
      const siteName = data.name || 'Untitled Site';
      const ownerName = data.ownerName || data.ownerEmail || 'Site Owner';

      if (Object.keys(sharedWith).length === 0) {
        log(functionName, 'No collaborators to process', { siteId });
        return;
      }

      log(functionName, 'Processing new site with collaborators', {
        siteId,
        ownerUID,
        siteName,
        collaboratorCount: Object.keys(sharedWith).length,
      });

      const emailPromises = [];
      const updatePromises = [];

      for (const [email, permission] of Object.entries(sharedWith)) {
        if (!isValidEmail(email)) {
          log(functionName, 'Skipping invalid email format', { email: email });
          continue;
        }

        if (!isValidPermission(permission)) {
          log(functionName, 'Skipping invalid permission', { email: email, permission });
          continue;
        }

        const emailHash = hashEmail(email);
        const accessRef = db.collection('shared_access').doc(emailHash);

        // Two-step approach: set() with merge doesn't interpret dots as nested paths
        // Step 1: Ensure document exists with email field
        // Step 2: Use update() which correctly interprets dots as nested paths
        // Store ownerUID + version for efficient client-side sync (RA 4.10)
        const siteVersion = data.firebaseVersion || 0;
        updatePromises.push(
          accessRef.set({ email: email.toLowerCase().trim() }, { merge: true })
            .then(() => accessRef.update({
              [`sites.${siteId}`]: { ownerUID, version: siteVersion }
            }))
        );

        // Queue email notification
        emailPromises.push(sendSiteSharedEmail(email, siteName, ownerName, permission));

        log(functionName, 'Queued shared_access update', { email: email, siteId, version: siteVersion });
      }

      await Promise.all(updatePromises);
      log(functionName, 'Successfully updated shared_access documents', { siteId });

      // Send all emails in parallel (don't await - fire and forget)
      Promise.all(emailPromises).then(() => {
        log(functionName, 'All share notification emails sent', { siteId });
      }).catch((err) => {
        log(functionName, 'Some share notification emails failed', { siteId, error: err.message });
      });

    } catch (error) {
      console.error(`${functionName} error:`, error);
      throw error;
    }
  }
);
*/

/**
 * Triggered when a site's sharedWith field changes.
 * Creates/deletes shared_access entries accordingly.
 */
exports.onSiteUpdated = onDocumentUpdated(
  {
    document: 'Profile/{ownerUID}/Sites/{siteId}',
    region: REGION,
    secrets: ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY'],
    // RETRY ENABLED: Ensures share removal propagates even if CF fails transiently
    // Safe because: event age check (30s), deferred emails, transient/permanent error handling
    // See: Claude/00-CORE/CLOUD_FUNCTIONS_BEST_PRACTICES.md
    retry: true,
  },
  async (event) => {
    const functionName = 'onSiteUpdated';

    // =========================================================================
    // EVENT AGE CHECK - MUST BE FIRST, before ANY code that could throw
    // =========================================================================
    // If this check isn't first, an error before it could cause infinite retries.
    // 30 seconds allows 1-2 transient retries (first retry ~10s with exponential backoff)
    // but prevents processing events that are too old to be relevant.
    // =========================================================================
    const MAX_EVENT_AGE_MS = 30000;
    const eventTimestamp = Date.parse(event.time);
    const eventAgeMs = Date.now() - eventTimestamp;

    // If event.time is invalid (NaN) or event is stale, drop it to prevent retry storms
    if (isNaN(eventAgeMs) || eventAgeMs > MAX_EVENT_AGE_MS) {
      log(functionName, 'Dropping stale/invalid event', {
        siteId: event.params?.siteId || 'unknown',  // Safe access - don't throw here
        eventAgeMs: isNaN(eventAgeMs) ? 'INVALID' : eventAgeMs,
        eventTime: event.time,
        maxAge: MAX_EVENT_AGE_MS,
      });
      return; // Return successfully - don't throw to avoid more retries
    }

    // Safe to destructure now - age check has passed
    const { ownerUID, siteId } = event.params;

    try {
      const beforeData = event.data?.before?.data();
      const afterData = event.data?.after?.data();

      if (!beforeData || !afterData) {
        log(functionName, 'Missing before/after data', { siteId });
        return;
      }

      const beforeShared = beforeData.sharedWith || {};
      const afterShared = afterData.sharedWith || {};
      const siteName = afterData.name || 'Untitled Site';
      const ownerName = afterData.ownerName || afterData.ownerEmail || 'Site Owner';

      // Check if sharedWith changed
      const sharedWithChanged = JSON.stringify(beforeShared) !== JSON.stringify(afterShared);
      const siteVersion = afterData.firebaseVersion || 0;
      const beforeVersion = beforeData.firebaseVersion || 0;
      const versionChanged = siteVersion !== beforeVersion;

      if (!sharedWithChanged && !versionChanged) {
        // No relevant changes for shared_access
        return;
      }

      log(functionName, 'Processing site update', {
        siteId,
        ownerUID,
        siteName,
        beforeCount: Object.keys(beforeShared).length,
        afterCount: Object.keys(afterShared).length,
      });

      // DEFERRED EMAILS: Store email data (not promises) to avoid starting emails
      // before Firestore operations succeed. This prevents duplicate emails on retry.
      const emailsToSend = [];
      const updatePromises = [];
      let operationCount = 0;

      // Find added shares
      for (const [email, permission] of Object.entries(afterShared)) {
        if (!beforeShared[email]) {
          // New share - add site to user's shared_access document
          if (!isValidEmail(email)) {
            log(functionName, 'Skipping invalid email format for new share', { email: email });
            continue;
          }

          if (!isValidPermission(permission)) {
            log(functionName, 'Skipping invalid permission for new share', { permission });
            continue;
          }

          const emailHash = hashEmail(email);
          const accessRef = db.collection('shared_access').doc(emailHash);

          // Two-step approach: set() with merge doesn't interpret dots as nested paths
          // Step 1: Ensure document exists with email field
          // Step 2: Use update() which correctly interprets dots as nested paths
          // Store ownerUID + version for efficient client-side sync (RA 4.10)
          updatePromises.push(
            accessRef.set({ email: email.toLowerCase().trim() }, { merge: true })
              .then(() => accessRef.update({
                [`sites.${siteId}`]: { ownerUID, version: siteVersion }
              }))
          );

          // Queue email data for new collaborators (deferred until Firestore success)
          emailsToSend.push({ email, siteName, ownerName, permission });

          operationCount++;
          log(functionName, 'Queued new share + email', { email: email, version: siteVersion });
        } else if (versionChanged) {
          // Existing user - update version only
          // Validate email for safety (in case of DB corruption)
          if (!isValidEmail(email)) {
            log(functionName, 'Skipping invalid email in existing share', { email: email });
            continue;
          }

          const emailHash = hashEmail(email);
          const accessRef = db.collection('shared_access').doc(emailHash);

          // Try update first (normal path - 1 write)
          // If doc doesn't exist (edge case), fall back to set+update (2 writes)
          // gRPC status codes: https://grpc.github.io/grpc/core/md_doc_statuscodes.html
          // NOT_FOUND = 5 (numeric, not string)
          updatePromises.push(
            accessRef.update({
              [`sites.${siteId}`]: { ownerUID, version: siteVersion }
            }).catch(err => {
              // Check for gRPC NOT_FOUND (code 5) - document doesn't exist
              const isNotFound = err.code === 5 ||
                                 (err.message && err.message.includes('NOT_FOUND'));
              if (isNotFound) {
                log(functionName, 'shared_access doc missing for existing user, recreating', { email: email });
                return accessRef.set({ email: email.toLowerCase().trim() }, { merge: true })
                  .then(() => accessRef.update({
                    [`sites.${siteId}`]: { ownerUID, version: siteVersion }
                  }));
              }
              throw err; // Re-throw other errors
            })
          );

          operationCount++;
          log(functionName, 'Queued version update for existing share', { email: email, version: siteVersion });
        }
        // Note: Permission changes don't require shared_access updates
        // since we only store ownerUID (permission is read from site document)
      }

      // Find removed shares
      for (const email of Object.keys(beforeShared)) {
        if (!afterShared[email]) {
          // Share removed - delete site entry from user's shared_access document
          const emailHash = hashEmail(email);
          const accessRef = db.collection('shared_access').doc(emailHash);

          // Delete the specific site entry from the sites map
          // Handle NOT_FOUND gracefully - can occur if:
          //   1. Initial share creation failed and retries timed out (>30s)
          //      → sharedWith has user, but shared_access doc was never created
          //   2. Admin manually deleted the shared_access document
          // In both cases, nothing to clean up = success
          // gRPC NOT_FOUND = 5
          updatePromises.push(
            accessRef.update({
              [`sites.${siteId}`]: FieldValue.delete(),
            }).catch(err => {
              const isNotFound = err.code === 5 ||
                                 (err.message && err.message.includes('NOT_FOUND'));
              if (isNotFound) {
                // Document doesn't exist - nothing to delete, this is success
                log(functionName, 'shared_access doc not found during removal, already clean', { email });
                return;
              }
              throw err; // Re-throw other errors
            })
          );

          operationCount++;
          log(functionName, 'Queued share removal', { email: email });
        }
      }

      if (operationCount > 0) {
        await Promise.all(updatePromises);
        log(functionName, 'Successfully processed site update', {
          siteId,
          operationCount,
        });

        // DEFERRED EMAILS: Only start emails AFTER Firestore operations succeed
        // This ensures emails are only sent once even if function retries
        if (emailsToSend.length > 0) {
          Promise.all(emailsToSend.map(e =>
            sendSiteSharedEmail(e.email, e.siteName, e.ownerName, e.permission)
          )).then(() => {
            log(functionName, 'All share notification emails sent', { siteId, emailCount: emailsToSend.length });
          }).catch((err) => {
            log(functionName, 'Some share notification emails failed', { siteId, error: err.message });
          });
        }
      } else {
        log(functionName, 'No operations needed', { siteId });
      }

    } catch (error) {
      // TRANSIENT VS PERMANENT ERROR HANDLING
      // Transient errors should retry; permanent errors should log and return
      // to prevent infinite retry loops
      //
      // gRPC numeric codes (from nodejs-firestore):
      // https://github.com/googleapis/nodejs-firestore/issues/1239
      // https://grpc.io/docs/guides/status-codes/
      const transientErrors = {
        // Network errors (string codes from Node.js)
        'ECONNRESET': true,
        'ETIMEDOUT': true,
        'ENOTFOUND': true,
        'EAI_AGAIN': true,
        // gRPC transient errors (numeric codes from Firestore)
        4: true,   // DEADLINE_EXCEEDED
        8: true,   // RESOURCE_EXHAUSTED
        14: true,  // UNAVAILABLE
      };

      const isTransient = transientErrors[error.code] ||
        (error.message && (
          error.message.includes('UNAVAILABLE') ||
          error.message.includes('DEADLINE_EXCEEDED') ||
          error.message.includes('RESOURCE_EXHAUSTED') ||
          error.message.includes('ECONNRESET') ||
          error.message.includes('ETIMEDOUT')
        ));

      if (isTransient) {
        // Transient error - throw to trigger retry
        console.error(`${functionName} transient error, will retry:`, error);
        throw error;
      }

      // Permanent error - log and return to stop retry cycle
      // Examples: PERMISSION_DENIED (7), INVALID_ARGUMENT (3), NOT_FOUND (5)
      console.error(`${functionName} permanent error, not retrying:`, error);
      return;
    }
  }
);

/**
 * Triggered when a site is deleted.
 * Removes all shared_access entries for that site.
 */
exports.onSiteDeleted = onDocumentDeleted(
  {
    document: 'Profile/{ownerUID}/Sites/{siteId}',
    region: REGION,
    // RETRY ENABLED: Ensures orphaned shared_access entries are cleaned up
    // even if CF fails transiently. Critical for security (prevents stale access).
    // See: Claude/00-CORE/CLOUD_FUNCTIONS_BEST_PRACTICES.md
    retry: true,
  },
  async (event) => {
    const functionName = 'onSiteDeleted';

    // =========================================================================
    // EVENT AGE CHECK - MUST BE FIRST, before ANY code that could throw
    // =========================================================================
    // If this check isn't first, an error before it could cause infinite retries.
    // 30 seconds allows 1-2 transient retries (first retry ~10s with exponential backoff).
    // =========================================================================
    const MAX_EVENT_AGE_MS = 30000;
    const eventTimestamp = Date.parse(event.time);
    const eventAgeMs = Date.now() - eventTimestamp;

    // If event.time is invalid (NaN) or event is stale, drop it to prevent retry storms
    if (isNaN(eventAgeMs) || eventAgeMs > MAX_EVENT_AGE_MS) {
      log(functionName, 'Dropping stale/invalid event', {
        siteId: event.params?.siteId || 'unknown',  // Safe access - don't throw here
        eventAgeMs: isNaN(eventAgeMs) ? 'INVALID' : eventAgeMs,
        eventTime: event.time,
        maxAge: MAX_EVENT_AGE_MS,
      });
      return; // Return successfully - don't throw to avoid more retries
    }

    // Safe to destructure now - age check has passed
    const { ownerUID, siteId } = event.params;

    try {
      const data = event.data?.data();
      if (!data) {
        log(functionName, 'No data in deleted document', { siteId });
        return;
      }

      const sharedWith = data.sharedWith || {};
      const collaboratorCount = Object.keys(sharedWith).length;

      if (collaboratorCount === 0) {
        log(functionName, 'No shared_access entries to clean up', { siteId });
        return;
      }

      log(functionName, 'Cleaning up shared_access for deleted site', {
        siteId,
        ownerUID,
        collaboratorCount,
      });

      const updatePromises = [];

      for (const email of Object.keys(sharedWith)) {
        const emailHash = hashEmail(email);
        const accessRef = db.collection('shared_access').doc(emailHash);

        // Delete the specific site entry from the sites map
        // Handle NOT_FOUND gracefully - can occur if:
        //   1. Initial share creation failed and retries timed out (>30s)
        //      → sharedWith has user, but shared_access doc was never created
        //   2. Admin manually deleted the shared_access document
        // In both cases, nothing to clean up = success
        // gRPC NOT_FOUND = 5
        updatePromises.push(
          accessRef.update({
            [`sites.${siteId}`]: FieldValue.delete(),
          }).catch(err => {
            const isNotFound = err.code === 5 ||
                               (err.message && err.message.includes('NOT_FOUND'));
            if (isNotFound) {
              // Document doesn't exist - nothing to delete, this is success
              log(functionName, 'shared_access doc not found, already clean', { email });
              return;
            }
            throw err; // Re-throw other errors
          })
        );
        log(functionName, 'Queued shared_access site removal', { email: email });
      }

      await Promise.all(updatePromises);
      log(functionName, 'Successfully cleaned up shared_access', {
        siteId,
        removedCount: collaboratorCount,
      });

    } catch (error) {
      // TRANSIENT VS PERMANENT ERROR HANDLING
      // Transient errors should retry; permanent errors should log and return
      //
      // gRPC numeric codes (from nodejs-firestore):
      // https://github.com/googleapis/nodejs-firestore/issues/1239
      // https://grpc.io/docs/guides/status-codes/
      const transientErrors = {
        // Network errors (string codes from Node.js)
        'ECONNRESET': true,
        'ETIMEDOUT': true,
        'ENOTFOUND': true,
        'EAI_AGAIN': true,
        // gRPC transient errors (numeric codes from Firestore)
        4: true,   // DEADLINE_EXCEEDED
        8: true,   // RESOURCE_EXHAUSTED
        14: true,  // UNAVAILABLE
      };

      const isTransient = transientErrors[error.code] ||
        (error.message && (
          error.message.includes('UNAVAILABLE') ||
          error.message.includes('DEADLINE_EXCEEDED') ||
          error.message.includes('RESOURCE_EXHAUSTED') ||
          error.message.includes('ECONNRESET') ||
          error.message.includes('ETIMEDOUT')
        ));

      if (isTransient) {
        // Transient error - throw to trigger retry
        console.error(`${functionName} transient error, will retry:`, error);
        throw error;
      }

      // Permanent error - log and return to stop retry cycle
      // Examples: PERMISSION_DENIED (7), INVALID_ARGUMENT (3)
      console.error(`${functionName} permanent error, not retrying:`, error);
      return;
    }
  }
);

// ============================================================================
// SITE SHARED EMAIL FUNCTION
// ============================================================================

/**
 * Generate stunning HTML email for site sharing notification
 * @param {string} siteName - Name of the shared site
 * @param {string} ownerName - Name of the site owner
 * @param {string} permission - Permission level (VIEW, WORKING, CONTRIBUTOR)
 * @returns {string} HTML email content
 */
function generateSiteSharedEmailHTML(siteName, ownerName, permission) {
  const permissionDescriptions = {
    'VIEW': 'View all snags and reports',
    'WORKING': 'Work on snags assigned to you',
    'CONTRIBUTOR': 'Create and manage snags',
  };

  const permissionIcons = {
    'VIEW': '👁️',
    'WORKING': '🔧',
    'CONTRIBUTOR': '✏️',
  };

  const permissionDesc = permissionDescriptions[permission] || 'Access the site';
  const permissionIcon = permissionIcons[permission] || '🔑';

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Site Shared With You - SnagSnapper</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #0f0f23;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background: linear-gradient(180deg, #0f0f23 0%, #1a1a3e 100%); padding: 40px 20px;">
    <tr>
      <td align="center">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="background: #ffffff; border-radius: 24px; box-shadow: 0 25px 80px rgba(102, 126, 234, 0.4); overflow: hidden;">

          <!-- Animated Header with Glow Effect -->
          <tr>
            <td style="background: linear-gradient(135deg, #667eea 0%, #764ba2 50%, #f093fb 100%); padding: 50px 40px; text-align: center; position: relative;">
              <div style="font-size: 64px; margin-bottom: 15px; filter: drop-shadow(0 0 20px rgba(255,255,255,0.5));">
                🏗️
              </div>
              <h1 style="margin: 0; font-size: 28px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px; text-shadow: 0 2px 10px rgba(0,0,0,0.2);">
                You've Been Invited!
              </h1>
              <p style="margin: 12px 0 0; font-size: 16px; color: rgba(255,255,255,0.9); font-weight: 500;">
                A construction site has been shared with you
              </p>
            </td>
          </tr>

          <!-- Site Card with Glass Effect -->
          <tr>
            <td style="padding: 40px;">
              <div style="background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 20px; padding: 35px; text-align: center; box-shadow: 0 10px 40px rgba(0,0,0,0.15);">

                <!-- Site Icon -->
                <div style="width: 80px; height: 80px; margin: 0 auto 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 20px; display: flex; align-items: center; justify-content: center; box-shadow: 0 10px 30px rgba(102, 126, 234, 0.4);">
                  <span style="font-size: 40px; line-height: 80px;">📍</span>
                </div>

                <!-- Site Name -->
                <h2 style="margin: 0 0 8px; font-size: 26px; font-weight: 700; color: #ffffff; letter-spacing: -0.5px;">
                  ${escapeHtml(siteName) || 'New Site'}
                </h2>

                <!-- Owner Info -->
                <p style="margin: 0 0 25px; font-size: 15px; color: #a0aec0;">
                  Shared by <strong style="color: #667eea;">${escapeHtml(ownerName) || 'Site Owner'}</strong>
                </p>

                <!-- Permission Badge -->
                <div style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 50px; padding: 12px 28px; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);">
                  <span style="font-size: 18px; vertical-align: middle;">${permissionIcon}</span>
                  <span style="font-size: 14px; font-weight: 700; color: #ffffff; text-transform: uppercase; letter-spacing: 1px; vertical-align: middle; margin-left: 8px;">
                    ${permission}
                  </span>
                </div>

                <p style="margin: 20px 0 0; font-size: 14px; color: #718096;">
                  ${permissionDesc}
                </p>
              </div>
            </td>
          </tr>

          <!-- Action Steps -->
          <tr>
            <td style="padding: 0 40px 40px;">
              <h3 style="margin: 0 0 25px; font-size: 18px; font-weight: 700; color: #1a202c; text-align: center;">
                Get Started in 3 Easy Steps
              </h3>

              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <!-- Step 1 -->
                <tr>
                  <td style="padding: 12px 0;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                      <tr>
                        <td width="50" style="vertical-align: top;">
                          <div style="width: 44px; height: 44px; background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%); border-radius: 12px; text-align: center; line-height: 44px; font-size: 18px; font-weight: 800; color: #ffffff; box-shadow: 0 4px 15px rgba(67, 233, 123, 0.3);">1</div>
                        </td>
                        <td style="padding-left: 15px; vertical-align: middle;">
                          <p style="margin: 0; font-size: 15px; font-weight: 600; color: #2d3748;">Open SnagSnapper App</p>
                          <p style="margin: 4px 0 0; font-size: 13px; color: #718096;">Launch the app on your device</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- Step 2 -->
                <tr>
                  <td style="padding: 12px 0;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                      <tr>
                        <td width="50" style="vertical-align: top;">
                          <div style="width: 44px; height: 44px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px; text-align: center; line-height: 44px; font-size: 18px; font-weight: 800; color: #ffffff; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);">2</div>
                        </td>
                        <td style="padding-left: 15px; vertical-align: middle;">
                          <p style="margin: 0; font-size: 15px; font-weight: 600; color: #2d3748;">Go to "Shared Sites"</p>
                          <p style="margin: 4px 0 0; font-size: 13px; color: #718096;">Navigate to Sites → Shared With Me</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- Step 3 -->
                <tr>
                  <td style="padding: 12px 0;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                      <tr>
                        <td width="50" style="vertical-align: top;">
                          <div style="width: 44px; height: 44px; background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); border-radius: 12px; text-align: center; line-height: 44px; font-size: 18px; font-weight: 800; color: #ffffff; box-shadow: 0 4px 15px rgba(240, 147, 251, 0.3);">3</div>
                        </td>
                        <td style="padding-left: 15px; vertical-align: middle;">
                          <p style="margin: 0; font-size: 15px; font-weight: 600; color: #2d3748;">Tap "Check & Download"</p>
                          <p style="margin: 4px 0 0; font-size: 13px; color: #718096;">Download the site and start collaborating!</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- CTA Button -->
          <tr>
            <td style="padding: 0 40px 50px; text-align: center;">
              <div style="background: linear-gradient(135deg, #e8f4f8 0%, #f0f4f8 100%); border-radius: 16px; padding: 30px;">
                <p style="margin: 0 0 5px; font-size: 32px;">📱</p>
                <p style="margin: 0 0 8px; font-size: 18px; font-weight: 700; color: #1a202c;">
                  Ready to collaborate?
                </p>
                <p style="margin: 0; font-size: 14px; color: #718096;">
                  Open the app now and check your shared sites!
                </p>
              </div>
            </td>
          </tr>

          <!-- Divider -->
          <tr>
            <td style="padding: 0 40px;">
              <div style="height: 1px; background: linear-gradient(90deg, transparent, #e2e8f0, transparent);"></div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); padding: 35px 40px; text-align: center;">
              <p style="margin: 0 0 8px; font-size: 22px; font-weight: 700; color: #ffffff;">
                🎯 SnagSnapper
              </p>
              <p style="margin: 0 0 15px; font-size: 13px; color: #a0aec0; letter-spacing: 1px; text-transform: uppercase;">
                Professional Snagging Made Simple
              </p>
              <p style="margin: 0; font-size: 12px; color: #718096;">
                © ${new Date().getFullYear()} SnagSnapper by Productive Apps. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();
}

/**
 * Generate plain text version of site shared email
 * @param {string} siteName - Name of the shared site
 * @param {string} ownerName - Name of the site owner
 * @param {string} permission - Permission level
 * @returns {string} Plain text email content
 */
function generateSiteSharedEmailText(siteName, ownerName, permission) {
  const permissionDescriptions = {
    'VIEW': 'View all snags and reports',
    'WORKING': 'Work on snags assigned to you',
    'CONTRIBUTOR': 'Create and manage snags',
  };

  const permissionDesc = permissionDescriptions[permission] || 'Access the site';

  return `
🏗️ A Site Has Been Shared With You!
=====================================

Hi there!

Great news! "${siteName || 'A new site'}" has been shared with you by ${ownerName || 'a SnagSnapper user'}.

YOUR ACCESS LEVEL: ${permission}
${permissionDesc}

GET STARTED IN 3 EASY STEPS:
-----------------------------
1️⃣ Open SnagSnapper App
   Launch the app on your device

2️⃣ Go to "Shared Sites"
   Navigate to Sites → Shared With Me

3️⃣ Tap "Check & Download"
   Download the site and start collaborating!

---

🎯 SnagSnapper
Professional Snagging Made Simple

© ${new Date().getFullYear()} SnagSnapper by Productive Apps. All rights reserved.
  `.trim();
}

/**
 * Send site shared notification email
 * @param {string} recipientEmail - Email address of the recipient
 * @param {string} siteName - Name of the shared site
 * @param {string} ownerName - Name of the site owner
 * @param {string} permission - Permission level
 */
async function sendSiteSharedEmail(recipientEmail, siteName, ownerName, permission) {
  const functionName = 'sendSiteSharedEmail';

  try {
    // Configure SES client
    const sesClient = new SESClient({
      region: 'eu-west-2',
      credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
      },
    });

    // Send email
    const sendCommand = new SendEmailCommand({
      Source: 'SnagSnapper <noreply@productiveapps.co.uk>',
      Destination: {
        ToAddresses: [recipientEmail],
      },
      Message: {
        Subject: {
          Data: `🏗️ "${siteName}" has been shared with you on SnagSnapper`,
          Charset: 'UTF-8',
        },
        Body: {
          Html: {
            Data: generateSiteSharedEmailHTML(siteName, ownerName, permission),
            Charset: 'UTF-8',
          },
          Text: {
            Data: generateSiteSharedEmailText(siteName, ownerName, permission),
            Charset: 'UTF-8',
          },
        },
      },
    });

    const response = await sesClient.send(sendCommand);
    log(functionName, 'Site shared email sent', {
      recipient: recipientEmail,
      siteName,
      messageId: response.MessageId,
    });

    return true;
  } catch (error) {
    // Log error but don't throw - email failure shouldn't break sharing
    console.error(`${functionName} error:`, error);
    log(functionName, 'Failed to send site shared email', {
      recipient: recipientEmail,
      siteName,
      error: error.message,
    });
    return false;
  }
}

// ============================================================================
// WELCOME EMAIL FUNCTION
// ============================================================================

/**
 * Generate stunning HTML welcome email
 * @param {string} userName - User's display name or email
 * @returns {string} HTML email content
 */
function generateWelcomeEmailHTML(userName) {
  const displayName = userName || 'there';

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to SnagSnapper</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f0f4f8;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px;">
    <tr>
      <td align="center">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="background: #ffffff; border-radius: 16px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); overflow: hidden;">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); padding: 40px 40px 30px; text-align: center;">
              <h1 style="margin: 0; font-size: 42px; font-weight: 800; color: #ffffff; letter-spacing: -1px;">
                🎯 SnagSnapper
              </h1>
              <p style="margin: 10px 0 0; font-size: 16px; color: #a0aec0; letter-spacing: 2px; text-transform: uppercase;">
                Professional Snagging Made Simple
              </p>
            </td>
          </tr>

          <!-- Welcome Message -->
          <tr>
            <td style="padding: 50px 40px 30px; text-align: center;">
              <h2 style="margin: 0 0 15px; font-size: 32px; font-weight: 700; color: #1a202c;">
                Welcome aboard, ${displayName}! 🚀
              </h2>
              <p style="margin: 0; font-size: 18px; color: #718096; line-height: 1.6;">
                You've just unlocked the most powerful snagging tool in your pocket.<br>
                Let's transform how you manage construction defects.
              </p>
            </td>
          </tr>

          <!-- Features Grid -->
          <tr>
            <td style="padding: 20px 40px 40px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">

                <!-- Feature Row 1 -->
                <tr>
                  <td width="50%" style="padding: 10px; vertical-align: top;">
                    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px; padding: 25px; text-align: center;">
                      <div style="font-size: 36px; margin-bottom: 10px;">📸</div>
                      <h3 style="margin: 0 0 8px; font-size: 16px; font-weight: 700; color: #ffffff;">Photo Snags</h3>
                      <p style="margin: 0; font-size: 13px; color: rgba(255,255,255,0.85);">Capture issues instantly with annotated photos</p>
                    </div>
                  </td>
                  <td width="50%" style="padding: 10px; vertical-align: top;">
                    <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); border-radius: 12px; padding: 25px; text-align: center;">
                      <div style="font-size: 36px; margin-bottom: 10px;">📴</div>
                      <h3 style="margin: 0 0 8px; font-size: 16px; font-weight: 700; color: #ffffff;">Offline Mode</h3>
                      <p style="margin: 0; font-size: 13px; color: rgba(255,255,255,0.85);">Work anywhere, sync when connected</p>
                    </div>
                  </td>
                </tr>

                <!-- Feature Row 2 -->
                <tr>
                  <td width="50%" style="padding: 10px; vertical-align: top;">
                    <div style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); border-radius: 12px; padding: 25px; text-align: center;">
                      <div style="font-size: 36px; margin-bottom: 10px;">📋</div>
                      <h3 style="margin: 0 0 8px; font-size: 16px; font-weight: 700; color: #ffffff;">PDF Reports</h3>
                      <p style="margin: 0; font-size: 13px; color: rgba(255,255,255,0.85);">Generate professional reports in seconds</p>
                    </div>
                  </td>
                  <td width="50%" style="padding: 10px; vertical-align: top;">
                    <div style="background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%); border-radius: 12px; padding: 25px; text-align: center;">
                      <div style="font-size: 36px; margin-bottom: 10px;">👥</div>
                      <h3 style="margin: 0 0 8px; font-size: 16px; font-weight: 700; color: #ffffff;">Team Sharing</h3>
                      <p style="margin: 0; font-size: 13px; color: rgba(255,255,255,0.85);">Collaborate with contractors & clients</p>
                    </div>
                  </td>
                </tr>

                <!-- Feature Row 3 -->
                <tr>
                  <td width="50%" style="padding: 10px; vertical-align: top;">
                    <div style="background: linear-gradient(135deg, #fa709a 0%, #fee140 100%); border-radius: 12px; padding: 25px; text-align: center;">
                      <div style="font-size: 36px; margin-bottom: 10px;">⚡</div>
                      <h3 style="margin: 0 0 8px; font-size: 16px; font-weight: 700; color: #ffffff;">Priority System</h3>
                      <p style="margin: 0; font-size: 13px; color: rgba(255,255,255,0.85);">Categorise snags from OK to Critical</p>
                    </div>
                  </td>
                  <td width="50%" style="padding: 10px; vertical-align: top;">
                    <div style="background: linear-gradient(135deg, #a18cd1 0%, #fbc2eb 100%); border-radius: 12px; padding: 25px; text-align: center;">
                      <div style="font-size: 36px; margin-bottom: 10px;">🏗️</div>
                      <h3 style="margin: 0 0 8px; font-size: 16px; font-weight: 700; color: #ffffff;">Site Management</h3>
                      <p style="margin: 0; font-size: 13px; color: rgba(255,255,255,0.85);">Organise multiple projects effortlessly</p>
                    </div>
                  </td>
                </tr>

              </table>
            </td>
          </tr>

          <!-- CTA Section -->
          <tr>
            <td style="padding: 0 40px 40px; text-align: center;">
              <div style="background: linear-gradient(135deg, #e0e5ec 0%, #f0f4f8 100%); border-radius: 12px; padding: 30px;">
                <p style="margin: 0 0 20px; font-size: 18px; font-weight: 600; color: #2d3748;">
                  Ready to snap your first snag? 📱
                </p>
                <p style="margin: 0; font-size: 15px; color: #718096; line-height: 1.6;">
                  Open the app, create your first site, and start documenting.<br>
                  It's that simple.
                </p>
              </div>
            </td>
          </tr>

          <!-- Divider -->
          <tr>
            <td style="padding: 0 40px;">
              <div style="height: 1px; background: linear-gradient(90deg, transparent, #e2e8f0, transparent);"></div>
            </td>
          </tr>

          <!-- Support Section -->
          <tr>
            <td style="padding: 40px; text-align: center;">
              <p style="margin: 0 0 15px; font-size: 16px; color: #4a5568;">
                Questions? Ideas? We'd love to hear from you!
              </p>
              <a href="mailto:developer@productiveapps.co.uk" style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; font-size: 15px; font-weight: 600; text-decoration: none; padding: 14px 32px; border-radius: 8px; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);">
                Contact Developer
              </a>
              <p style="margin: 20px 0 0; font-size: 13px; color: #a0aec0;">
                developer@productiveapps.co.uk
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background: #1a1a2e; padding: 30px 40px; text-align: center;">
              <p style="margin: 0 0 10px; font-size: 14px; color: #a0aec0;">
                Built with ❤️ by Productive Apps
              </p>
              <p style="margin: 0; font-size: 12px; color: #718096;">
                © ${new Date().getFullYear()} SnagSnapper. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();
}

/**
 * Generate plain text version of welcome email
 * @param {string} userName - User's display name or email
 * @returns {string} Plain text email content
 */
function generateWelcomeEmailText(userName) {
  const displayName = userName || 'there';

  return `
Welcome to SnagSnapper! 🎯
========================

Hi ${displayName},

You've just unlocked the most powerful snagging tool in your pocket.

WHAT YOU CAN DO:
----------------
📸 Photo Snags - Capture issues instantly with annotated photos
📴 Offline Mode - Work anywhere, sync when connected
📋 PDF Reports - Generate professional reports in seconds
👥 Team Sharing - Collaborate with contractors & clients
⚡ Priority System - Categorise snags from OK to Critical
🏗️ Site Management - Organise multiple projects effortlessly

GETTING STARTED:
----------------
Open the app, create your first site, and start documenting.
It's that simple.

NEED HELP?
----------
Questions? Ideas? We'd love to hear from you!
Email: developer@productiveapps.co.uk

---
Built with ❤️ by Productive Apps
© ${new Date().getFullYear()} SnagSnapper. All rights reserved.
  `.trim();
}

/**
 * Triggered when a new user profile is created.
 * Sends a stunning welcome email via AWS SES.
 */
exports.onProfileCreated = onDocumentCreated(
  {
    document: 'Profile/{userId}',
    region: REGION,
    secrets: ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY'],
  },
  async (event) => {
    const functionName = 'onProfileCreated';
    const { userId } = event.params;

    try {
      log(functionName, 'New profile created', { userId });

      // Get user email from Firebase Auth
      const auth = getAuth();
      const userRecord = await auth.getUser(userId);
      const userEmail = userRecord.email;
      const userName = userRecord.displayName || userEmail?.split('@')[0];

      if (!userEmail) {
        log(functionName, 'No email found for user', { userId });
        return;
      }

      log(functionName, 'Sending welcome email', { email: userEmail });

      // Configure SES client
      const sesClient = new SESClient({
        region: 'eu-west-2',
        credentials: {
          accessKeyId: process.env.AWS_ACCESS_KEY_ID,
          secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
        },
      });

      // Send email
      const sendCommand = new SendEmailCommand({
        Source: 'SnagSnapper <welcome@productiveapps.co.uk>',
        Destination: {
          ToAddresses: [userEmail],
        },
        Message: {
          Subject: {
            Data: '🎯 Welcome to SnagSnapper - Your Snagging Superpower Awaits!',
            Charset: 'UTF-8',
          },
          Body: {
            Html: {
              Data: generateWelcomeEmailHTML(userName),
              Charset: 'UTF-8',
            },
            Text: {
              Data: generateWelcomeEmailText(userName),
              Charset: 'UTF-8',
            },
          },
        },
      });

      const response = await sesClient.send(sendCommand);

      log(functionName, 'Welcome email sent successfully', {
        userId,
        messageId: response.MessageId,
      });

    } catch (error) {
      // Log error but don't throw - welcome email failure shouldn't break profile creation
      console.error(`${functionName} error:`, error);
      log(functionName, 'Failed to send welcome email', {
        userId,
        error: error.message,
      });
    }
  }
);
