#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint vlc_player.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'vlc_player'
  s.version          = '2.1.3'
  s.summary          = 'A Flutter plugin for video playback using VLCKit.'
  s.description      = <<-DESC
A Flutter plugin for video playback using VideoLAN VLCKit.
                       DESC
  s.homepage         = 'https://github.com/lingjhf/vlc_player'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'lingjhf' => 'lingjhf@users.noreply.github.com' }

  s.source           = { :path => '.' }
  s.source_files = 'vlc_player/Sources/vlc_player/**/*.swift'
  s.resource_bundles = {'vlc_player_privacy' => ['vlc_player/Sources/vlc_player/PrivacyInfo.xcprivacy']}

  s.dependency 'Flutter'
  s.dependency 'MobileVLCKit', '3.7.3'

  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
