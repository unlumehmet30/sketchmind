// data/model/story.dart (veya data/dummy/stories.dart)

class Story {
  // Firestore belge kimliği ve routing için gereklidir
  final String id; 
  
  // Temel hikaye verileri
  final String title;
  final String text;
  final String imageUrl; // DALL·E/SD veya asset görseli yolu
  
  // Sesli anlatım ve medya yönetimi için
  final String audioUrl; // Firebase Storage veya TTS çıktısı yolu
  
  // Keşfet sayfası ve kullanıcı yönetimi için
  final bool isPublic; // Hikayenin herkese açık olup olmadığı
  final DateTime createdAt; // Oluşturulma tarihi
  
  // Opsiyonel: Kullanıcı ID'si (Hafta 6 için hazırlık)
  final String? userId; 

  Story({
    required this.id,
    required this.title,
    required this.text,
    required this.imageUrl,
    // Yeni eklenenler:
    this.audioUrl = '', // Varsayılan boş string
    this.isPublic = false, // Varsayılan olarak gizli
    required this.createdAt,
    this.userId,
  });

  // Firestore'dan veri çekerken kullanılacak Factory metod
  // (Hafta 4'te kullanılacak, şimdilik sadece yapı hazır olsun)
  factory Story.fromMap(Map<String, dynamic> data, String documentId) {
    return Story(
      id: documentId,
      title: data['title'] as String,
      text: data['text'] as String,
      imageUrl: data['imageUrl'] as String,
      audioUrl: data['audioUrl'] as String? ?? '',
      isPublic: data['isPublic'] as bool? ?? false,
      createdAt: (data['createdAt'] as dynamic).toDate() as DateTime,
      userId: data['userId'] as String?,
    );
  }

  // Firestore'a veri gönderirken kullanılacak metod
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'isPublic': isPublic,
      'createdAt': createdAt,
      'userId': userId,
    };
  }
}

// Hafta 1'de oluşturulan dummy verileri bu yeni yapıyı destekleyecek şekilde güncelleyelim.
final List<Story> dummyStories = [
  Story(
    id: "dummy_1",
    title: "Küçük Astronot",
    text: "Ay’a ilk kez giden küçük astronotun macerası, yıldız tozları arasında gizemli bir harita bulmasıyla başlar. Bu harita onu daha önce hiç görmediği renkli gezegenlere götürür. Orada uzaylı dostlar edinir ve Dünya'ya getireceği özel bir taş bulur.",
    imageUrl: "assets/images/astronaut.png",
    isPublic: true,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  Story(
    id: "dummy_2",
    title: "Ormanın Sırrı",
    text: "Gizemli bir ormanda kaybolan iki arkadaş, konuşan bir baykuşla tanışır. Baykuş onlara, sadece iyi kalpli çocukların görebileceği ışıldayan bir nehrin yolunu gösterir. Nehirden içtikleri su onlara hayvanların dilini öğrenme yeteneği verir.",
    imageUrl: "assets/images/forest.png",
    isPublic: true,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  Story(
    id: "dummy_3",
    title: "Deniz Altı Macerası",
    text: "Büyülü denizaltında keşfe çıkan bir grup çocuk, parlayan mercan kayalıklarının arasında kayıp bir su perisi şehri keşfeder. Şehrin kraliçesi onlara, okyanusu korumak için sihirli bir kolye hediye eder.",
    imageUrl: "assets/images/underwater.png",
    isPublic: false, // Gizli hikaye örneği
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];