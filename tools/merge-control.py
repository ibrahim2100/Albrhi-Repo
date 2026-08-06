"""Builds the combined package's control from ours plus whatever Theos computed.

    merge-control.py <ours> <theos-generated|""> <out>

The first version of make-suite.sh replaced DEBIAN/control wholesale with suite/control,
and that threw away every field Theos writes for the packaging scheme. The roothide build
then installed as a rootless one, because as far as its control said, it was one.

So the tool's fields are kept and only the ones this project owns are overridden. Keeping
what a tool computed and overriding only what is ours is the safe direction; the reverse is
discarding information we did not know we had -- which is exactly what happened.

Written as a file rather than inline in the shell script because it has to be nested inside
one heredoc already, and a second delimiter inside the first is how that script stopped
parsing.
"""
import sys


def fields(path):
    """[(name, whole entry including its continuation lines)], in file order.

    Debian control folds a long value onto following lines that begin with a space, so a
    line-by-line read that ignores that would split a Description in half and call the
    second half a field.
    """
    if not path:
        return []

    entries, name, lines = [], None, []
    for line in open(path, encoding='utf-8').read().split('\n'):
        if line[:1] in (' ', '\t') and name:
            lines.append(line)
            continue
        if name:
            entries.append((name, '\n'.join(lines)))
        if ':' in line:
            name, lines = line.split(':', 1)[0], [line]
        else:
            name, lines = None, []
    if name:
        entries.append((name, '\n'.join(lines)))
    return entries


def main():
    ours_path, theirs_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    ours = fields(ours_path)
    mine = {name for name, _ in ours}

    # Ours first, in the order they were written, then anything Theos added that we do not
    # define -- which is exactly the set carrying the packaging scheme.
    out = [body for _, body in ours]

    for name, body in fields(theirs_path):
        if name not in mine:
            out.append(body)
            print('  kept from Theos: %s' % name)

    open(out_path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')


if __name__ == '__main__':
    main()
