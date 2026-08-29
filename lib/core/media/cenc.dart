/// MPEG Common Encryption (ISO/IEC 23001-7) decryption for ClearKey content.
///
/// libVLC cannot decrypt CENC on any build this app ships — there is no
/// `tenc`/`senc` parser in its MP4 demuxer at all — so encrypted DASH is
/// decrypted here and handed to the engine as plaintext.
///
/// Two things make this far smaller than it sounds, and both were measured
/// against live content rather than assumed:
///
///  * **`cenc` is AES-CTR, so plaintext and ciphertext are the same length.**
///    Samples are decrypted in place. Nothing is inserted, removed or resized,
///    so no `moof` changes size and no `trun` `data_offset` needs fixing —
///    which is otherwise the classic source of silent corruption here.
///  * **Only the init segment needs relabelling.** VLC refuses a fragment
///    whose sample entry still says `encv`, but it does not care about
///    leftover `senc`/`saiz`/`saio` in the fragments. Verified by playing all
///    four combinations: init-only treatment plays, fragment-only does not.
///    So media segments — which arrive every few seconds, forever — cost
///    decryption and nothing else.
///
/// Scope: `cenc` (AES-CTR) only. Not `cbcs`, not Widevine, not PlayReady.
library;

import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'iso_bmff.dart';

/// What the init segment says about how a track is encrypted.
class CencTrackInfo {
  const CencTrackInfo({
    required this.isProtected,
    required this.perSampleIvSize,
    required this.keyId,
    required this.originalFormat,
  });

  final bool isProtected;

  /// Size in bytes of each sample's IV, normally 8. Zero means the IV comes
  /// from a `saiz`/`saio` constant rather than per sample.
  final int perSampleIvSize;

  /// The 16-byte KID this track's samples are encrypted against.
  final Uint8List keyId;

  /// The codec the track really is, from `frma` — e.g. `avc1`, `mp4a`.
  final String originalFormat;
}

/// Reads the protection scheme out of an init segment, or null when the track
/// is not encrypted.
CencTrackInfo? parseInitSegment(Uint8List init) {
  final stsd = mp4Path(init, 'moov/trak/mdia/minf/stbl/stsd');
  if (stsd == null) return null;

  // stsd payload: version+flags (4), entry_count (4), then sample entries.
  final entry = mp4Child(init, stsd.payloadStart + 8, stsd.payloadEnd, 'encv') ??
      mp4Child(init, stsd.payloadStart + 8, stsd.payloadEnd, 'enca');
  if (entry == null) return null;

  final sinf = _findSinf(init, entry);
  if (sinf == null) return null;

  final frma = mp4Child(init, sinf.payloadStart, sinf.payloadEnd, 'frma');
  final schi = mp4Child(init, sinf.payloadStart, sinf.payloadEnd, 'schi');
  if (frma == null || schi == null) return null;

  final tenc = mp4Child(init, schi.payloadStart, schi.payloadEnd, 'tenc');
  if (tenc == null) return null;

  // tenc payload: version+flags (4), reserved (1), reserved/pattern (1),
  // default_isProtected (1), default_Per_Sample_IV_Size (1), default_KID (16).
  final body = tenc.payloadStart + 4;
  if (body + 20 > tenc.payloadEnd) return null;

  return CencTrackInfo(
    isProtected: init[body + 2] == 1,
    perSampleIvSize: init[body + 3],
    keyId: Uint8List.fromList(init.sublist(body + 4, body + 20)),
    originalFormat: String.fromCharCodes(
      init,
      frma.payloadStart,
      frma.payloadStart + 4,
    ),
  );
}

