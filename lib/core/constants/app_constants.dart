/// Application-wide non-UI constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'VolticPlayer';
  static const String appTagline = 'Play Everything, Beautifully.';
  static const String appVersion = '1.0.0';
  static const String appBuild = '1';

  // ── Brand / Store URLs ────────────────────────────────────────────────
  static const String websiteUrl = 'https://volticplayer.app';
  static const String privacyPolicyUrl = 'https://volticplayer.app/privacy';
  static const String termsUrl = 'https://volticplayer.app/terms';
  static const String supportEmail = 'support@volticplayer.app';
  static const String googlePlayUrl =
      'https://play.google.com/store/apps/details?id=com.volticplayer.app';
  static const String appStoreUrl =
      'https://apps.apple.com/app/volticplayer/id000000000'; // replace with real ID

  // ── Social profiles ───────────────────────────────────────────────────
  static const String twitterUrl = 'https://twitter.com/volticplayer';
  static const String instagramUrl = 'https://instagram.com/volticplayer';
  static const String youtubeUrl = 'https://youtube.com/@volticplayer';

  // ── Package identifiers ───────────────────────────────────────────────
  static const String androidPackageId = 'com.volticplayer.app';
  static const String iosBundleId = 'com.volticplayer.app';

  // Supported video extensions
  static const List<String> videoExtensions = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'webm',
    'flv',
    'mpeg',
    'mpg',
    'ts',
    'm2ts',
    '3gp',
    'wmv',
    'ogv',
    'm4v',
    'gif',
    'amv',
    '3g2',
    'vob',
    'asf',
    'f4v',
    'dv',
    'divx',
    'rm',
    'rmvb',
    'mxf',
    '3gp2',
  ];

  // Supported audio extensions
  static const List<String> audioExtensions = [
    'mp3',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
    'm4a',
    'alac',
    'ac3',
    'wma',
    'ape',
    'aiff',
    'aif',
    'mid',
    'midi',
    'ra',
    'amr',
    'pcm',
    'dsf',
    'dff',
    'wv',
    'tta',
    'tak',
    'dtshd',
    'dts',
  ];

  // Supported subtitle extensions
  static const List<String> subtitleExtensions = [
    'srt',
    'ass',
    'ssa',
    'vtt',
    'sub',
    'ttml',
  ];

  // Playback speed options
  static const List<double> playbackSpeeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    2.5,
    3.0,
  ];

  // Seek step used by double-tap / gesture (seconds)
  static const int seekStep = 10;

  // Player volume: normal 0–100%, boost up to 200% (media_kit supports >100).
  static const double volumeNormalMax = 100.0;
  static const double volumeBoostMax = 200.0;
  static const List<double> volumePresets = [0, 50, 100, 125, 150, 200];

  // Default thumbnail cache directory name
  static const String thumbnailCacheDir = 'thumbnails';

  // Default downloads layout: a root folder named after the app, containing
  // one app-prefixed subfolder per media kind
  // ("VolticPlayer/VolticPlayer Images", ".../VolticPlayer Videos", ".../VolticPlayer Musics").
  static const String imagesDownloadFolder = '$appName Images';
  static const String videosDownloadFolder = '$appName Videos';
  static const String musicsDownloadFolder = '$appName Musics';
  static const List<String> downloadSubfolders = [
    imagesDownloadFolder,
    videosDownloadFolder,
    musicsDownloadFolder,
  ];

  // Database file name
  static const String databaseName = 'sarwari_player.db';
}
