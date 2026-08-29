/// Turning what a plugin hands us into a usable ClearKey.
///
/// Plugins carry the key in whatever shape their upstream playlist used, and
/// the shapes genuinely differ: Kodi-style `inputstream.adaptive` props use
/// `kid:key` hex pairs, while W3C JWK sources emit base64url. Getting this
/// wrong does not throw — a wrong key decrypts to noise — so parsing is strict
/// and returns null rather than guessing.
///
/// ClearKey only. There is no CDM in this app, so Widevine and PlayReady are
/// out of reach regardless of what a manifest advertises.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/domain/entity/multimedia_item.dart';

/// A 16-byte content key and the key ID it decrypts.
class ClearKey {
  const ClearKey({required this.keyId, required this.key});

  /// The KID the media declares in `tenc` / the manifest's `default_KID`.
  final Uint8List keyId;

  /// The 16-byte AES key.
  final Uint8List key;
}

/// Why a stream's DRM cannot be opened, for telling the user something useful.
enum DrmObstacle {
  /// A licence server using a CDM this app does not have. Never openable.
  widevine,
  playready,

  /// ClearKey, but the key must be fetched from a licence server rather than
  /// being carried in the playlist. Not currently attempted.
  licenceServer,

  /// Encrypted, but nothing identifies how.
  unknown,
}

/// Classifies DRM that [clearKeyFor] could not satisfy.
///
/// Returns null when the stream is not encrypted, or when it is ClearKey with
/// a usable key. Naming the scheme matters: Widevine is permanently out of
/// reach without a CDM, while a missing ClearKey is a plugin problem, and a
/// user told only "DRM" cannot tell those apart.
DrmObstacle? drmObstacleFor(StreamResult stream) {
  if (clearKeyFor(stream) != null) return null;
  final licence = stream.licenseUrl;
  if (licence == null && stream.drmKey == null && stream.drmKid == null) {
    return null; // not encrypted at all
  }
  final lower = licence?.toLowerCase() ?? '';
  if (lower.contains('widevine')) return DrmObstacle.widevine;
  if (lower.contains('playready')) return DrmObstacle.playready;
  if (licence != null && licence.isNotEmpty) return DrmObstacle.licenceServer;
  return DrmObstacle.unknown;
}

/// A short, honest explanation of [obstacle].
String describeDrmObstacle(DrmObstacle obstacle) => switch (obstacle) {
  DrmObstacle.widevine =>
    'This channel uses Widevine DRM, which needs a licence module this player '
        'does not have.',
  DrmObstacle.playready =>
    'This channel uses PlayReady DRM, which needs a licence module this player '
        'does not have.',
  DrmObstacle.licenceServer =>
    'This channel needs a decryption key from a licence server, which this '
        'player cannot request.',
  DrmObstacle.unknown =>
    'This channel is encrypted and no usable decryption key was provided.',
};

/// Extracts a usable ClearKey from [stream], or null when there is not one.
///
/// Returns null for licence-server DRM: obtaining a key from `licenseUrl`
/// needs a request this does not make, and pretending otherwise would produce
/// a black screen rather than an honest refusal.
ClearKey? clearKeyFor(StreamResult stream) {
  final rawKey = stream.drmKey;
  final rawKid = stream.drmKid;
  if (rawKey == null || rawKey.isEmpty) return null;

  // Some plugins pack both halves into drmKey as "kid:key".
  var keyText = rawKey.trim();
  var kidText = rawKid?.trim();
  if (keyText.contains(':')) {
    final parts = keyText.split(':');
    if (parts.length == 2) {
      kidText ??= parts[0].trim();
      keyText = parts[1].trim();
    }
  }
  if (kidText == null || kidText.isEmpty) return null;

  final key = _decode16(keyText);
  final keyId = _decode16(kidText);
  if (key == null || keyId == null) return null;
  return ClearKey(keyId: keyId, key: key);
}

/// Decodes a 16-byte value written as hex or base64url.
///
/// Hex is tried first, with hyphens removed so a UUID-form KID works. That
/// stripping must NOT happen before the base64url attempt: `-` is a legal
/// base64url character, and removing it silently corrupts the value into a
/// key that decrypts to noise instead of failing.
Uint8List? _decode16(String value) {
  final trimmed = value.trim();

  final hex = trimmed.replaceAll('-', '');
  if (hex.length == 32) {
    final out = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) return null;
      out[i] = byte;
    }
    return out;
  }

  // base64url, with or without padding, on the ORIGINAL text.
  try {
    final padded = trimmed.padRight((trimmed.length + 3) & ~3, '=');
    final bytes = base64Url.decode(padded);
    return bytes.length == 16 ? Uint8List.fromList(bytes) : null;
  } catch (_) {
    return null;
  }
}
