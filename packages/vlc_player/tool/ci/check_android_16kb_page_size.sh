#!/usr/bin/env bash
set -euo pipefail

artifact="${1:-example/build/app/outputs/flutter-apk/app-debug.apk}"
page_size="${VLC_PLAYER_ANDROID_PAGE_SIZE:-16384}"

python3 - "$artifact" "$page_size" <<'PY'
import os
import struct
import sys
import zipfile

artifact = sys.argv[1]
page_size = int(sys.argv[2])
# 16 KB page-size Android devices run 64-bit ABIs. Universal debug APKs may
# still contain 32-bit libraries that are irrelevant to this compatibility gate.
checked_abis = {"arm64-v8a", "x86_64"}
pt_load = 1


def error(message):
    print(f"::error::{message}")


def note(message):
    print(message)


def load_segments(data, name):
    if len(data) < 64 or data[:4] != b"\x7fELF":
        raise ValueError(f"{name} is not an ELF shared library")

    elf_class = data[4]
    endian = "<" if data[5] == 1 else ">"
    if elf_class == 2:
        e_phoff = struct.unpack_from(endian + "Q", data, 32)[0]
        e_phentsize = struct.unpack_from(endian + "H", data, 54)[0]
        e_phnum = struct.unpack_from(endian + "H", data, 56)[0]
        for index in range(e_phnum):
            offset = e_phoff + index * e_phentsize
            p_type = struct.unpack_from(endian + "I", data, offset)[0]
            if p_type == pt_load:
                yield struct.unpack_from(endian + "Q", data, offset + 48)[0]
        return

    if elf_class == 1:
        e_phoff = struct.unpack_from(endian + "I", data, 28)[0]
        e_phentsize = struct.unpack_from(endian + "H", data, 42)[0]
        e_phnum = struct.unpack_from(endian + "H", data, 44)[0]
        for index in range(e_phnum):
            offset = e_phoff + index * e_phentsize
            values = struct.unpack_from(endian + "IIIIIIII", data, offset)
            if values[0] == pt_load:
                yield values[7]
        return

    raise ValueError(f"{name} has unsupported ELF class {elf_class}")


def local_data_offset(zip_file, info):
    zip_file.fp.seek(info.header_offset)
    header = zip_file.fp.read(30)
    if len(header) != 30 or header[:4] != b"PK\x03\x04":
        raise ValueError(f"{info.filename} has an invalid local ZIP header")
    name_length, extra_length = struct.unpack_from("<HH", header, 26)
    return info.header_offset + 30 + name_length + extra_length


if not os.path.isfile(artifact):
    error(f"Android artifact not found: {artifact}")
    sys.exit(1)

failures = []
checked = 0
skipped = 0

with zipfile.ZipFile(artifact) as archive:
    for info in archive.infolist():
        if not info.filename.endswith(".so"):
            continue

        parts = info.filename.split("/")
        if "lib" not in parts:
            continue
        lib_index = parts.index("lib")
        if lib_index + 2 >= len(parts):
            continue

        abi = parts[lib_index + 1]
        if abi not in checked_abis:
            skipped += 1
            continue

        checked += 1
        data = archive.read(info)
        try:
            alignments = list(load_segments(data, info.filename))
        except ValueError as exc:
            failures.append(str(exc))
            continue

        for alignment in alignments:
            if alignment < page_size or alignment % page_size != 0:
                failures.append(
                    f"{info.filename} has PT_LOAD alignment {alignment}; "
                    f"expected a multiple of {page_size}"
                )

        if info.compress_type == zipfile.ZIP_STORED:
            offset = local_data_offset(archive, info)
            if offset % page_size != 0:
                failures.append(
                    f"{info.filename} has ZIP data offset {offset}; "
                    f"expected {page_size}-byte alignment"
                )

if failures:
    for failure in failures:
        error(failure)
    sys.exit(1)

if checked == 0:
    note(f"No 64-bit native libraries found in {artifact}.")
else:
    note(
        f"Verified {checked} 64-bit native libraries for "
        f"{page_size}-byte page-size support."
    )
if skipped:
    note(f"Skipped {skipped} non-64-bit native libraries.")
PY
