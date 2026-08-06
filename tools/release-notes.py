"""Prints the changelog section for the version a control file names.

    release-notes.py <changelog.md> <control>

Its own file rather than a heredoc inside the workflow. A heredoc inside a YAML block
scalar has to satisfy YAML's indentation rules and the shell's terminator rules at the
same time, and getting it wrong breaks the workflow at parse time -- which is what
happened when this was written inline, for the second time today.

The section for this version and no other: release notes that are the whole changelog are
notes nobody reads the top of.
"""
import io
import re
import sys


def main():
    changelog_path, control_path = sys.argv[1], sys.argv[2]

    control = io.open(control_path, encoding='utf-8').read()
    match = re.search(r'^Version: (.*)$', control, re.M)
    if not match:
        print('See CHANGELOG.md.')
        return

    version = match.group(1).strip()
    text = io.open(changelog_path, encoding='utf-8').read()

    # Up to the next heading of the same level, or the end of the file for the newest
    # entry -- which is the common case, since notes are written before the release.
    section = re.search(r'^## v%s\s*\n(.*?)(?=^## |\Z)' % re.escape(version),
                        text, re.M | re.S)

    print(section.group(1).strip() if section else 'See CHANGELOG.md.')


if __name__ == '__main__':
    main()
