#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <cstdint>
#include <memory>
#include <string>
#include <variant>
#include <vector>

#include "vlc_player_core.h"
#include "vlc_player_plugin.h"
#include "../../test/native/vlc_player_core_test_suite.h"

namespace vlc_player {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(VlcPlayerPlugin, MissingPlayerReturnsPlayerNotFound) {
  VlcPlayerPlugin plugin(nullptr, nullptr);

  std::string error_code;
  std::string error_message;
  EncodableMap arguments;
  arguments[EncodableValue("viewId")] = EncodableValue(int64_t{42});

  plugin.HandleMethodCall(
      MethodCall("play", std::make_unique<EncodableValue>(arguments)),
      std::make_unique<MethodResultFunctions<>>(
          nullptr,
          [&error_code, &error_message](const std::string &code,
                                        const std::string &message,
                                        const EncodableValue *details) {
            error_code = code;
            error_message = message;
          },
          nullptr));

  EXPECT_EQ(error_code, "player_not_found");
  EXPECT_NE(error_message.find("viewId 42"), std::string::npos);
}

std::vector<std::string> VlcPlayerCoreTestOptions() {
  return {};
}

}  // namespace test
}  // namespace vlc_player