/// Makes an init segment describe plaintext, without changing its length.
///
/// `encv`/`enca` becomes the real codec from `frma`, and `sinf` becomes `free`
/// — the standard ignore-me box. Both replacements are four characters, so
/// every size and offset in the file is untouched.
///
/// Returns a copy; the input is not modified.
Uint8List rewriteInitSegment(Uint8List init) {
  final out = Uint8List.fromList(init);
  final stsd = mp4Path(out, 'moov/trak/mdia/minf/stbl/stsd');
  if (stsd == null) return out;

  for (final encrypted in const ['encv', 'enca']) {
    final entry = mp4Child(out, stsd.payloadStart + 8, stsd.payloadEnd, encrypted);
    if (entry == null) continue;
    final sinf = _findSinf(out, entry);
    if (sinf == null) continue;
    final frma = mp4Child(out, sinf.payloadStart, sinf.payloadEnd, 'frma');
    if (frma == null) continue;

    final original = String.fromCharCodes(
      out,
      frma.payloadStart,
      frma.payloadStart + 4,
    );
    mp4RenameBox(out, entry, original);
    mp4RenameBox(out, sinf, 'free');
  }
  return out;
}

/// A sample entry has a fixed-size header before its child boxes, and the size
/// differs by handler, so the children cannot be found by walking from the
/// payload start.
Mp4Box? _findSinf(Uint8List data, Mp4Box entry) {
  // Sizes measured from the box start: VisualSampleEntry is 78 bytes of body
  // after the 8-byte header (86), AudioSampleEntry v0 is 28 (36), and v1 adds
  // 16. Try each rather than plumbing the handler type down from hdlr, and let
  // finding a real `sinf` be the validation.
  for (final headerSize in const [86, 36, 28, 52]) {
    final start = entry.start + headerSize;
    if (start >= entry.end) continue;
    final sinf = mp4Child(data, start, entry.end, 'sinf');
    if (sinf != null) return sinf;
  }
  return null;
}

/// Decrypts one media fragment in place.
///
/// [segment] is modified directly and keeps its exact length. Returns the
/// number of bytes decrypted, or -1 when the fragment carries no `senc` and so
/// needs no work.
int decryptSegment(Uint8List segment, Uint8List key, {required int ivSize}) {
  final moof = mp4Child(segment, 0, segment.length, 'moof');
  if (moof == null) return -1;
  final traf = mp4Child(segment, moof.payloadStart, moof.payloadEnd, 'traf');
  if (traf == null) return -1;

  final senc = mp4Child(segment, traf.payloadStart, traf.payloadEnd, 'senc');
  if (senc == null) return -1; // not encrypted

  final layout = _readTrackFragment(segment, traf, moof);
  if (layout == null) return -1;

  final entries = _readSenc(segment, senc, ivSize);
  if (entries.length != layout.sampleSizes.length) {
    throw StateError(
      'CENC: trun says ${layout.sampleSizes.length} samples, '
      'senc says ${entries.length}',
    );
  }

  final cipher = SICStreamCipher(AESEngine());
  final counter = Uint8List(16);
  var offset = layout.dataStart;
  var decrypted = 0;

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final size = layout.sampleSizes[i];

    // Counter block is the IV zero-padded to the AES block size.
    counter.fillRange(0, 16, 0);
    counter.setRange(0, entry.iv.length, entry.iv);
    cipher
      ..reset()
      ..init(false, ParametersWithIV(KeyParameter(key), counter));

    if (entry.subsamples.isEmpty) {
      _xorInPlace(cipher, segment, offset, size);
      decrypted += size;
    } else {
      var at = offset;
      for (final sub in entry.subsamples) {
        at += sub.clearBytes; // clear bytes do not advance the counter
        if (sub.protectedBytes > 0) {
          _xorInPlace(cipher, segment, at, sub.protectedBytes);
          decrypted += sub.protectedBytes;
          at += sub.protectedBytes;
        }
      }
    }
    offset += size;
  }
  return decrypted;
}

/// Runs the keystream over a range in place.
///
/// The cipher is never re-initialised between subsamples of the same sample,
/// so its counter continues across them — which is what CENC requires.
void _xorInPlace(SICStreamCipher cipher, Uint8List data, int start, int length) {
  if (length <= 0) return;
  final end = start + length;
  if (end > data.length) {
    throw StateError('CENC: sample range $start..$end exceeds segment');
  }
  final slice = Uint8List.sublistView(data, start, end);
  cipher.processBytes(slice, 0, length, slice, 0);
}

