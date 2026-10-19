import 'dart:math';

class Media {
  Media._();

  static const String video1 = '';
  static const String video4 = '';

  static const List<String> splashVideos = [video1, video4];

  static String randomSplashVideo() =>
      splashVideos[Random().nextInt(splashVideos.length)];
}
