/// Minimal ISO base media file format (ISO/IEC 14496-12) reading.
///
/// Only what CENC decryption needs: walk boxes, find children, and rename a
/// box type in place. Deliberately not a general MP4 library — it never
/// constructs, resizes or reorders a box, because the whole decryption design
/// depends on the file's length and every internal offset staying untouched.
library;

import 'dart:typed_data';

/// A box located within a buffer. Offsets are absolute within that buffer.
class Mp4Box {
  const Mp4Box({
    required this.type,
    required this.start,
    required this.headerSize,
    required this.end,
  });

  /// Four-character box type, e.g. `moof`.
  final String type;

  /// Offset of the box header.
  final int start;

  /// 8 normally, 16 for a 64-bit `largesize` box.
  final int headerSize;

  /// Exclusive end offset.
  final int end;

  int get payloadStart => start + headerSize;
  int get payloadEnd => end;
}

/// Walks the boxes at one level of [data] between [start] and [end].
///
/// Stops rather than throwing on a malformed length, so a truncated or
/// unexpected segment yields the boxes it could read instead of failing the
/// whole request.
Iterable<Mp4Box> mp4Boxes(Uint8List data, [int start = 0, int? end]) sync* {
  final limit = end ?? data.length;
  final view = ByteData.sublistView(data);
  var offset = start;
  while (offset + 8 <= limit) {
    var size = view.getUint32(offset);
    final type = String.fromCharCodes(data, offset + 4, offset + 8);
    var headerSize = 8;
    if (size == 1) {
      if (offset + 16 > limit) return;
      size = view.getUint64(offset + 8);
      headerSize = 16;
    } else if (size == 0) {
      size = limit - offset;
    }
    if (size < headerSize || offset + size > limit) return;
    yield Mp4Box(
      type: type,
      start: offset,
      headerSize: headerSize,
      end: offset + size,
    );
    offset += size;
  }
}

/// The first direct child of the given range with [type].
Mp4Box? mp4Child(Uint8List data, int start, int end, String type) {
  for (final box in mp4Boxes(data, start, end)) {
    if (box.type == type) return box;
  }
  return null;
}

/// Follows a `/`-separated path of container boxes from the top level.
Mp4Box? mp4Path(Uint8List data, String path) {
  var start = 0;
  var end = data.length;
  Mp4Box? found;
  for (final name in path.split('/')) {
    found = mp4Child(data, start, end, name);
    if (found == null) return null;
    start = found.payloadStart;
    end = found.payloadEnd;
  }
  return found;
}

/// Overwrites a box's four-character type in place.
///
/// The replacement must also be four characters, so the box keeps its exact
/// length and nothing downstream shifts.
void mp4RenameBox(Uint8List data, Mp4Box box, String newType) {
  assert(newType.length == 4, 'box types are four characters');
  data.setRange(box.start + 4, box.start + 8, newType.codeUnits);
}
