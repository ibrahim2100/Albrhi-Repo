#!/usr/bin/env python3
"""
Add one LC_LOAD_DYLIB to a Mach-O executable.

    python3 tools/inject-dylib.py <binary> @executable_path/Frameworks/X.dylib

**Why this exists rather than `insert_dylib`.** That tool is not installed on this machine and is
a build from source away; the operation itself is thirty lines. `tools/ipa-inject.html` already
does exactly this in JavaScript for the browser route -- this is the same write, done where the
IPA already is.

What it writes, and the two things that make it safe:

  * **The load command goes in the padding after the existing ones.** A Mach-O keeps its load
    commands between the header and the first section's data, and there is normally slack there.
    Writing past it would overwrite the first bytes of __text, which is a binary that loads and
    then crashes -- so the space is measured, and a file without enough is refused rather than
    damaged.
  * **The region is checked to be zero before it is used.** Slack is not the same as free: a
    linker may have left something there, and "it looked like padding" is not a reason to write
    over it.

The signature is invalidated by any of this, which is expected -- an injected IPA is re-signed
afterwards, by ldid for TrollStore or by whatever certificate is being used.
"""

import struct
import sys

LC_LOAD_DYLIB = 0x0C
LC_SEGMENT_64 = 0x19
MH_MAGIC_64 = 0xFEEDFACF


def inject(path, dylib):
    with open(path, "rb") as handle:
        data = bytearray(handle.read())

    magic, = struct.unpack_from("<I", data, 0)
    if magic != MH_MAGIC_64:
        # A fat binary would need each slice done separately, and an app from the store is thin.
        raise SystemExit("not a thin 64-bit Mach-O (magic %08x) — a fat binary needs each slice" % magic)

    ncmds, sizeofcmds = struct.unpack_from("<II", data, 16)
    header = 32
    end_of_commands = header + sizeofcmds

    # Where the first byte of real content is. The load commands may not grow into it.
    first_section = len(data)
    offset = header
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, offset)
        if cmd == LC_SEGMENT_64:
            segname = data[offset + 8:offset + 24].rstrip(b"\0").decode()
            nsects, = struct.unpack_from("<I", data, offset + 64)
            for i in range(nsects):
                at = offset + 72 + i * 80
                sect_offset, = struct.unpack_from("<I", data, at + 48)
                if sect_offset and segname == "__TEXT":
                    first_section = min(first_section, sect_offset)
        offset += cmdsize

    name = dylib.encode() + b"\0"
    padded = (len(name) + 7) // 8 * 8
    cmdsize = 24 + padded

    room = first_section - end_of_commands
    if room < cmdsize:
        raise SystemExit(
            "no room: %d bytes of padding after the load commands, %d needed" % (room, cmdsize))

    if any(data[end_of_commands:end_of_commands + cmdsize]):
        raise SystemExit("the space after the load commands is not empty — refusing to overwrite it")

    # cmd, cmdsize, name offset, timestamp, current version, compatibility version.
    struct.pack_into("<IIIIII", data, end_of_commands,
                     LC_LOAD_DYLIB, cmdsize, 24, 2, 0x10000, 0x10000)
    data[end_of_commands + 24:end_of_commands + 24 + len(name)] = name

    struct.pack_into("<II", data, 16, ncmds + 1, sizeofcmds + cmdsize)

    with open(path, "wb") as handle:
        handle.write(data)

    print("added LC_LOAD_DYLIB %s (%d bytes, %d of padding left)" % (dylib, cmdsize, room - cmdsize))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    inject(sys.argv[1], sys.argv[2])
