import 'package:shared_preferences/shared_preferences.dart';

import '../dummy/stories.dart';

class DialogicPrompt {
  const DialogicPrompt({
    required this.id,
    required this.question,
    required this.coachTip,
  });

  final String id;
  final String question;
  final String coachTip;
}

class StoryMicroQuiz {
  const StoryMicroQuiz({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class FamilyStoryTask {
  const FamilyStoryTask({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
}

class StoryCompanionService {
  static const _taskStatePrefix = 'story_family_task_state_';

  List<DialogicPrompt> buildDialogicPrompts(Story story) {
    final prompts = <DialogicPrompt>[
      const DialogicPrompt(
        id: 'who',
        question: 'Bu bölümde en dikkat çeken karakter kimdi ve neden?',
        coachTip: 'Çocuktan sahneden bir ipucu göstermesini isteyin.',
      ),
      const DialogicPrompt(
        id: 'problem',
        question: 'Karakterin çözmeye çalıştığı sorun neydi?',
        coachTip:
            'Sorunu tek cümlede söylemesini isteyin, sonra kendi kelimeleriyle açıklatın.',
      ),
      const DialogicPrompt(
        id: 'emotion',
        question: 'Sence kahraman o anda ne hissetti?',
        coachTip:
            'Yüz ifadesi/beden dili canlandırması yaptırarak duygu kelimesi buldurun.',
      ),
      const DialogicPrompt(
        id: 'prediction',
        question: 'Bir sonraki sahnede ne olacağını tahmin et.',
        coachTip: 'Tahminini bir "çünkü" cümlesiyle desteklemesini isteyin.',
      ),
      const DialogicPrompt(
        id: 'life_link',
        question: 'Bu hikaye senin hayatına hangi yönüyle benziyor?',
        coachTip:
            'Kısa bir aile örneği verip çocuğun bağ kurmasını kolaylaştırın.',
      ),
    ];

    if (story.scenes.length >= 4) {
      prompts.add(
        const DialogicPrompt(
          id: 'sequence',
          question: 'Sahneleri sırayla anlatır mısın? Başlangıç-orta-son.',
          coachTip: 'Üç adımlı sıralama dili kullanın: önce-sonra-en son.',
        ),
      );
    }

    return prompts;
  }

  StoryMicroQuiz buildSceneQuiz({
    required Story story,
    required StoryScene scene,
  }) {
    final mainGoal = story.originalPrompt.trim().isEmpty
        ? 'görevi tamamlamak'
        : story.originalPrompt.trim();

    final question = 'Sahne ${scene.order}: Bu bölümde ana odak neydi?';
    final options = <String>[
      mainGoal,
      'Hikayeden tamamen kopmak',
      'Sorunu yok saymak',
      'Hiçbir şey denememek',
    ];

    return StoryMicroQuiz(
      id: 'scene_${scene.id}',
      question: question,
      options: options,
      correctIndex: 0,
      explanation:
          'Doğru odak, hikayenin hedefini sürdürmektir. Boyunca ipuçları bunu destekler.',
    );
  }

  List<FamilyStoryTask> buildFamilyTasks(Story story) {
    final tasks = <FamilyStoryTask>[
      const FamilyStoryTask(
        id: 'draw_scene',
        title: 'Sahneyi Çiz',
        description: 'En sevdiğin sahneyi 5 dakikada çiz ve anlat.',
        icon: 'draw',
      ),
      const FamilyStoryTask(
        id: 'retell',
        title: 'Hikayeyi Tekrar Anlat',
        description: 'Başlangıç, gelişme, sonucu kendi cümlelerinle özetle.',
        icon: 'retell',
      ),
      const FamilyStoryTask(
        id: 'role_play',
        title: 'Mini Canlandırma',
        description: 'Ailece 1 dakalık kısa bir rol oyunu yapın.',
        icon: 'roleplay',
      ),
    ];

    if (story.style == StoryStyle.educational) {
      tasks.add(
        const FamilyStoryTask(
          id: 'real_life',
          title: 'Gerçek Hayat Bağlantısı',
          description: 'Hikayedeki fikri evde bir örnekle deneyin.',
          icon: 'discover',
        ),
      );
    } else if (story.style == StoryStyle.bedtime) {
      tasks.add(
        const FamilyStoryTask(
          id: 'breathing',
          title: 'Sakin Nefes Rutini',
          description: 'Hikaye sonrasında 4 derin nefesle günü kapatın.',
          icon: 'calm',
        ),
      );
    }

    return tasks;
  }

  Future<Set<String>> getCompletedTaskIds(String storyId) async {
    final normalizedId = storyId.trim();
    if (normalizedId.isEmpty) return <String>{};

    final prefs = await SharedPreferences.getInstance();
    final values =
        prefs.getStringList('$_taskStatePrefix$normalizedId') ?? <String>[];
    return values.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  }

  Future<void> setTaskCompleted({
    required String storyId,
    required String taskId,
    required bool completed,
  }) async {
    final normalizedStoryId = storyId.trim();
    final normalizedTaskId = taskId.trim();
    if (normalizedStoryId.isEmpty || normalizedTaskId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = await getCompletedTaskIds(normalizedStoryId);
    if (completed) {
      current.add(normalizedTaskId);
    } else {
      current.remove(normalizedTaskId);
    }
    await prefs.setStringList(
      '$_taskStatePrefix$normalizedStoryId',
      current.toList()..sort(),
    );
  }
}
