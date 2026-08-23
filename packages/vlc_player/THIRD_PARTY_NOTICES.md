# Third-party notices

`vlc_player` is distributed under the MIT license. The plugin also uses or
integrates with third-party VLC components whose licenses and redistribution
requirements are separate from this package license.

## VideoLAN VLC and libVLC

The native implementations play media through VLC/libVLC runtime libraries.
Applications that distribute VLC runtime files or link against platform VLC
packages must comply with the applicable VideoLAN license terms for those
libraries and bundled plugins.

- VideoLAN: https://www.videolan.org/
- VLC source and license information: https://www.videolan.org/vlc/download-sources.html

## VLCKit and MobileVLCKit

The iOS implementation depends on `MobileVLCKit`, and the macOS implementation
depends on `VLCKit` through CocoaPods. Applications embedding this plugin are
responsible for satisfying the VLCKit and MobileVLCKit binary distribution
requirements for their target platform.

- VLCKit source: https://code.videolan.org/videolan/VLCKit

## libvlcpp

The Windows and Linux implementations vendor official libVLC C++ headers from
`libvlcpp` under `third_party/libvlcpp`. The vendored copy includes its own
LGPL-2.1 license text in `third_party/libvlcpp/COPYING`.

- libvlcpp source: https://code.videolan.org/videolan/libvlcpp
- Local license copy: third_party/libvlcpp/COPYING
