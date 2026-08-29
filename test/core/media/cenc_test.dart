import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:skystream/core/media/cenc.dart';
import 'package:skystream/core/media/iso_bmff.dart';

/// A real DASH init segment from an encrypted live channel (video track).
///
/// Kept as a fixture because every field that matters here - the sample entry
/// type, the frma fourcc, the tenc IV size and KID - comes from a real
/// packager, and a hand-built one would not have caught the sample-entry
/// header size bug this file now guards.
const String _encryptedVideoInitBase64 =
    'AAAAHGZ0eXBpc29tAAAAAWlzb21hdmMxZGFzaAAAB1xtb292AAAAbG12aGQAAAAA5rjdmea43ZkA'
    'AGGoAAAAAAABAAABAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAECnBzc2gAAAAAmgTweZhAQoarkuZb4Ihf'
    'lQAAA+rqAwAAAQABAOADPABXAFIATQBIAEUAQQBEAEUAUgAgAHgAbQBsAG4AcwA9ACIAaAB0AHQA'
    'cAA6AC8ALwBzAGMAaABlAG0AYQBzAC4AbQBpAGMAcgBvAHMAbwBmAHQALgBjAG8AbQAvAEQAUgBN'
    'AC8AMgAwADAANwAvADAAMwAvAFAAbABhAHkAUgBlAGEAZAB5AEgAZQBhAGQAZQByACIAIAB2AGUA'
    'cgBzAGkAbwBuAD0AIgA0AC4AMAAuADAALgAwACIAPgA8AEQAQQBUAEEAPgA8AFAAUgBPAFQARQBD'
    'AFQASQBOAEYATwA+ADwASwBFAFkATABFAE4APgAxADYAPAAvAEsARQBZAEwARQBOAD4APABBAEwA'
    'RwBJAEQAPgBBAEUAUwBDAFQAUgA8AC8AQQBMAEcASQBEAD4APAAvAFAAUgBPAFQARQBDAFQASQBO'
    'AEYATwA+ADwATABBAF8AVQBSAEwAPgBoAHQAdABwADoALwAvAG8AdgBlAHIAcgBpAGQAZQAuAGkA'
    'bgAuAGMAbABpAGUAbgB0AC8APAAvAEwAQQBfAFUAUgBMAD4APABMAFUASQBfAFUAUgBMAD4AaAB0'
    'AHQAcAA6AC8ALwBuAG8AdAAuAHUAcwBlAGQALwA8AC8ATABVAEkAXwBVAFIATAA+ADwASwBJAEQA'
    'PgBXAGcARgBTAFoAdwBqAFAAYwBrAFcAZwBqAGYANABoAGUAVwArAEwAUgBRAD0APQA8AC8ASwBJ'
    'AEQAPgA8AEMAVQBTAFQATwBNAEEAVABUAFIASQBCAFUAVABFAFMAIAB4AG0AbABuAHMAPQAiACIA'
    'PgA8AEMAbwBuAHQAZQBuAHQAUgBlAGYAPgAxADkANAA0ADAAOAA8AC8AQwBvAG4AdABlAG4AdABS'
    'AGUAZgA+ADwAQwByAHkAcAB0AG8AUABlAHIAaQBvAGQASQBuAGQAZQB4AD4AMAA8AC8AQwByAHkA'
    'cAB0AG8AUABlAHIAaQBvAGQASQBuAGQAZQB4AD4APABDAHIAeQBwAHQAbwBQAGUAcgBpAG8AZABT'
    'AGUAYwBvAG4AZABzAD4AbgB1AGwAbAA8AC8AQwByAHkAcAB0AG8AUABlAHIAaQBvAGQAUwBlAGMA'
    'bwBuAGQAcwA+ADwALwBDAFUAUwBUAE8ATQBBAFQAVABSAEkAQgBVAFQARQBTAD4APABDAEgARQBD'
    'AEsAUwBVAE0APgB4AEYARwAxAGkAawB2AE4AVgAxAHMAPQA8AC8AQwBIAEUAQwBLAFMAVQBNAD4A'
    'PAAvAEQAQQBUAEEAPgA8AC8AVwBSAE0ASABFAEEARABFAFIAPgAAAABFcHNzaAAAAADt74upedZK'
    'zqPIJ9zVHSHtAAAAJQgBEhBnUgFazwhFcqCN/iF5b4tFGgVuYWdyYSIGMTk0NDA4OAAAAAAbaW9k'
    'cwAAAAAQDQBP////f/8OBAAAAAEAAAJWdHJhawAAAFx0a2hkAAAAB+a43ZnmuN2ZAAAAAQAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAANW'
    'AAAB4AAAAAAB8m1kaWEAAAAgbWRoZAAAAADmuN2Z5rjdmQAAYagAAAAAVcQAAAAAADxoZGxyAAAA'
    'AAAAAAB2aWRlAAAAAAAAAAAAAAAARVRJIElTTyBWaWRlbyBNZWRpYSBIYW5kbGVyAAAAAY5taW5m'
    'AAAAFHZtaGQAAAABAAAAAAAAAAAAAAAkZGluZgAAABxkcmVmAAAAAAAAAAEAAAAMdXJsIAAAAAEA'
    'AAFOc3RibAAAAQJzdHNkAAAAAAAAAAEAAADyZW5jdgAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAANW'
    'AeAASAAAAEgAAAAAAAAAAQ9FbGVtZW50YWwgSC4yNjQAAAAAAAAAAAAAAAAAAAAAABj//wAAABBw'
    'YXNwAAAAAQAAAAEAAAA8YXZjQwFNQB7/4QAlJ01AHrkMBsHvN4CIAAADAAgAAAMBlwMAAtxoAD0J'
    '3vcB8IhFmgEABCj+vIAAAABQc2luZgAAAAxmcm1hYXZjMQAAABRzY2htAAAAAGNlbmMAAQAAAAAA'
    'KHNjaGkAAAAgdGVuYwAAAAAAAAEIZ1IBWs8IRXKgjf4heW+LRQAAABBzdHRzAAAAAAAAAAAAAAAQ'
    'c3RzYwAAAAAAAAAAAAAAFHN0c3oAAAAAAAAAAAAAAAAAAAAQc3RjbwAAAAAAAAAAAAAAKG12ZXgA'
    'AAAgdHJleAAAAAAAAAABAAAAAQAAAAAAAAAAAAAAAA==';

