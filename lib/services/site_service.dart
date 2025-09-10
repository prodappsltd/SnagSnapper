import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../Data/database/app_database.dart';
import '../Data/database/daos/site_dao.dart';
import '../Data/models/site.dart';

/// Service class for Site operations
/// 
/// This service provides a high-level interface for site management,
/// wrapping the DAO operations with business logic.
class SiteService {
  final SiteDao _siteDao;
  final String _currentUserEmail;
  final String _currentUserUID;
  
  /// Constructor requires the database instance and current user info
  SiteService({
    required AppDatabase database,
    required String userEmail,
    required String userUID,
  }) : _siteDao = database.siteDao,
       _currentUserEmail = userEmail,
       _currentUserUID = userUID;

  // ============== Create Operations ==============
  
  /// Create a new site
  /// Returns the created site's ID
  Future<String> createSite({
    required String name,
    String? companyName,
    String? address,
    String? contactPerson,
    String? contactPhone,
    DateTime? expectedCompletion,
    int pictureQuality = 1,
  }) async {
    try {
      // Generate a new UUID for the site
      final siteId = const Uuid().v4();
      
      // Create the site using the factory constructor
      final site = Site.create(
        id: siteId,
        ownerUID: _currentUserUID,
        ownerEmail: _currentUserEmail,
        name: name,
        companyName: companyName,
        address: address,
        contactPerson: contactPerson,
        contactPhone: contactPhone,
        expectedCompletion: expectedCompletion,
        pictureQuality: pictureQuality,
      );
      
      // Insert into database
      await _siteDao.insertSite(site);
      
      if (kDebugMode) {
        print('SiteService: Created new site: $siteId - $name');
      }
      
      return siteId;
    } catch (e) {
      if (kDebugMode) {
        print('SiteService: Error creating site "$name": $e');
      }
      rethrow;
    }
  }

  // ============== Read Operations ==============
  
  /// Get all sites accessible to the current user
  Future<List<Site>> getAllSites() async {
    return await _siteDao.getAllSites(_currentUserEmail);
  }
  
  /// Get only sites owned by the current user
  Future<List<Site>> getOwnedSites() async {
    return await _siteDao.getOwnedSites(_currentUserEmail);
  }
  
  /// Get only sites shared with the current user
  Future<List<Site>> getSharedSites() async {
    return await _siteDao.getSharedSites(_currentUserEmail);
  }
  
  /// Get active (non-archived) sites
  Future<List<Site>> getActiveSites() async {
    return await _siteDao.getActiveSites(_currentUserEmail);
  }
  
  /// Get a specific site by ID
  Future<Site?> getSite(String siteId) async {
    final site = await _siteDao.getSiteById(siteId);
    
    // Check if user has access to this site
    if (site != null) {
      if (site.isOwnedBy(_currentUserEmail) || 
          site.getPermissionFor(_currentUserEmail) != null) {
        return site;
      }
    }
    return null; // No access or site doesn't exist
  }
  
  /// Watch all sites for real-time updates
  Stream<List<Site>> watchAllSites() {
    return _siteDao.watchAllSites(_currentUserEmail);
  }
  
  /// Watch a specific site for real-time updates
  Stream<Site?> watchSite(String siteId) {
    return _siteDao.watchSite(siteId);
  }

  // ============== Update Operations ==============
  
  /// Update site information
  /// Only the owner can update site details
  Future<bool> updateSite(Site site) async {
    // Check if current user is the owner
    if (!site.isOwnedBy(_currentUserEmail)) {
      if (kDebugMode) {
        print('SiteService: User $_currentUserEmail cannot update site ${site.id} - not owner');
      }
      return false;
    }
    
    return await _siteDao.updateSite(site);
  }
  
  /// Archive or unarchive a site
  /// Only the owner can archive sites
  Future<bool> archiveSite(String siteId, bool archive) async {
    final site = await getSite(siteId);
    if (site == null || !site.isOwnedBy(_currentUserEmail)) {
      return false;
    }
    
    await _siteDao.archiveSite(siteId, archive);
    return true;
  }
  
  /// Mark a site for deletion (soft delete with 7-day grace period)
  /// Only the owner can delete sites
  Future<bool> deleteSite(String siteId) async {
    final site = await getSite(siteId);
    if (site == null || !site.isOwnedBy(_currentUserEmail)) {
      return false;
    }
    
    await _siteDao.markSiteForDeletion(siteId);
    
    if (kDebugMode) {
      print('SiteService: Site $siteId marked for deletion - will be deleted in 7 days');
    }
    
    return true;
  }

