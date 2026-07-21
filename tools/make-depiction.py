"""Generates the Sileo depiction for Albrhi.

A depiction is the package page Sileo renders instead of the plain Description
field: tabs, headings, styled text. Sileo reads a JSON description of native
views; Cydia and older managers read an HTML page, so both are produced.

Generated rather than hand-written, so the version and changelog on the page can
never drift from what actually shipped.

Usage: python3 tools/make-depiction.py <out-dir> <version> <base-url>
"""
import json
import os
import re
import sys

out_dir, version, base_url = sys.argv[1], sys.argv[2], sys.argv[3].rstrip('/')

# Derived from the Pages URL (https://<owner>.github.io/<project>) so renaming the
# repository needs no edit here.
_parts = base_url.split('/')
_owner = _parts[2].split('.')[0]
_project = _parts[3] if len(_parts) > 3 else ''
REPO = 'https://github.com/%s/%s' % (_owner, _project)
ISSUES = REPO + '/issues/new'

ACCENT = '#E8590C'

FEATURES = [
    ('Downloads',
     'A native download button in the action row of every post and reel, beside '
     'the save icon. One tap takes the highest quality available straight to '
     'Photos. Stories and view-once DMs have their own button, and reels can be '
     'saved as video or as the original audio.'),

    ('Download Center',
     'A real queue: pause, resume, retry, several transfers at once, and '
     'downloads that keep running after you leave the app. Duplicates are '
     'detected, finished files are cleared once they reach Photos, and a '
     'searchable history records everything you saved.'),

    ('A quieter feed',
     'Remove ads, sponsored and suggested posts, suggested accounts and reels, '
     'Threads posts, Meta AI, the friends map, trending searches and the '
     'explore grid. Hide the stories tray, or the entire feed.'),

    ('Privacy',
     'Watch stories without sending a seen receipt, and choose per story when to '
     'send one. View-once photos and videos stay unseen until you tap the eye '
     'button on that exact message. Hide the typing indicator and disable '
     'screenshot detection.'),

    ('Confirmations',
     'An optional prompt before liking, following, reposting, calling, '
     'commenting or sending a voice message — so a mis-tap never turns into a '
     'notification.'),

    ('Built to fit in',
     'Full Arabic and English with automatic right-to-left layout, SF Symbols, a '
     'customisable accent colour and dark mode. Hold the menu button on your '
     'profile to open it.'),
]


def latest_changelog(path='CHANGELOG.md', limit=3):
    """The most recent few entries, as markdown."""
    try:
        text = open(path, encoding='utf-8').read()
    except OSError:
        return '_No changelog available._'

    sections = re.split(r'\n(?=## )', text)
    # sections[0] is the file title
    return '\n\n'.join(s.strip() for s in sections[1:limit + 1]) or '_No entries._'


def header(title):
    return {'class': 'DepictionSubheaderView', 'title': title, 'useBoldText': True}


def text(body):
    return {'class': 'DepictionMarkdownView', 'markdown': body, 'useSpacing': True}


def spacer(height=12):
    return {'class': 'DepictionSpacerView', 'spacing': height}


def separator():
    return {'class': 'DepictionSeparatorView'}


def row(title, value):
    return {'class': 'DepictionTableTextView', 'title': title, 'text': value}


def link(title, action):
    return {'class': 'DepictionTableButtonView', 'title': title,
            'action': action, 'openExternal': True}


details = [
    text('**Download anything, hide the noise, browse invisibly** — in Arabic or '
         'English.\n\nAlbrhi puts a download button where Instagram should have '
         'put one, strips the feed back to the people you actually follow, and '
         'stops the app reporting what you watch.'),
    spacer(),
    {'class': 'DepictionHeaderView', 'title': 'Beta'},
    text('Tested on Instagram **410.1.0** — the newest build the developer\'s '
         'phone will still accept. Nothing here is pinned to a version number, so '
         'newer builds should work. If one misbehaves, Settings › Diagnostics '
         'writes the bug report for you.'),
    separator(),
]

