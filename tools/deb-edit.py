"""Reads and edits the metadata of a .deb without dpkg.

Useful when re-hosting a tweak whose control fields are wrong, missing a display
name, or pointing at a repo that no longer exists.

A .deb is an `ar` archive holding three members: debian-binary, control.tar.*
and data.tar.*. Only the control member is touched; the payload is copied through
byte for byte, so the package contents cannot be altered by accident.

Pure standard library, because dpkg-deb does not exist on Windows.

    python tools/deb-edit.py show      thing.deb
    python tools/deb-edit.py set       thing.deb Name="Nice Name" Version=1.2.3
    python tools/deb-edit.py set       thing.deb Description="One line" -o out.deb
    python tools/deb-edit.py normalize thing.deb
    python tools/deb-edit.py label     thing.deb
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

    if command == 'normalize':
        if normalize(path):
            print('Converted %s to control.tar.gz' % path)
        else:
            print('%s already uses gzip — unchanged' % path)
        return

    if command == 'label':
        renamed = label(path)
        if renamed:
            print('Labelled: %s' % renamed)
        else:
            print('%s needs no label' % path)
        return

    if command != 'set':
        raise SystemExit('Unknown command: %s (use show, set, normalize or label)' % command)

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


def normalize(path):
    """Rewrites a control.tar.xz package to use gzip instead.

    The browser editor cannot read xz — decoding it needs an LZMA implementation,
    which is a lot of exacting code for a rare case, and a subtle bug there would
    silently corrupt packages. Converting the container instead costs nothing: the
    control archive is a few kilobytes and the payload is untouched either way.

    Returns True if the file was changed.
    """
    members = ar_read(path)

    for index, (name, data) in enumerate(members):
        if not name.startswith('control.tar'):
            continue

        if name.endswith('.gz'):
            return False        # already readable everywhere

        tar_bytes, _ = open_control(name, data)
        members[index] = ('control.tar.gz', gzip.compress(tar_bytes, 9))

        ar_write(path, members)
        return True

    raise SystemExit('No control.tar member found in %s' % path)


# Architecture is the only reliable statement a package makes about which
# jailbreak it targets, and it is set at build time by the packaging scheme.
FLAVOURS = {
    'iphoneos-arm64': 'rootless',
    'iphoneos-arm64e': 'roothide',
    'iphoneos-arm': 'rootful',
}


def flavour_of(fields):
    """Which jailbreak this package is for, or None if the architecture is unknown."""
    for key, value in fields:
        if key.lower() == 'architecture':
            return FLAVOURS.get(value.strip())
    return None


def label(path):
    """Appends "(rootless)" or "(roothide)" to the package's display name.

    With several flavours of the same tweak in one source, the list in Sileo is
    otherwise a row of identical names and the wrong one gets installed. Reading
    the architecture is exact — no inspection or guessing involved.

    Returns the new name, or None when nothing needed doing.
    """
    members, index, tar_bytes, recompress = load(path)
    fields = parse(read_fields(tar_bytes))

    flavour = flavour_of(fields)
    if not flavour:
        return None

    name_index = None
    for i, (key, _) in enumerate(fields):
        if key.lower() == 'name':
            name_index = i
            break

    if name_index is None:
        # No display name to label. Inventing one from the package id would be a
        # guess, and a wrong display name is worse than none.
        return None

    current = fields[name_index][1]

    # Already carries a flavour, whichever one — leave it alone.
    for known in FLAVOURS.values():
        if '(' + known + ')' in current.lower():
            return None

    updated = '%s (%s)' % (current.strip(), flavour)
    fields[name_index] = (fields[name_index][0], updated)

    members[index] = (members[index][0], recompress(replace_control(tar_bytes, render(fields))))
    ar_write(path, members)

    return updated


def interactive():
    """Runs when the script is opened with no arguments.

    On Windows, launching a script from the file manager passes no arguments and
    closes the console the moment it returns — so an argv-only tool looks like it
    crashed on startup whether it worked or not. This gives it something to do.
    """
    print('deb-edit \u2014 read and change the metadata inside a .deb')
    print()

    path = input('Path to the .deb (or drag the file onto this window): ').strip()
    path = path.strip('"').strip("'")

    if not path:
        return

    if not os.path.exists(path):
        print()
        print('No file at: %s' % path)
        return

    members, index, tar_bytes, recompress = load(path)
    fields = parse(read_fields(tar_bytes))

    print()
    print('Current values:')
    for key, value in fields:
        print('  %-16s %s' % (key + ':', value.split(chr(10))[0]))

    print()
    print('Type  Field=value  to change one. Blank line when finished.')
    print('For example:  Name=My Tweak')
    print()

    changes = {}
    while True:
        line = input('> ').strip()
        if not line:
            break
        if '=' not in line:
            print('  Expected Field=value')
            continue
        key, _, value = line.partition('=')
        changes[key.strip()] = value.strip()
        print('  %s -> %s' % (key.strip(), value.strip()))

    if not changes:
        print()
        print('Nothing changed.')
        return

    fields = apply_changes(fields, changes)
    members[index] = (members[index][0],
                      recompress(replace_control(tar_bytes, render(fields))))

    ar_write(path, members)

    print()
    print('Saved: %s' % path)


if __name__ == '__main__':
    launched_by_double_click = not sys.argv[1:]

    try:
        if launched_by_double_click:
            interactive()
        else:
            main(sys.argv)
    except SystemExit as signal:
        # Our own errors travel as SystemExit with a message; show them plainly
        # rather than letting Python print a traceback over them.
        if signal.code and not isinstance(signal.code, int):
            print(signal.code)
    except KeyboardInterrupt:
        print()
        print('Cancelled.')
    except Exception as error:
        print()
        print('Could not read that file: %s: %s' % (type(error).__name__, error))
        print('If other tools open it fine, please report it.')

    # Without this the console vanishes before anything can be read.
    if launched_by_double_click:
        try:
            input('\nPress Enter to close.')
        except EOFError:
            pass
