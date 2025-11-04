// lib/data/services/storage_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _storyAudiosPath = 'story_audios/';

  // Verilen dosya yolundaki dosyayı Firebase Storage'a yükler
  // ve indirilebilir (download) URL'sini döndürür.
  Future<String> uploadFile({
    required File file,
    required String fileName,
    required String contentType,
  }) async {
    final uploadPath = '$_storyAudiosPath$fileName';
    
    final Reference ref = _storage.ref().child(uploadPath);

    // Metadata (içerik tipini belirtmek zorunludur)
    final metadata = SettableMetadata(contentType: contentType);

    // Yükleme işlemi
    await ref.putFile(file, metadata);

    // İndirme URL'sini döndür
    return await ref.getDownloadURL();
  }

  // TODO: Hafta 7'de görsel yükleme için de bu servis kullanılabilir.
}