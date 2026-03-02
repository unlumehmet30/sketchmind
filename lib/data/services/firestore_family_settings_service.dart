import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';

class FirestoreFamilySettingsService {
  FirestoreFamilySettingsService._internal();
  static final FirestoreFamilySettingsService _instance =
      FirestoreFamilySettingsService._internal();
  factory FirestoreFamilySettingsService() => _instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final ConnectivityService _connectivity = ConnectivityService();
  final String _collection = 'family_settings';

  static const Duration _operationTimeout = Duration(seconds: 10);
  static const int _maxRetryAttempts = 2;

  String _docId({
    required String ownerUid,
    required String userId,
  }) {
    return '${ownerUid.trim()}__${userId.trim()}';
  }

  Future<Map<String, dynamic>?> fetch({
    required String ownerUid,
    required String userId,
  }) async {
    if (ownerUid.trim().isEmpty || userId.trim().isEmpty) {
      return null;
    }

    final doc = await _runWithRetry<DocumentSnapshot<Map<String, dynamic>>>(
      () => _firestore
          .collection(_collection)
          .doc(_docId(ownerUid: ownerUid, userId: userId))
          .get(),
    );

    return doc.data();
  }

  Future<void> upsert({
    required String ownerUid,
    required String userId,
    required Map<String, dynamic> settings,
    required int updatedAtMs,
  }) async {
    if (ownerUid.trim().isEmpty || userId.trim().isEmpty) return;
    await _assertOnlineForWrite();

    await _runWithRetry<void>(
      () => _firestore
          .collection(_collection)
          .doc(_docId(ownerUid: ownerUid, userId: userId))
          .set(
        {
          'ownerUid': ownerUid.trim(),
          'userId': userId.trim(),
          'settings': settings,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtMs': updatedAtMs,
          'schemaVersion': 1,
        },
        SetOptions(merge: true),
      ),
    );
  }

  int readUpdatedAtMs(Map<String, dynamic> documentData) {
    final timestamp = documentData['updatedAt'];
    if (timestamp is Timestamp) {
      return timestamp.millisecondsSinceEpoch;
    }

    final rawMs = documentData['updatedAtMs'];
    if (rawMs is num) return rawMs.toInt();

    return 0;
  }

  Future<void> _assertOnlineForWrite() async {
    final connected = await _connectivity.isConnected();
    if (connected) return;
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'Ayar senkronizasyonu icin internet baglantisi gerekli.',
    );
  }

  Future<T> _runWithRetry<T>(Future<T> Function() action) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        return await action().timeout(_operationTimeout);
      } catch (error, stackTrace) {
        lastError = error;
        if (!_shouldRetry(error) || attempt == _maxRetryAttempts) {
          rethrow;
        }
        if (kDebugMode) {
          debugPrint(
            'Family settings Firestore retry $attempt/$_maxRetryAttempts: $error\n$stackTrace',
          );
        }
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
    }
    throw Exception('Family settings Firestore operation failed: $lastError');
  }

  bool _shouldRetry(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseException) {
      const retryableCodes = <String>{
        'aborted',
        'cancelled',
        'deadline-exceeded',
        'internal',
        'resource-exhausted',
        'unavailable',
      };
      return retryableCodes.contains(error.code);
    }
    return false;
  }
}