class _Subsample {
  const _Subsample(this.clearBytes, this.protectedBytes);
  final int clearBytes;
  final int protectedBytes;
}

class _SencEntry {
  const _SencEntry(this.iv, this.subsamples);
  final Uint8List iv;
  final List<_Subsample> subsamples;
}

class _FragmentLayout {
  const _FragmentLayout(this.dataStart, this.sampleSizes);
  final int dataStart;
  final List<int> sampleSizes;
}

/// Reads `tfhd` and `trun` to learn where samples start and how big each is.
_FragmentLayout? _readTrackFragment(Uint8List data, Mp4Box traf, Mp4Box moof) {
  final tfhd = mp4Child(data, traf.payloadStart, traf.payloadEnd, 'tfhd');
  final trun = mp4Child(data, traf.payloadStart, traf.payloadEnd, 'trun');
  if (tfhd == null || trun == null) return null;
  final view = ByteData.sublistView(data);

  var p = tfhd.payloadStart;
  final tfhdFlags = view.getUint32(p) & 0xFFFFFF;
  p += 4 + 4; // version+flags, track_ID
  var baseDataOffset = 0;
  if (tfhdFlags & 0x000001 != 0) {
    baseDataOffset = view.getUint64(p);
    p += 8;
  }
  if (tfhdFlags & 0x000002 != 0) p += 4; // sample_description_index
  if (tfhdFlags & 0x000008 != 0) p += 4; // default_sample_duration
  var defaultSampleSize = 0;
  if (tfhdFlags & 0x000010 != 0) {
    defaultSampleSize = view.getUint32(p);
    p += 4;
  }
  final defaultBaseIsMoof = tfhdFlags & 0x020000 != 0;

  p = trun.payloadStart;
  final trunFlags = view.getUint32(p) & 0xFFFFFF;
  final sampleCount = view.getUint32(p + 4);
  p += 8;
  var dataOffset = 0;
  if (trunFlags & 0x000001 != 0) {
    dataOffset = view.getInt32(p);
    p += 4;
  }
  if (trunFlags & 0x000004 != 0) p += 4; // first_sample_flags

  final sizes = List<int>.filled(sampleCount, defaultSampleSize);
  for (var i = 0; i < sampleCount; i++) {
    if (trunFlags & 0x000100 != 0) p += 4; // duration
    if (trunFlags & 0x000200 != 0) {
      sizes[i] = view.getUint32(p);
      p += 4;
    }
    if (trunFlags & 0x000400 != 0) p += 4; // flags
    if (trunFlags & 0x000800 != 0) p += 4; // composition offset
  }

  final base = defaultBaseIsMoof ? moof.start : baseDataOffset;
  return _FragmentLayout(base + dataOffset, sizes);
}

/// Reads per-sample IVs and subsample ranges from `senc`.
List<_SencEntry> _readSenc(Uint8List data, Mp4Box senc, int ivSize) {
  final view = ByteData.sublistView(data);
  var p = senc.payloadStart;
  final flags = view.getUint32(p) & 0xFFFFFF;
  final count = view.getUint32(p + 4);
  p += 8;
  final usesSubsamples = flags & 0x000002 != 0;

  final entries = <_SencEntry>[];
  for (var i = 0; i < count; i++) {
    final iv = Uint8List.fromList(data.sublist(p, p + ivSize));
    p += ivSize;
    final subs = <_Subsample>[];
    if (usesSubsamples) {
      final n = view.getUint16(p);
      p += 2;
      for (var j = 0; j < n; j++) {
        subs.add(_Subsample(view.getUint16(p), view.getUint32(p + 2)));
        p += 6;
      }
    }
    entries.add(_SencEntry(iv, subs));
  }
  return entries;
}
