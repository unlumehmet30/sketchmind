// lib/data/dummy/stories.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id; 
  final String title;
  final String text;
  final String imageUrl;
  final String audioUrl; // Ses Kaydı URL'si
  final String userId; // HAFTA 6: Zorunlu Alan
  final DateTime createdAt; // Zorunlu Alan
  final bool isPublic; 

  Story({
    required this.id,
    required this.title,
    required this.text,
    required this.imageUrl,
    this.audioUrl = '', 
    this.userId = 'anonymous', // Varsayılan değer, ancak required olduğu için constructor'da sağlanmalı
    required this.createdAt,
    this.isPublic = true, 
  });

  // Firestore'a kaydetmek için
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPublic': isPublic,
    };
  }

  // Firestore'dan okumak için
  factory Story.fromMap(Map<String, dynamic> map, String id) {
    return Story(
      id: id,
      title: map['title'] as String,
      text: map['text'] as String,
      imageUrl: map['imageUrl'] as String,
      audioUrl: map['audioUrl'] as String? ?? '',
      userId: map['userId'] as String? ?? 'anonymous', 
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isPublic: map['isPublic'] as bool? ?? true,
    );
  }

  // ID güncellemek için
  Story copyWith({
    String? id,
    String? title,
    String? text,
    String? imageUrl,
    String? audioUrl,
    String? userId,
    DateTime? createdAt,
    bool? isPublic,
  }) {
    return Story(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

// HATA DÜZELTMESİ: Dummy hikayelere zorunlu alanlar eklendi
final List<Story> dummyStories = [
  Story(
    id: "dummy_1",
    title: "Küçük Astronot",
    text: "Ay’a ilk kez giden küçük astronotun macerası...",
    imageUrl: "assets/images/astronaut.png",
    userId: "GUEST_001", // Geçici ID eklendi
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  Story(
    id: "dummy_2",
    title: "Ormanın Sırrı",
    text: "Gizemli bir ormanda kaybolan iki arkadaşın hikayesi...",
    imageUrl: "assets/images/forest.png",
    userId: "GUEST_001",
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  Story(
    id: "dummy_3",
    title: "Deniz Altı Macerası",
    text: "Büyülü denizaltında keşfe çıkan bir grup çocuk...",
    imageUrl: "assets/images/underwater.png",
    userId: "GUEST_002",
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];