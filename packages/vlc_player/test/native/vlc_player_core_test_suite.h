#ifndef VLC_PLAYER_TEST_NATIVE_VLC_PLAYER_CORE_TEST_SUITE_H_
#define VLC_PLAYER_TEST_NATIVE_VLC_PLAYER_CORE_TEST_SUITE_H_

#include <cstdint>
#include <limits>
#include <memory>
#include <string>
#include <vector>

#include <gtest/gtest.h>

#include "vlc_player_core.h"

namespace vlc_player {
namespace test {

std::vector<std::string> VlcPlayerCoreTestOptions();

namespace {

std::unique_ptr<VlcPlayerCore> MakeCore() {
  return std::make_unique<VlcPlayerCore>(VlcPlayerCoreTestOptions(), [] {});
}

}  // namespace

TEST(VlcPlayerCore, SnapshotWithoutMediaIsIdle) {
  auto core = MakeCore();

  ASSERT_TRUE(core->is_valid()) << core->error();
  const VlcSnapshot snapshot = core->Snapshot();

  EXPECT_EQ(snapshot.state, "idle");
  EXPECT_EQ(snapshot.position, 0);
  EXPECT_EQ(snapshot.duration, 0);
  EXPECT_EQ(snapshot.volume, 100);
  EXPECT_EQ(snapshot.audio_delay, 0);
  EXPECT_EQ(snapshot.subtitle_delay, 0);
}

TEST(VlcPlayerCore, SnapshotEqualityComparesPayloadFields) {
  VlcSnapshot first;
  VlcSnapshot second;

  EXPECT_EQ(first, second);

  second.position = 1;
  EXPECT_NE(first, second);

  second = first;
  second.error_description = "failed";
  EXPECT_NE(first, second);
}

TEST(VlcPlayerCore, RejectsEmptySourceUri) {
  auto core = MakeCore();

  ASSERT_TRUE(core->is_valid()) << core->error();

  EXPECT_EQ(core->SetSource("", {}, {}, 0, false),
            "A non-empty uri is required.");
}

TEST(VlcPlayerCore, ClampsVolumeInSnapshot) {
  auto core = MakeCore();

  ASSERT_TRUE(core->is_valid()) << core->error();

  EXPECT_EQ(core->SetVolume(250), "");
  EXPECT_EQ(core->Snapshot().volume, 200);

  EXPECT_EQ(core->SetVolume(-25), "");
  EXPECT_EQ(core->Snapshot().volume, 0);
}

TEST(VlcPlayerCore, RejectsInvalidPlaybackSpeeds) {
  auto core = MakeCore();

  ASSERT_TRUE(core->is_valid()) << core->error();

  EXPECT_EQ(core->SetPlaybackSpeed(0),
            "A finite positive playback speed is required.");
  EXPECT_EQ(core->SetPlaybackSpeed(-1),
            "A finite positive playback speed is required.");
  EXPECT_EQ(core->SetPlaybackSpeed(std::numeric_limits<double>::infinity()),
            "A finite positive playback speed is required.");
}

TEST(VlcPlayerCore, TakeSnapshotWithoutMediaFailsClearly) {
  auto core = MakeCore();
  std::string error;

  ASSERT_TRUE(core->is_valid()) << core->error();

  const std::vector<uint8_t> data = core->TakeSnapshot(0, 0, &error);

  EXPECT_TRUE(data.empty());
  EXPECT_EQ(error, "No media is loaded.");
}

TEST(VlcPlayerCore, MediaStatsWithoutMediaIsUnavailable) {
  auto core = MakeCore();

  ASSERT_TRUE(core->is_valid()) << core->error();

  const VlcMediaStats stats = core->GetMediaStats();

  EXPECT_FALSE(stats.available);
  EXPECT_EQ(stats.read_bytes, 0);
  EXPECT_EQ(stats.input_bitrate, 0);
  EXPECT_EQ(stats.demux_read_bytes, 0);
  EXPECT_EQ(stats.demux_bitrate, 0);
}

TEST(VlcPlayerCore, CopyPixelsWithoutFrameReturnsFalse) {
  auto core = MakeCore();
  const uint8_t sentinel = 0;
  const uint8_t* buffer = &sentinel;
  uint32_t width = 7;
  uint32_t height = 9;

  ASSERT_TRUE(core->is_valid()) << core->error();

  EXPECT_FALSE(core->CopyPixels(&buffer, &width, &height));
  EXPECT_EQ(buffer, &sentinel);
  EXPECT_EQ(width, 7u);
  EXPECT_EQ(height, 9u);
}

TEST(VlcPlayerCore, ResizeVideoBufferReusesUnchangedBuffers) {
  auto core = MakeCore();

  ASSERT_TRUE(core->is_valid()) << core->error();

  core->ResizeVideoBufferForTesting(4, 4, 16);
  const uint8_t* frame_data = core->FrameBufferDataForTesting();
  const size_t frame_size = core->FrameBufferSizeForTesting();

  core->ResizeVideoBufferForTesting(4, 4, 16);

  EXPECT_EQ(core->FrameBufferDataForTesting(), frame_data);
  EXPECT_EQ(core->FrameBufferSizeForTesting(), frame_size);
  EXPECT_EQ(core->RenderGenerationForTesting(), 0u);
  EXPECT_EQ(core->TextureGenerationForTesting(), 0u);
}

TEST(VlcPlayerCore, CopyPixelsCopiesOnlyNewRenderGenerations) {
  auto core = MakeCore();
  const uint8_t* buffer = nullptr;
  uint32_t width = 0;
  uint32_t height = 0;

  ASSERT_TRUE(core->is_valid()) << core->error();

  core->ResizeVideoBufferForTesting(2, 2, 8);
  core->SimulateFrameForTesting(17);

  EXPECT_TRUE(core->CopyPixels(&buffer, &width, &height));
  EXPECT_EQ(width, 2u);
  EXPECT_EQ(height, 2u);
  ASSERT_NE(buffer, nullptr);
  EXPECT_EQ(buffer[0], 17u);
  EXPECT_EQ(core->TextureGenerationForTesting(),
            core->RenderGenerationForTesting());

  const auto copied_generation = core->TextureGenerationForTesting();
  EXPECT_TRUE(core->CopyPixels(&buffer, &width, &height));
  EXPECT_EQ(core->TextureGenerationForTesting(), copied_generation);

  core->SimulateFrameForTesting(23);
  EXPECT_TRUE(core->CopyPixels(&buffer, &width, &height));
  ASSERT_NE(buffer, nullptr);
  EXPECT_EQ(buffer[0], 23u);
  EXPECT_EQ(core->TextureGenerationForTesting(),
            core->RenderGenerationForTesting());
}

TEST(VlcPlayerCore, DisposeIsIdempotentAndGuardsCommands) {
  auto core = MakeCore();

  ASSERT_TRUE(core->is_valid()) << core->error();

  core->Dispose();
  core->Dispose();

  EXPECT_FALSE(core->is_valid());
  EXPECT_EQ(core->Play(), "The vlc_player has been disposed.");
  EXPECT_EQ(core->SetVolume(100), "The vlc_player has been disposed.");
  EXPECT_EQ(core->SetAudioDelay(1000), "The vlc_player has been disposed.");
  EXPECT_EQ(core->SetSubtitleDelay(1000),
            "The vlc_player has been disposed.");
  EXPECT_TRUE(core->GetAudioTracks().empty());
}

}  // namespace test
}  // namespace vlc_player

#endif  // VLC_PLAYER_TEST_NATIVE_VLC_PLAYER_CORE_TEST_SUITE_H_
