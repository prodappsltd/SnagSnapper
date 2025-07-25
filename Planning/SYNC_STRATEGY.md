# SnagSnapper Sync Strategy - Cost-Optimized Approach

## Critical Discovery: Firestore Pricing Model

**IMPORTANT**: Firestore charges per document operation, NOT per field:
- Updating 1 field = 1 write operation = $0.18 per 100k
- Updating ALL fields = 1 write operation = $0.18 per 100k
- **Same cost regardless of how many fields change!**

This fundamentally changes our sync strategy.

## Previous Approach (Inefficient)

We were planning to track individual field changes:
```dart
// Example of INEFFICIENT approach:
updateProfileName();        // 1 write
updateProfilePhone();       // 1 write
updateProfileImage();       // 1 write
updateProfileJobTitle();    // 1 write
// Total: 4 writes = 4x cost for single user update
```

## New Approach (Cost-Optimized)

Sync entire documents:
```dart
// EFFICIENT approach:
updateEntireProfile();      // 1 write only!
// Updates ALL fields at once
```

## Cost Analysis

### Scenario: User updates profile 5 times offline

**Field-Level Tracking (OLD)**:
- Name changed: 1 write
- Phone changed: 1 write  
- Image changed: 1 write
- Job title changed: 1 write
- Company changed: 1 write
- **Total: 5 writes**

**Document-Level Sync (NEW)**:
- Entire profile synced once: 1 write
- **Total: 1 write**
- **Savings: 80%**

### At Scale (1000 users, 5 updates each)

**Field-Level**: 5,000 writes = $0.90
**Document-Level**: 1,000 writes = $0.18
**Savings**: $0.72 (80%)

## Implementation Strategy

### 1. Local State Management
```dart
// Store complete documents locally
class LocalCache {
  // Complete profile stored locally
  AppUser localProfile;
  
  // Complete sites stored locally
  Map<String, Site> localSites;
  
  // Complete snags stored locally
  Map<String, Snag> localSnags;
}
```

### 2. Sync Tracking (Simplified)
```dart
// Just track WHICH entities changed, not WHAT changed
SharedPreferences:
  - profile_needs_sync: true/false
  - sites_need_sync: ["site1", "site2"]  // Just IDs
  - snags_need_sync: ["snag1", "snag2"]  // Just IDs
```

### 3. Sync Process
```dart
// When online, sync entire documents
Future<void> syncProfile() async {
  if (!profileNeedsSync) return;
  
  // Get entire local profile
  final profile = getLocalProfile();
  
  // Single write operation
  await Firestore.collection('Profile')
    .doc(userId)
    .set(profile.toJson());
    
  // Clear flag
  clearProfileSyncFlag();
}
```

## Benefits

1. **Cost Reduction**: 80%+ savings on Firestore writes
2. **Simpler Code**: No complex field tracking
3. **Less Memory**: Just entity IDs, not change details
4. **No Conflicts**: Local state becomes server state
5. **Faster Sync**: Batch operations, no field merging

## Implementation Phases

### Phase 1: Profile (Current)
- Store complete profile locally
- Track profile_needs_sync flag
- Sync entire profile document

### Phase 2: Sites
- Store complete sites locally
- Track site IDs that need sync
- Sync entire site documents

### Phase 3: Snags
- Store complete snags locally
- Track snag IDs that need sync
- Sync entire snag documents

## Implementation Decisions

### 1. Conflict Resolution
- **Decision**: Last write wins - local state becomes server state
- **Rationale**: Simplest approach, no merge conflicts
- **No change tracking required**

### 2. Local Storage
- **Decision**: Local SQLite database
- **Rationale**: 
  - Structured data storage
  - Complex queries possible
  - Better than SharedPreferences for documents
  - Efficient for large datasets
- **Implementation**: sqflite package

### 3. Sync Triggers
- **Primary**: Screen navigation (next available opportunity)
- **Secondary**:
  - App launch/resume
  - Network state change
  - Manual refresh (if needed)
- **Background**: Continuous while app is active

### 4. User Feedback
- **Global Sync Indicator**: AppBar icon across all screens
  - Shows when items pending sync
  - Animated while syncing
  - Disappears when queue empty
- **Per-Item Indicators**: Small sync icon on lists
- **No blocking UI**: All sync happens in background

## Local Database Schema

```sql
-- Sync queue table
CREATE TABLE sync_queue (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL, -- 'profile', 'site', 'snag'
  entity_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_error TEXT
);

-- Local profile cache
CREATE TABLE profile_cache (
  user_id TEXT PRIMARY KEY,
  data TEXT NOT NULL, -- JSON document
  last_modified INTEGER NOT NULL
);

-- Local sites cache
CREATE TABLE sites_cache (
  site_id TEXT PRIMARY KEY,
  data TEXT NOT NULL, -- JSON document
  last_modified INTEGER NOT NULL
);

-- Local snags cache  
CREATE TABLE snags_cache (
  snag_id TEXT PRIMARY KEY,
  site_id TEXT NOT NULL,
  data TEXT NOT NULL, -- JSON document
  last_modified INTEGER NOT NULL
);
```

## Sync Indicator Widget

```dart
// Global app bar widget
class SyncStatusIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: SyncService().pendingCountStream,
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;
        
        if (pendingCount == 0) {
          return SizedBox.shrink(); // No icon when synced
        }
        
        return Stack(
          children: [
            Icon(Icons.cloud_sync, color: Colors.orange),
            if (pendingCount > 1)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$pendingCount',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

## Background Sync Process

```dart
class SyncService {
  Timer? _syncTimer;
  
  void startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (isOnline && hasConnection) {
        processQueue();
      }
    });
  }
  
  Future<void> processQueue() async {
    final pending = await db.query('sync_queue');
    
    for (final item in pending) {
      try {
        await syncEntity(item);
        await db.delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
        notifyListeners(); // Updates UI
      } catch (e) {
        await incrementRetryCount(item['id']);
      }
    }
  }
}
```

## Navigation Trigger

```dart
// In main navigation widget
class AppNavigator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Navigator(
      observers: [
        SyncNavigatorObserver(), // Triggers sync on navigation
      ],
      // ... routes
    );
  }
}

class SyncNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    SyncService().checkAndSync(); // Non-blocking
  }
}
```

## Code Architecture

```dart
// Generic sync service
class SyncService {
  // Mark entire entity for sync
  markForSync(EntityType type, String id);
  
  // Sync entire documents
  syncPendingEntities();
  
  // No field-level tracking needed!
}
```

## Migration Path

1. Current implementation already stores relative paths
2. Already doing full document updates for profile
3. Just need to formalize the pattern for sites/snags

## Cost Projections

For 10,000 active users:
- Average 10 operations/day/user
- OLD: 100,000 writes/day = $18/day
- NEW: 20,000 writes/day = $3.60/day
- **Savings: $14.40/day = $5,256/year**

## Conclusion

By syncing entire documents instead of individual fields, we achieve:
- Massive cost savings
- Simpler implementation  
- Better performance
- Easier maintenance

This approach aligns perfectly with our offline-first, cost-efficient requirements.

## Next Steps

1. Implement SyncService with document-level sync
2. Update profile to use new service
3. Design local storage for sites/snags
4. Test sync performance

---
*Last Updated: 2024-01-23*
*Critical Discovery: Firestore charges per document, not per field*