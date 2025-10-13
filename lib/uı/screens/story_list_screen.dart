import 'package:flutter/material.dart';
import '../../data/dummy/stories.dart';

class StoryListScreen extends StatelessWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SketchMind Hikayeler"),
      ),
      body: ListView.builder(
        itemCount: dummyStories.length,
        itemBuilder: (context, index) {
          final story = dummyStories[index];
          return Card(
            child: ListTile(
              leading: Image.asset(story.imageUrl, width: 50, height: 50),
              title: Text(story.title),
              subtitle: Text(story.text),
            ),
          );
        },
      ),
    );
  }
}
