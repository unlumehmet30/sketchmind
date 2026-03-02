import '../dummy/stories.dart';
import 'story_generation_models.dart';

class StoryPromptBuilder {
  static const String promptVersion = 'story_prompt_v2';

  StoryPromptEnvelope build(StoryGenerationRequest request) {
    final ageHint = _ageHint(request.ageProfile);
    final styleHint = _styleHint(request.style);
    final paletteHint = _paletteHint(request.colorPalette);
    final sceneHint = request.sceneMode
        ? 'Hikayeyi ${request.sceneCount} sahneye ayir. Her sahne net bir olay anlatsin.'
        : 'Hikayeyi tek parca ama akici anlat.';

    final characterHint = request.characterProfile == null
        ? ''
        : 'Karakter Profili: Isim=${request.characterProfile!.name}, '
            'Guc=${request.characterProfile!.power}, '
            'Kisilik=${request.characterProfile!.personality}, '
            'Dunya=${request.characterProfile!.world}. '
            '${request.characterProfile!.toyImageUrl.isEmpty ? '' : 'Oyuncak referans gorseli: ${request.characterProfile!.toyImageUrl}.'}';

    final continuationHint = request.parentStory == null
        ? ''
        : 'Bu bir devam bolumu. Onceki bolum basligi: '
            '"${request.parentStory!.title}". '
            'Onceki bolumden ozet: "${_shorten(request.parentStory!.text)}". '
            'Yeni bolum hem baglanti kursun hem yeni bir hedef acsin.';

    final systemHint = [
      'Cocuklar icin guvenli, sicak ve destekleyici bir hikaye yaz.',
      ageHint,
      styleHint,
      paletteHint,
      sceneHint,
      'Korkutucu, siddetli veya zararli icerik uretme.',
      'Kisa ama duygusal olarak tatmin edici final kur.',
    ].join(' ');

    final userPrompt = [
      'Tema: ${request.prompt}.',
      continuationHint,
      characterHint,
    ].where((line) => line.isNotEmpty).join(' ');

    return StoryPromptEnvelope(
      promptVersion: promptVersion,
      systemHint: systemHint,
      userPrompt: userPrompt,
      combinedPrompt: '$systemHint\n$userPrompt',
    );
  }

  String _shorten(String text) {
    if (text.length <= 320) return text;
    return '${text.substring(0, 320)}...';
  }

  String _ageHint(StoryAgeProfile ageProfile) {
    switch (ageProfile) {
      case StoryAgeProfile.age4to6:
        return '4-6 yas seviyesine uygun, cok kisa cumleler ve net kelimeler kullan.';
      case StoryAgeProfile.age7to9:
        return '7-9 yas seviyesine uygun, enerjik ve hayal gucu yuksek bir dil kullan.';
      case StoryAgeProfile.age10to12:
        return '10-12 yas seviyesine uygun, daha katmanli olay orgusu ve karakter gelisimi ekle.';
      case StoryAgeProfile.unknown:
        return 'Yas grubu bilinmiyor; sade ve dengeli bir anlatim kullan.';
    }
  }

  String _styleHint(StoryStyle style) {
    switch (style) {
      case StoryStyle.fairyTale:
        return 'Masal tonunda, umutlu ve buyulu bir atmosfer kur.';
      case StoryStyle.funny:
        return 'Komik ve sicak bir ton kullan; mizah cocuk dostu olsun.';
      case StoryStyle.adventure:
        return 'Macera odakli, tempolu ve kesif hissi veren bir anlatim kullan.';
      case StoryStyle.educational:
        return 'Hikayeye fark ettirmeden ogretici bir mesaj yerlestir.';
      case StoryStyle.bedtime:
        return 'Uyku oncesine uygun, sakin ve rahatlatici bir ton kullan.';
    }
  }

  String _paletteHint(StoryColorPalette palette) {
    switch (palette) {
      case StoryColorPalette.auto:
        return 'Renk paletini hikayenin duygusuna gore sec; cocuk dostu tonlar kullan.';
      case StoryColorPalette.vibrant:
        return 'Canli ve enerjik bir renk paleti kullan; mavi, pembe ve sari tonlarini one cikar.';
      case StoryColorPalette.pastel:
        return 'Pastel ve yumusak tonlar kullan; sakin, nazik ve huzurlu bir atmosfer kur.';
      case StoryColorPalette.warmSunset:
        return 'Gunum batimi hissi veren sicak tonlar kullan; turuncu, mercan ve altin renkleri one cikar.';
      case StoryColorPalette.forest:
        return 'Dogadan ilham alan yesil ve toprak tonlari kullan; kesif hissini guclendir.';
      case StoryColorPalette.ocean:
        return 'Deniz ve gokyuzu tonlari kullan; mavi, turkuaz ve ferah bir renk dili kur.';
      case StoryColorPalette.candy:
        return 'Sekersi ve eglenceli bir palet kullan; pembe, nane ve lila tonlarini dengeli kullan.';
    }
  }
}
