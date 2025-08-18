import 'package:mockito/annotations.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

@GenerateMocks([
  SyncService,
  ImageStorageService,
  Connectivity,
])
void main() {}