void main() {
  final init = Uint8List.fromList(base64.decode(_encryptedVideoInitBase64));

  group('parseInitSegment', () {
    test('reads the protection scheme from a real encrypted init', () {
      final info = parseInitSegment(init)!;
      expect(info.isProtected, isTrue);
      expect(info.perSampleIvSize, 8);
      expect(info.originalFormat, 'avc1');
      expect(
        info.keyId.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '6752015acf084572a08dfe21796f8b45',
      );
    });

    test('returns null for an init segment that is not encrypted', () {
      final plain = rewriteInitSegment(init); // no longer says encv
      expect(parseInitSegment(plain), isNull);
    });
  });

  group('rewriteInitSegment', () {
    // VLC refuses a decrypted fragment whose sample entry still says encv.
    // Renaming rather than removing keeps every size and offset identical,
    // which is what avoids a moof resize and a trun data_offset fixup.
    test('relabels encv to the real codec and neuters sinf', () {
      final out = rewriteInitSegment(init);
      expect(out.length, init.length, reason: 'length must not change');

      final stsd = mp4Path(out, 'moov/trak/mdia/minf/stbl/stsd')!;
      expect(
        mp4Child(out, stsd.payloadStart + 8, stsd.payloadEnd, 'encv'),
        isNull,
        reason: 'encv must be gone',
      );
      expect(
        mp4Child(out, stsd.payloadStart + 8, stsd.payloadEnd, 'avc1'),
        isNotNull,
        reason: 'and replaced by the frma codec',
      );
    });

    test('does not mutate the input', () {
      final before = Uint8List.fromList(init);
      rewriteInitSegment(init);
      expect(init, orderedEquals(before));
    });
  });

  group('decryptSegment', () {
    // Builds a fragment whose ciphertext we generated ourselves, so the test
    // asserts round-trip recovery rather than trusting a captured file.
    test('recovers plaintext across subsamples with one running counter', () {
      final key = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
      final iv = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      // Two samples: the first has a clear prefix, the second is all clear.
      final plaintext = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final expected = Uint8List.fromList(plaintext);

      // Encrypt bytes 8..32 of sample 0 only - the clear prefix must be
      // skipped without advancing the counter.
      final cipher = SICStreamCipher(AESEngine())
        ..init(true, ParametersWithIV(KeyParameter(key), _pad(iv)));
      final enc = Uint8List.fromList(plaintext);
      final slice = Uint8List.sublistView(enc, 8, 32);
      cipher.processBytes(slice, 0, slice.length, slice, 0);

      final segment = _buildFragment(
        mdat: enc,
        sampleSizes: [32, 32],
        ivs: [iv, iv],
        subsamples: [
          [(8, 24)],
          [(32, 0)],
        ],
      );

      final n = decryptSegment(segment, key, ivSize: 8);
      expect(n, 24);

      final mdat = mp4Child(segment, 0, segment.length, 'mdat')!;
      expect(
        segment.sublist(mdat.payloadStart, mdat.payloadEnd),
        orderedEquals(expected),
      );
    });

    test('leaves an unencrypted fragment alone', () {
      final segment = _buildFragment(
        mdat: Uint8List.fromList(List<int>.filled(16, 7)),
        sampleSizes: [16],
        ivs: const [],
        subsamples: const [],
        includeSenc: false,
      );
      final before = Uint8List.fromList(segment);
      expect(decryptSegment(segment, Uint8List(16), ivSize: 8), -1);
      expect(segment, orderedEquals(before));
    });

    test('refuses a fragment whose senc and trun disagree', () {
      final segment = _buildFragment(
        mdat: Uint8List.fromList(List<int>.filled(32, 0)),
        sampleSizes: [16, 16],
        ivs: [Uint8List(8)],
        subsamples: [
          [(0, 16)],
        ],
      );
      expect(
        () => decryptSegment(segment, Uint8List(16), ivSize: 8),
        throwsStateError,
      );
    });
  });
}

