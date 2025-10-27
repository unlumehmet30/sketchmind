// lib/data/dummy/stories.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id; // Firestore ID'si
  final String title;
  final String text;
  final String imageUrl;
  final String audioUrl; // TTS çıktısı veya URL'si
  final bool isPublic;
  final DateTime createdAt;
  final String userId; // Hikayeyi oluşturan kullanıcı ID'si (Hafta 5 ve sonrası)

  Story({
    required this.id,
    required this.title,
    required this.text,
    required this.imageUrl,
    this.audioUrl = '',
    this.isPublic = true,
    required this.createdAt,
    this.userId = 'ai_generated', 
  });

  // Firestore'a kaydetmek için Map'e dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }

  // Firestore'dan gelen Map'ten Story nesnesi oluşturur
  factory Story.fromMap(Map<String, dynamic> map, String id) {
    return Story(
      id: id,
      title: map['title'] as String,
      text: map['text'] as String,
      imageUrl: map['imageUrl'] as String,
      audioUrl: map['audioUrl'] as String? ?? '',
      isPublic: map['isPublic'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      userId: map['userId'] as String? ?? 'unknown',
    );
  }

  // Güncelleme yaparken eski veriyi korumak için kullanılır (özellikle ID güncellemesi için)
  Story copyWith({
    String? id,
    String? title,
    String? text,
    String? imageUrl,
    String? audioUrl,
    bool? isPublic,
    DateTime? createdAt,
    String? userId,
  }) {
    return Story(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }
}

// HAFTA 5 İÇİN GEÇİCİ DUMMY LİSTESİ (Firestore devreye girince kaldırılacak)
final List<Story> dummyStories = [
  // ... (Eski dummy hikayeleriniz burada kalabilir)
];