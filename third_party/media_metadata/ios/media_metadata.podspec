#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint media_metadata.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'media_metadata'
  s.version          = '2.2.2'
  s.summary          = 'A Flutter plugin to read metadata from media files (audio and video) on Android, iOS, macOS, Windows, and Linux.'
  s.description      = <<-DESC
  A Flutter plugin to read metadata from media files (audio and video) on Android, iOS, macOS, Windows, and Linux.
                       DESC
  s.homepage         = 'https://github.com/Noamcreator/media_metadata'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Noam' => 'noam.bourmault@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'media_metadata/Sources/media_metadata/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'media_metadata_privacy' => ['media_metadata/Sources/media_metadata/PrivacyInfo.xcprivacy']}
end
