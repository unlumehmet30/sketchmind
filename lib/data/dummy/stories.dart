class Story {
  final String title;
  final String text;
  final String imageUrl;

  Story({
    required this.title,
    required this.text,
    required this.imageUrl,
  });
}

final List<Story> dummyStories = [
  Story(
    title: "Küçük Astronot",
    text: "Ay’a ilk kez giden küçük astronotun macerası...",
    imageUrl: "assets/images/astronaut.png",
  ),
  Story(
    title: "Ormanın Sırrı",
    text: "Gizemli bir ormanda kaybolan iki arkadaşın hikayesi...",
    imageUrl: "assets/images/forest.png",
  ),
  Story(
    title: "Deniz Altı Macerası",
    text: "Büyülü denizaltında keşfe çıkan bir grup çocuk...",
    imageUrl: "assets/images/underwater.png",
  ),
];
