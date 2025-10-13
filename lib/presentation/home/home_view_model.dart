import 'package:flutter/material.dart';
import '../../data/dummy/stories.dart'; // senin Story class ve dummyStories
import 'story_detail_screen.dart'; // hikaye detay ekranı

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hikayeler")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: dummyStories.length,
              itemBuilder: (context, index) {
                final story = dummyStories[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Image.asset(
                      story.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                    title: Text(story.title),
                    subtitle: Text(
                      story.text.length > 30
                          ? '${story.text.substring(0, 30)}...'
                          : story.text,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryDetailScreen(story: story),
                        ),
                      );
                    },
                      
                  ),
                );
              },
            ),
    );
  }
}


