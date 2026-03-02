// lib/data/services/storage_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

import 'auth_service.dart';

class StorageService {
  StorageService._internal();
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService = AuthService();
  final String _storyAudiosPath = 'story_audios';
  final String _characterImagesPath = 'character_images';

  // Verilen dosya yolundaki dosyayı Firebase Storage'a yükler
  // ve indirilebilir (download) URL'sini döndürür.
  Future<String> uploadFile({
    required File file,
    required String fileName,
    required String contentType,
    String? folderPath,
  }) async {
    final resolvedFolder =
        (folderPath ?? _storyAudiosPath).replaceAll('//', '/');
    final normalizedFolder =
        resolvedFolder.endsWith('/') ? resolvedFolder : '$resolvedFolder/';
    final uploadPath = '$normalizedFolder$fileName';

    final Reference ref = _storage.ref().child(uploadPath);

    // Metadata (içerik tipini belirtmek zorunludur)
    final metadata = SettableMetadata(contentType: contentType);

    // Yükleme işlemi
    await ref.putFile(file, metadata);

    // İndirme URL'sini döndür
    return await ref.getDownloadURL();
  }

  Future<String> uploadCharacterImage({
    required File file,
    required String userId,
  }) async {
    final extension = _readExtension(file.path);
    final ownerUid = await _authService.getCurrentUserId();
    final safeOwnerUid = ownerUid.trim().isEmpty ? 'guest' : ownerUid.trim();
    final safeUserId = userId.trim().isEmpty ? 'guest' : userId.trim();
    final fileName =
        '${safeUserId}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    return uploadFile(
      file: file,
      fileName: fileName,
      contentType: 'image/$extension',
      folderPath: '$_characterImagesPath/$safeOwnerUid/$safeUserId',
    );
  }

  String _readExtension(String filePath) {
    final normalized = filePath.toLowerCase();
    if (normalized.endsWith('.png')) return 'png';
    if (normalized.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }
}
