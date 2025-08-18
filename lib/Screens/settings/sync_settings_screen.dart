import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'package:snagsnapper/services/background_sync_service.dart';
import 'package:snagsnapper/Data/models/sync_result.dart';

/// Sync Settings Screen
/// Manages sync configuration and preferences
class SyncSettingsScreen extends StatefulWidget {
  final SyncService? syncServiceOverride;
  
  const SyncSettingsScreen({
    super.key,
    this.syncServiceOverride,
  });
  
  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  late SyncService syncService;
  late SharedPreferences prefs;
  
  bool autoSyncEnabled = true;
  bool wifiOnlySync = true;
  bool backgroundSyncEnabled = true;
  int syncIntervalMinutes = 30;
  
  // Statistics
  DateTime? lastSyncTime;
  int totalDataSynced = 0;
  int errorCount = 0;
  Map<String, int> dailySyncCounts = {};
  
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    syncService = widget.syncServiceOverride ?? SyncService.instance;
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    prefs = await SharedPreferences.getInstance();
    
    setState(() {
      autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? true;
      wifiOnlySync = prefs.getBool('wifi_only_sync') ?? true;
      backgroundSyncEnabled = prefs.getBool('background_sync_enabled') ?? true;
      syncIntervalMinutes = prefs.getInt('sync_interval_minutes') ?? 30;
      
      // Load statistics
      final lastSyncMs = prefs.getInt('last_sync_time');
      if (lastSyncMs != null) {
        lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
      }
      totalDataSynced = prefs.getInt('total_data_synced') ?? 0;
      errorCount = prefs.getInt('sync_error_count') ?? 0;
      
      // Load daily sync counts (last 7 days)
      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final key = '${date.year}-${date.month}-${date.day}';
        dailySyncCounts[key] = prefs.getInt('sync_count_$key') ?? 0;
      }
      
      isLoading = false;
    });
  }
  
  Future<void> _updateAutoSync(bool enabled) async {
    setState(() {
      autoSyncEnabled = enabled;
    });
    
    await prefs.setBool('auto_sync_enabled', enabled);
    
    if (enabled) {
      syncService.setupAutoSync();
    } else {
      syncService.pauseSync();
    }
  }
  
  Future<void> _updateWifiOnly(bool enabled) async {
    setState(() {
      wifiOnlySync = enabled;
    });
    
    await prefs.setBool('wifi_only_sync', enabled);
  }
  
  Future<void> _updateBackgroundSync(bool enabled) async {
    setState(() {
      backgroundSyncEnabled = enabled;
    });
    
    await prefs.setBool('background_sync_enabled', enabled);
    
    if (enabled) {
      await BackgroundSyncService.registerPeriodicSync(
        frequency: Duration(minutes: syncIntervalMinutes),
        requiresWifi: wifiOnlySync,
      );
    } else {
      await BackgroundSyncService.cancelPeriodicSync();
    }
  }
  
  Future<void> _updateSyncInterval(int minutes) async {
    setState(() {
      syncIntervalMinutes = minutes;
    });
    
    await prefs.setInt('sync_interval_minutes', minutes);
    
    if (backgroundSyncEnabled) {
      await BackgroundSyncService.registerPeriodicSync(
        frequency: Duration(minutes: minutes),
        requiresWifi: wifiOnlySync,
      );
    }
  }
  
  Future<void> _clearSyncQueue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Sync Queue?'),
        content: const Text('This will remove all pending sync items. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Clear queue implementation
      await prefs.remove('sync_queue');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync queue cleared')),
        );
      }
    }
  }
  
  Future<void> _forceSyncNow() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Syncing...'),
          ],
        ),
      ),
    );
    
    final result = await syncService.syncNow();
    
    if (mounted) {
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? 'Sync completed' : 'Sync failed: ${result.message}'),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      
      // Update last sync time
      if (result.success) {
        setState(() {
          lastSyncTime = DateTime.now();
        });
        await prefs.setInt('last_sync_time', lastSyncTime!.millisecondsSinceEpoch);
      }
    }
  }
  
  Future<void> _resetSyncState() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Sync State?'),
        content: const Text('This will reset all sync flags and require a full re-sync. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Reset implementation
      await prefs.clear();
      await _loadSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync state reset')),
        );
      }
    }
  }
  
  void _viewSyncHistory() {
    // Navigate to sync history screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lastSyncTime != null)
              ListTile(
                title: const Text('Last Sync'),
                subtitle: Text(_formatDateTime(lastSyncTime!)),
                leading: const Icon(Icons.access_time),
              ),
            ListTile(
              title: const Text('Total Data Synced'),
              subtitle: Text(_formatBytes(totalDataSynced)),
              leading: const Icon(Icons.cloud_upload),
            ),
            ListTile(
              title: const Text('Error Count'),
              subtitle: Text('$errorCount errors'),
              leading: Icon(Icons.error, color: errorCount > 0 ? Colors.red : Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  String _getRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
      ),
      body: ListView(
        children: [
          // Sync Configuration Section
          const ListTile(
            title: Text('Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('Auto-sync'),
            subtitle: const Text('Automatically sync when online'),
            value: autoSyncEnabled,
            onChanged: _updateAutoSync,
          ),
          SwitchListTile(
            title: const Text('WiFi only'),
            subtitle: const Text('Only sync when connected to WiFi'),
            value: wifiOnlySync,
            onChanged: autoSyncEnabled ? _updateWifiOnly : null,
          ),
          SwitchListTile(
            title: const Text('Background sync'),
            subtitle: const Text('Sync in the background periodically'),
            value: backgroundSyncEnabled,
            onChanged: _updateBackgroundSync,
          ),
          ListTile(
            title: const Text('Sync interval'),
            subtitle: Text('Every $syncIntervalMinutes minutes'),
            enabled: backgroundSyncEnabled,
            onTap: backgroundSyncEnabled
                ? () async {
                    final selected = await showDialog<int>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('Select Sync Interval'),
                        children: [15, 30, 60, 120].map((minutes) {
                          return SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, minutes),
                            child: Text('$minutes minutes'),
                          );
                        }).toList(),
                      ),
                    );
                    if (selected != null) {
                      await _updateSyncInterval(selected);
                    }
                  }
                : null,
          ),
          
          const Divider(),
          
          // Management Options Section
          const ListTile(
            title: Text('Management', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.clear_all),
            title: const Text('Clear sync queue'),
            subtitle: const Text('Remove all pending sync items'),
            onTap: _clearSyncQueue,
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Force sync now'),
            subtitle: const Text('Trigger immediate sync'),
            onTap: _forceSyncNow,
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Reset sync state'),
            subtitle: const Text('Clear all sync flags'),
            onTap: _resetSyncState,
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('View sync history'),
            subtitle: const Text('See recent sync operations'),
            onTap: _viewSyncHistory,
          ),
          
          const Divider(),
          
          // Statistics Section
          const ListTile(
            title: Text('Statistics', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (lastSyncTime != null)
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Last sync'),
              subtitle: Text(_getRelativeTime(lastSyncTime!)),
              trailing: Text(_formatDateTime(lastSyncTime!)),
            ),
          ListTile(
            leading: const Icon(Icons.data_usage),
            title: const Text('Data synced'),
            subtitle: Text(_formatBytes(totalDataSynced)),
            trailing: const Text('This month'),
          ),
          
          // Simple bar chart for daily sync counts
          if (dailySyncCounts.isNotEmpty) ...[
            const ListTile(
              title: Text('Sync Frequency (Last 7 days)'),
            ),
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: dailySyncCounts.entries.map((entry) {
                  final maxCount = dailySyncCounts.values.reduce((a, b) => a > b ? a : b);
                  final height = maxCount > 0 ? (entry.value / maxCount) * 80 : 0.0;
                  
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 40,
                        height: height,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.key.split('-').last,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
          
          if (errorCount > 0)
            ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: const Text('Error count'),
              subtitle: Text('$errorCount errors in last 24 hours'),
              trailing: TextButton(
                onPressed: () {
                  // Show error details
                },
                child: const Text('Details'),
              ),
            ),
        ],
      ),
    );
  }
}