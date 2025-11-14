// lib/data/dummy/avatars.dart

class AvatarCategory {
  final String name;
  final List<String> imageUrls;

  AvatarCategory({required this.name, required this.imageUrls});
}

// Güvenilir Placeholder URL'leri kullanılmıştır.
// Bu URL'ler (placehold.co), sunucudan resim gelmediği sürece tarayıcı/uygulama tarafından metinle doldurulur.
final List<AvatarCategory> predefinedAvatars = [
  AvatarCategory(
    name: "Sevimli Hayvanlar",
    imageUrls: [
      'https://placehold.co/100x100/A1C4FD/white/png?text=CAT', // Kedi
      'https://placehold.co/100x100/ADD8E6/white/png?text=DOG', // Köpek
      'https://placehold.co/100x100/FFD700/white/png?text=FOX', // Tilki
      'https://placehold.co/100x100/F08080/white/png?text=OWL', // Baykuş
      'https://placehold.co/100x100/90EE90/white/png?text=BEAR', // Ayı
      'https://placehold.co/100x100/DDA0DD/white/png?text=RBT', // Tavşan
    ],
  ),
  AvatarCategory(
    name: "Çizgi Film Karakterleri",
    imageUrls: [
      'https://placehold.co/100x100/FFA07A/white/png?text=BOY', // Erkek Çocuk
      'https://placehold.co/100x100/20B2AA/white/png?text=GIRL', // Kız Çocuk
      'https://placehold.co/100x100/B0C4DE/white/png?text=WZD', // Sihirbaz
      'https://placehold.co/100x100/6A5ACD/white/png?text=ASTRO', // Astronot
      'https://placehold.co/100x100/5F9EA0/white/png?text=ROBOT', // Robot
    ],
  ),
  AvatarCategory(
    name: "Fantastik Yaratıklar",
    imageUrls: [
      'https://placehold.co/100x100/8B4513/white/png?text=DRG', // Ejderha
      'https://placehold.co/100x100/FFC0CB/white/png?text=UNI', // Tek boynuzlu at
      'https://placehold.co/100x100/DA70D6/white/png?text=FRY', // Peri
    ],
  ),
];

// Varsayılan avatar URL'i
const String defaultAvatarUrl = 'https://placehold.co/100x100/808080/white/png?text=USER';