Uint8List _pad(Uint8List iv) {
  final out = Uint8List(16);
  out.setRange(0, iv.length, iv);
  return out;
}

/// Builds a minimal moof/mdat fragment good enough to exercise the reader.
Uint8List _buildFragment({
  required Uint8List mdat,
  required List<int> sampleSizes,
  required List<Uint8List> ivs,
  required List<List<(int, int)>> subsamples,
  bool includeSenc = true,
}) {
  Uint8List box(String type, List<int> body) {
    final out = BytesBuilder();
    final size = 8 + body.length;
    out.add([size >> 24 & 0xff, size >> 16 & 0xff, size >> 8 & 0xff, size & 0xff]);
    out.add(type.codeUnits);
    out.add(body);
    return out.toBytes();
  }

  List<int> u32(int v) => [v >> 24 & 0xff, v >> 16 & 0xff, v >> 8 & 0xff, v & 0xff];
  List<int> u16(int v) => [v >> 8 & 0xff, v & 0xff];

  // tfhd: flags 0x020000 (default-base-is-moof) only.
  final tfhd = box('tfhd', [...u32(0x00020000), ...u32(1)]);

  // trun: flags 0x000201 (data-offset + sample-size present).
  final trunBody = <int>[...u32(0x00000201), ...u32(sampleSizes.length)];
  final trunSizeGuess = 8 + trunBody.length + 4 + sampleSizes.length * 4;

  final sencBody = <int>[];
  if (includeSenc) {
    sencBody.addAll(u32(0x00000002)); // use_subsamples
    sencBody.addAll(u32(ivs.length));
    for (var i = 0; i < ivs.length; i++) {
      sencBody.addAll(ivs[i]);
      sencBody.addAll(u16(subsamples[i].length));
      for (final (clear, prot) in subsamples[i]) {
        sencBody.addAll(u16(clear));
        sencBody.addAll(u32(prot));
      }
    }
  }
  final senc = includeSenc ? box('senc', sencBody) : Uint8List(0);

  // moof size = 8 (moof) + 8 (traf) + tfhd + trun + senc
  final moofSize = 8 + 8 + tfhd.length + trunSizeGuess + senc.length;
  // data offset is relative to the moof start and lands on the mdat payload.
  final dataOffset = moofSize + 8;
  trunBody.addAll(u32(dataOffset));
  for (final s in sampleSizes) {
    trunBody.addAll(u32(s));
  }
  final trun = box('trun', trunBody);

  final traf = box('traf', [...tfhd, ...trun, ...senc]);
  final moof = box('moof', traf);
  final mdatBox = box('mdat', mdat);

  return Uint8List.fromList([...moof, ...mdatBox]);
}
