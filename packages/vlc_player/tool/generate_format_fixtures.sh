#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$repo_root/example/assets/format_fixtures"
tmp_dir="$(mktemp -d)"
vlc_bin="${VLC_BIN:-/Applications/VLC.app/Contents/MacOS/VLC}"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

if [[ ! -x "$vlc_bin" ]]; then
  echo "VLC executable not found at $vlc_bin" >&2
  echo "Set VLC_BIN to the VLC executable path and retry." >&2
  exit 1
fi

command -v swift >/dev/null
command -v afconvert >/dev/null
command -v python3 >/dev/null

mkdir -p "$output_dir/hls"

cat >"$tmp_dir/make_video.swift" <<'SWIFT'
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let fileType = AVFileType(CommandLine.arguments[2])
try? FileManager.default.removeItem(at: output)

let writer = try AVAssetWriter(outputURL: output, fileType: fileType)
let width = 160
let height = 90
let input = AVAssetWriterInput(
  mediaType: .video,
  outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
      AVVideoAverageBitRateKey: 120_000,
      AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
    ],
  ]
)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
  assetWriterInput: input,
  sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
  ]
)

writer.add(input)
precondition(writer.startWriting())
writer.startSession(atSourceTime: .zero)

let fps: Int32 = 15
for frame in 0..<30 {
  while !input.isReadyForMoreMediaData {
    Thread.sleep(forTimeInterval: 0.01)
  }

  var buffer: CVPixelBuffer?
  CVPixelBufferCreate(
    kCFAllocatorDefault,
    width,
    height,
    kCVPixelFormatType_32ARGB,
    nil,
    &buffer
  )
  guard let pixelBuffer = buffer else {
    fatalError("Failed to create pixel buffer")
  }

  CVPixelBufferLockBaseAddress(pixelBuffer, [])
  let base = CVPixelBufferGetBaseAddress(pixelBuffer)!
    .assumingMemoryBound(to: UInt8.self)
  let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
  for y in 0..<height {
    for x in 0..<width {
      let offset = y * bytesPerRow + x * 4
      base[offset] = 255
      base[offset + 1] = UInt8((x + frame * 3) % 256)
      base[offset + 2] = UInt8((y * 2 + frame * 5) % 256)
      base[offset + 3] = UInt8((x + y + frame * 7) % 256)
    }
  }
  CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

  let time = CMTime(value: CMTimeValue(frame), timescale: fps)
  if !adaptor.append(pixelBuffer, withPresentationTime: time) {
    print("Failed to append frame: \(writer.error?.localizedDescription ?? "unknown")")
    exit(1)
  }
}

input.markAsFinished()
let semaphore = DispatchSemaphore(value: 0)
writer.finishWriting {
  semaphore.signal()
}
semaphore.wait()

if writer.status != .completed {
  print("Failed to write video: \(writer.error?.localizedDescription ?? "unknown")")
  exit(1)
}
SWIFT

python3 - <<'PY' "$tmp_dir/tone.wav"
import math
import struct
import sys
import wave

output = sys.argv[1]
sample_rate = 16000
frame_count = sample_rate
with wave.open(output, "wb") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(sample_rate)
    for frame in range(frame_count):
        sample = int(math.sin(2 * math.pi * 440 * frame / sample_rate) * 12000)
        wav.writeframesraw(struct.pack("<h", sample))
PY

run_vlc() {
  perl -e 'alarm shift; exec @ARGV' 45 "$vlc_bin" "$@"
}

swift "$tmp_dir/make_video.swift" "$output_dir/video.mp4" public.mpeg-4
swift "$tmp_dir/make_video.swift" "$output_dir/video.mov" com.apple.quicktime-movie

run_vlc -I dummy --play-and-exit "$output_dir/video.mp4" \
  --sout "#standard{access=file,mux=ts,dst=$output_dir/video.ts}" \
  vlc://quit >/dev/null 2>&1
run_vlc -I dummy --play-and-exit "$output_dir/video.mp4" \
  --sout "#standard{access=file,mux=avcodec{mux=matroska},dst=$output_dir/video.mkv}" \
  vlc://quit >/dev/null 2>&1
run_vlc -I dummy --play-and-exit "$output_dir/video.mp4" \
  --sout "#transcode{vcodec=VP80,vb=120,scale=1}:standard{access=file,mux=avcodec{mux=webm},dst=$output_dir/video.webm}" \
  vlc://quit >/dev/null 2>&1

cp "$output_dir/video.ts" "$output_dir/hls/segment.ts"
cat >"$output_dir/hls/playlist.m3u8" <<'M3U8'
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:2
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:2.000,
segment.ts
#EXT-X-ENDLIST
M3U8

cat >"$output_dir/captions.srt" <<'SRT'
1
00:00:00,000 --> 00:00:01,000
Synthetic subtitle fixture.
SRT

afconvert "$tmp_dir/tone.wav" "$output_dir/audio.m4a" -d aac -f m4af
afconvert "$tmp_dir/tone.wav" "$output_dir/audio.flac" -d flac -f flac
run_vlc -I dummy --play-and-exit "$tmp_dir/tone.wav" \
  --sout "#transcode{acodec=mp3,ab=64,channels=1,samplerate=16000}:standard{access=file,mux=dummy,dst=$output_dir/audio.mp3}" \
  vlc://quit >/dev/null 2>&1
run_vlc -I dummy --play-and-exit "$tmp_dir/tone.wav" \
  --sout "#transcode{acodec=opus,ab=64,channels=1,samplerate=48000}:standard{access=file,mux=mux_ogg,dst=$output_dir/audio.opus}" \
  vlc://quit >/dev/null 2>&1
run_vlc -I dummy --play-and-exit "$tmp_dir/tone.wav" \
  --sout "#transcode{acodec=vorb,ab=64,channels=1,samplerate=44100}:standard{access=file,mux=mux_ogg,dst=$output_dir/audio.ogg}" \
  vlc://quit >/dev/null 2>&1

find "$output_dir" -type f -maxdepth 2 -print | sort
