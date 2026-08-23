#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint vlc_player.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'vlc_player'
  s.version          = '2.1.3'
  s.summary          = 'A macOS Flutter plugin for video playback using VLCKit.'
  s.description      = <<-DESC
A macOS Flutter plugin for video playback using VideoLAN VLCKit.
                       DESC
  s.homepage         = 'https://github.com/lingjhf/vlc_player'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'lingjhf' => 'lingjhf@users.noreply.github.com' }

  s.source           = { :path => '.' }
  s.source_files = 'vlc_player/Sources/vlc_player/**/*.swift'
  s.resource_bundles = {'vlc_player_privacy' => ['vlc_player/Sources/vlc_player/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'
  s.dependency 'VLCKit', '3.7.3'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.script_phase = {
    :name => 'Patch VLCKit runtime path',
    :execution_position => :after_compile,
    :always_out_of_date => '1',
    :input_files => [
      '${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}/${PRODUCT_NAME}.framework/Versions/A/${PRODUCT_NAME}',
    ],
    :output_files => [
      '${DERIVED_FILE_DIR}/${CONFIGURATION}_vlc_player_patch_vlckit_runtime_path.stamp',
    ],
    :script => <<-SCRIPT
set -e

find "${BUILT_PRODUCTS_DIR}" -path "*/${PRODUCT_NAME}.framework/Versions/A/${PRODUCT_NAME}" -type f | while IFS= read -r FRAMEWORK_BINARY; do
  install_name_tool -change "@loader_path/../Frameworks/VLCKit.framework/Versions/A/VLCKit" "@executable_path/../Frameworks/VLCKit.framework/Versions/A/VLCKit" "$FRAMEWORK_BINARY" || true
done
touch "${DERIVED_FILE_DIR}/${CONFIGURATION}_vlc_player_patch_vlckit_runtime_path.stamp"
    SCRIPT
  }
  s.swift_version = '5.0'
end
