"""Reads and edits the metadata of a .deb without dpkg.

Useful when re-hosting a tweak whose control fields are wrong, missing a display
name, or pointing at a repo that no longer exists.

A .deb is an `ar` archive holding three members: debian-binary, control.tar.*
and data.tar.*. Only the control member is touched; the payload is copied through
byte for byte, so the package contents cannot be altered by accident.

Pure standard library, because dpkg-deb does not exist on Windows.

    python tools/deb-edit.py show    thing.deb
    python tools/deb-edit.py set     thing.deb Name="Nice Name" Version=1.2.3
    python tools/deb-edit.py set     thing.deb Description="One line" -o out.deb
"""
import gzip
import io
import lzma
import os
import sys
import tarfile
import time

AR_MAGIC = b'!<arch>\n'


# ---------------------------------------------------------------- ar archive

def ar_read(path):
    """Returns [(name, data)] in archive order."""
    with open(path, 'rb') as f:
        blob = f.read()

    if not blob.startswith(AR_MAGIC):
        raise SystemExit('%s is not an ar archive — is it really a .deb?' % path)

    members = []
    pos = len(AR_MAGIC)

    while pos + 60 <= len(blob):
        header = blob[pos:pos + 60]
        name = header[0:16].decode('utf-8', 'replace').strip()
        size = int(header[48:58].decode('ascii').strip() or 0)
        pos += 60

        data = blob[pos:pos + size]
        pos += size + (size % 2)  # members are padded to an even offset

        if name.endswith('/'):
            name = name[:-1]

        members.append((name, data))

    return members


def ar_write(path, members):
    out = bytearray(AR_MAGIC)
    now = str(int(time.time())).encode()

    for name, data in members:
        out += name.encode().ljust(16)
        out += now.ljust(12)
        out += b'0'.ljust(6)      # uid
        out += b'0'.ljust(6)      # gid
        out += b'100644'.ljust(8)
        out += str(len(data)).encode().ljust(10)
        out += b'`\n'
        out += data
        if len(data) % 2:
            out += b'\n'

    with open(path, 'wb') as f:
        f.write(bytes(out))


# ------------------------------------------------------------ control member

def open_control(name, data):
    """Decompresses a control.tar.* member. Returns (tar bytes, recompress fn)."""
    if name.endswith('.gz'):
        return gzip.decompress(data), lambda raw: gzip.compress(raw, 9)
    if name.endswith('.xz'):
        return lzma.decompress(data), lzma.compress
    if name.endswith('.tar'):
        return data, lambda raw: raw

    raise SystemExit('Unsupported control compression: %s\n'
                     'Only gzip, xz and uncompressed are handled.' % name)


def read_fields(tar_bytes):
    with tarfile.open(fileobj=io.BytesIO(tar_bytes)) as tar:
        for member in tar.getmembers():
            if os.path.basename(member.name) == 'control':
                return tar.extractfile(member).read().decode('utf-8')

    raise SystemExit('No control file inside the control archive.')


def replace_control(tar_bytes, new_text):
    """Rebuilds the control tar with a replaced control file."""
    src = tarfile.open(fileobj=io.BytesIO(tar_bytes))
    buf = io.BytesIO()
    dst = tarfile.open(fileobj=buf, mode='w')

    for member in src.getmembers():
        if os.path.basename(member.name) == 'control':
            payload = new_text.encode('utf-8')
            member.size = len(payload)
            dst.addfile(member, io.BytesIO(payload))
        elif member.isfile():
            dst.addfile(member, src.extractfile(member))
        else:
            dst.addfile(member)

    dst.close()
    src.close()

    return buf.getvalue()


# ------------------------------------------------------------- field editing

def parse(text):
    """Debian control text -> ordered [(field, value)], continuations kept."""
    fields = []
    for line in text.split('\n'):
        if line.startswith((' ', '\t')) and fields:
            fields[-1] = (fields[-1][0], fields[-1][1] + '\n' + line)
        elif ':' in line:
            key, _, value = line.partition(':')
            fields.append((key.strip(), value.strip()))
    return fields


def render(fields):
    return '\n'.join('%s: %s' % (k, v) for k, v in fields) + '\n'


def apply_changes(fields, changes):
    keys = [k.lower() for k, _ in fields]

    for key, value in changes.items():
        if key.lower() in keys:
            index = keys.index(key.lower())
            fields[index] = (fields[index][0], value)
        else:
            fields.append((key, value))

    return fields


# --------------------------------------------------------------------- main

def load(path):
    members = ar_read(path)

    for index, (name, data) in enumerate(members):
        if name.startswith('control.tar'):
            tar_bytes, recompress = open_control(name, data)
            return members, index, tar_bytes, recompress

    raise SystemExit('No control.tar member found in %s' % path)


def main(argv):
    if len(argv) < 3:
        raise SystemExit(__doc__)

    command, path = argv[1], argv[2]
    members, index, tar_bytes, recompress = load(path)
    text = read_fields(tar_bytes)

    if command == 'show':
        for key, value in parse(text):
            first = value.split('\n')[0]
            more = ' …' if '\n' in value else ''
            print('%-16s %s%s' % (key + ':', first, more))
        return

    if command != 'set':
        raise SystemExit('Unknown command: %s (use show or set)' % command)

    changes = {}
    out_path = path

    rest = argv[3:]
    i = 0
    while i < len(rest):
        arg = rest[i]
        if arg in ('-o', '--output'):
            out_path = rest[i + 1]
            i += 2
            continue
        if '=' not in arg:
            raise SystemExit('Expected Field=value, got: %s' % arg)
        key, _, value = arg.partition('=')
        changes[key] = value
        i += 1

    if not changes:
        raise SystemExit('Nothing to change.')

    fields = apply_changes(parse(text), changes)
    members[index] = (members[index][0], recompress(replace_control(tar_bytes, render(fields))))

    ar_write(out_path, members)

    print('Wrote %s' % out_path)
    for key in changes:
        print('  %s = %s' % (key, changes[key]))


if __name__ == '__main__':
    main(sys.argv)