  // ============== Sharing Operations ==============
  
  /// Share a site with a colleague
  /// Only the owner can share sites
  Future<bool> shareSiteWithUser({
    required String siteId,
    required String userEmail,
    required String permission, // VIEW, FIXER, or CONTRIBUTOR
  }) async {
    final site = await getSite(siteId);
    if (site == null || !site.isOwnedBy(_currentUserEmail)) {
      return false;
    }
    
    // Validate permission level
    if (!['VIEW', 'FIXER', 'CONTRIBUTOR'].contains(permission)) {
      if (kDebugMode) {
        print('SiteService: Invalid permission level: $permission');
      }
      return false;
    }
    
    await _siteDao.addUserToSite(siteId, userEmail, permission);
    
    if (kDebugMode) {
      print('SiteService: Shared site $siteId with $userEmail as $permission');
    }
    
    return true;
  }
  
  /// Remove a user's access to a site
  /// Only the owner can remove sharing
  Future<bool> removeSiteSharing({
    required String siteId,
    required String userEmail,
  }) async {
    final site = await getSite(siteId);
    if (site == null || !site.isOwnedBy(_currentUserEmail)) {
      return false;
    }
    
    await _siteDao.removeUserFromSite(siteId, userEmail);
    
    if (kDebugMode) {
      print('SiteService: Removed $userEmail access from site $siteId');
    }
    
    return true;
  }
  
  /// Update all sharing permissions for a site at once
  Future<bool> updateSiteSharing({
    required String siteId,
    required Map<String, String> sharedWith,
  }) async {
    final site = await getSite(siteId);
    if (site == null || !site.isOwnedBy(_currentUserEmail)) {
      return false;
    }
    
    await _siteDao.updateSiteSharing(siteId, sharedWith);
    return true;
  }

  // ============== Category Management ==============
  
  /// Add a new category to a site
  /// Categories are added when creating snags with new categories
  Future<void> addCategory({
    required String siteId,
    required String categoryName,
  }) async {
    final site = await getSite(siteId);
    if (site == null) return;
    
    // Find the next available category ID
    final existingIds = site.snagCategories.keys.toList()..sort();
    final nextId = existingIds.isEmpty ? 1 : existingIds.last + 1;
    
    await _siteDao.addSiteCategory(siteId, nextId, categoryName);
    
    if (kDebugMode) {
      print('SiteService: Added category "$categoryName" with ID $nextId to site $siteId');
    }
  }

  // ============== Statistics Operations ==============
  
  /// Update site statistics after snag changes
  /// This would typically be called by the SnagService
  Future<void> updateStatistics({
    required String siteId,
    required int totalSnags,
    required int openSnags,
    required int closedSnags,
  }) async {
    await _siteDao.updateSiteStatistics(
      siteId,
      totalSnags: totalSnags,
      openSnags: openSnags,
      closedSnags: closedSnags,
    );
  }

  // ============== Sync Operations ==============
  
  /// Get all sites that need syncing
  Future<List<Site>> getSitesNeedingSync() async {
    return await _siteDao.getSitesNeedingSync();
  }
  
  /// Clear sync flags after successful sync
  Future<void> clearSyncFlags(String siteId) async {
    await _siteDao.clearSyncFlags(siteId);
  }
  
  /// Clean up expired soft-deleted sites
  /// This should be called periodically (e.g., on app startup)
  Future<int> cleanupExpiredSites() async {
    final count = await _siteDao.deleteExpiredSites();
    if (count > 0 && kDebugMode) {
      print('SiteService: Cleaned up $count expired sites');
    }
    return count;
  }

  // ============== Permission Checking Helpers ==============
  
  /// Check if current user can edit a site
  bool canEditSite(Site site) {
    return site.canEdit(_currentUserEmail);
  }
  
  /// Check if current user can create snags in a site
  bool canCreateSnags(Site site) {
    return site.canCreateSnags(_currentUserEmail);
  }
  
  /// Get current user's permission level for a site
  String? getPermissionLevel(Site site) {
    if (site.isOwnedBy(_currentUserEmail)) {
      return 'OWNER'; // Special case for display
    }
    return site.getPermissionFor(_currentUserEmail);
  }
}