for name, body in FEATURES:
    details += [header(name), text(body), spacer(8)]

info = [
    row('Version', version),
    row('Developer', 'Ibrahim Ismail AL-Rahn'),
    row('Based on', 'SCInsta by SoCuul'),
    row('Licence', 'GNU GPL v3'),
    row('Tested on', 'Instagram 410.1.0'),
    separator(),
    link('Source code', REPO),
    link('Report an issue', ISSUES),
    link('Instagram — @Ib.11p', 'https://instagram.com/Ib.11p'),
    link('Telegram — @Ib11p', 'https://t.me/Ib11p'),
    separator(),
    text('_Free and open source. Not affiliated with, endorsed by or sponsored by '
         'Instagram or Meta Platforms._'),
]

depiction = {
    'minVersion': '0.1',
    'class': 'DepictionTabView',
    'tintColor': ACCENT,
    'tabs': [
        {'class': 'DepictionStackView', 'tabname': 'Details', 'views': details},
        {'class': 'DepictionStackView', 'tabname': "What's New",
         'views': [text(latest_changelog())]},
        {'class': 'DepictionStackView', 'tabname': 'Info', 'views': info},
    ],
}

os.makedirs(os.path.join(out_dir, 'depictions'), exist_ok=True)

json_path = os.path.join(out_dir, 'depictions', 'albrhi.json')
with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(depiction, f, indent=2, ensure_ascii=False)

# Plain-HTML fallback for managers without native depiction support.
html_features = '\n'.join(
    '<h2>%s</h2><p>%s</p>' % (n, b) for n, b in FEATURES)

html = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Albrhi %(version)s</title>
<style>
:root{--accent:%(accent)s;--bg:#fff;--fg:#1c1c1e;--muted:#6e6e73;--line:#e3e3e6}
@media(prefers-color-scheme:dark){:root{--bg:#000;--fg:#f5f5f7;--muted:#98989d;--line:#2c2c2e}}
body{margin:0;padding:24px 18px 60px;background:var(--bg);color:var(--fg);
font:16px/1.55 -apple-system,BlinkMacSystemFont,system-ui,sans-serif}
main{max-width:620px;margin:0 auto}
h1{font-size:28px;margin:0 0 4px}
.v{color:var(--muted);font-family:ui-monospace,Menlo,monospace;font-size:13px}
.beta{display:inline-block;font-size:11px;font-weight:700;color:var(--accent);
background:color-mix(in srgb,var(--accent) 14%%,transparent);padding:3px 9px;
border-radius:9px;margin-left:8px;vertical-align:3px}
h2{font-size:15px;margin:26px 0 6px;color:var(--accent)}
p{margin:0;color:var(--fg)}
hr{border:0;border-top:1px solid var(--line);margin:26px 0}
footer{color:var(--muted);font-size:13px;margin-top:30px}
a{color:var(--accent)}
</style></head><body><main>
<h1>Albrhi<span class="beta">BETA</span></h1>
<div class="v">%(version)s · by Ibrahim Ismail AL-Rahn</div>
<hr>
<p><strong>Download anything, hide the noise, browse invisibly</strong> — in Arabic or English.</p>
%(features)s
<hr>
<p class="v">Tested on Instagram 410.1.0. Newer builds should work — if one misbehaves,
Settings &rsaquo; Diagnostics writes the bug report for you.</p>
<footer>
<a href="%(repo)s">Source</a> ·
<a href="%(issues)s">Report an issue</a><br>
GPLv3 · based on SCInsta by SoCuul · not affiliated with Instagram or Meta.
</footer>
</main></body></html>
""" % {'version': version, 'accent': ACCENT, 'features': html_features,
     'repo': REPO, 'issues': ISSUES}

with open(os.path.join(out_dir, 'depictions', 'albrhi.html'), 'w', encoding='utf-8') as f:
    f.write(html)

print('Depiction written for %s' % version)
