// lib/data/services/connectivity_service.dart

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  // YENİ: Stream dönüş tipini List<ConnectivityResult> olarak güncellendi.
  Stream<List<ConnectivityResult>> get connectivityStream => _connectivity.onConnectivityChanged;

  // Mevcut bağlantı durumunu kontrol eden yardımcı metot
  Future<bool> isConnected() async {
    // YENİ: checkConnectivity artık Future<List<ConnectivityResult>> döndürüyor.
    final connectivityResult = await _connectivity.checkConnectivity();
    
    // Wi-Fi veya Mobil veri içeren herhangi bir sonuç varsa true döndür
    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi)) {
      return true;
    }
    // Bağlantı yoksa veya bilinmiyorsa false döndür
    return false;
  }
}