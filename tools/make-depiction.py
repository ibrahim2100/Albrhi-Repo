"""Generates a Sileo depiction.

A depiction is the package page Sileo renders instead of the plain Description
field: tabs, headings, styled text. Sileo reads a JSON description of native
views; Cydia and older managers read an HTML page, so both are produced.

Generated rather than hand-written, so the version and changelog on the page can
never drift from what actually shipped.

One script, one entry per tweak. The YouTube package shipped with no depiction at
all for three releases, so Sileo fell back to rendering the raw Description field
-- a wall of prose where Instagram had a tabbed page. The fix is not a second
script to keep in sync with this one; it is a table.

Usage: python3 tools/make-depiction.py <out-dir> <version> <base-url> [tweak]

`tweak` is instagram (the default, so the existing call site keeps working) or
youtube. The changelog is read from the current working directory, which is why
callers cd into the tweak's own directory first.
"""
import json
import os
import re
import sys

out_dir, version, base_url = sys.argv[1], sys.argv[2], sys.argv[3].rstrip('/')
tweak = (sys.argv[4] if len(sys.argv) > 4 else 'instagram').lower()

# Derived from the Pages URL (https://<owner>.github.io/<project>) so renaming the
# repository needs no edit here.
_parts = base_url.split('/')
_owner = _parts[2].split('.')[0]
_project = _parts[3] if len(_parts) > 3 else ''
REPO = 'https://github.com/%s/%s' % (_owner, _project)
ISSUES = REPO + '/issues/new'

INSTAGRAM_FEATURES = [
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

YOUTUBE_FEATURES = [
    ('No ads',
     'Stopped at three points, because ads arrive by three routes and blocking '
     'one does nothing about the others. The app stops asking for ads at all, so '
     'they are never sent rather than sent and hidden; promoted rows are dropped '
     'from the feed by the identifier YouTube\'s own servers attach to them; and '
     'the player refuses ads before a video, in the middle of one, and the kind '
     'stitched into the stream itself.'),

    ('Skip the sponsored parts',
     'Paid plugs, self-promotion and subscribe reminders are jumped over using '
     'segments other viewers submitted to SponsorBlock. A short line names what '
     'was skipped and offers an undo, and each segment is coloured on the progress '
     'bar so you can see what is coming. Eight categories, each with its own '
     'switch — intros, endcards, recaps and tangents stay off until you turn them '
     'on, because somebody chose to make that content.'),

    ('Your video is never sent',
     'SponsorBlock offers two ways to ask, and this uses the one that sends only '
     'the first four characters of the video\'s fingerprint — so the reply covers '
     'many videos and the server cannot tell which one you are watching. Nothing '
     'is requested at all when the feature is off, or when every category is off.'),

    ('Background playback',
     'Audio keeps going when you leave the app or lock the screen.'),

    ('Quieter',
     'Silence the prompt to update, since updating replaces the app and removes '
     'this tweak. And optionally hide the paid-promotion banner — off by default, '
     'because it is a disclosure.'),

    ('Settings and diagnostics',
     'Hold two fingers anywhere in YouTube. Arabic and English with right-to-left '
     'layout, and a card at the top saying whether everything actually attached to '
     'your build. The report is also written to Documents/AlbrhiYT-report.txt, so '
     'it is readable even if nothing else worked.'),
]

# Everything that differs between the two package pages, in one place.
TWEAKS = {
    'instagram': {
        'slug': 'albrhi',                       # the existing filename; URLs in
                                                # control already point at it
        'title': 'Albrhi',
        'accent': '#E8590C',
        'features': INSTAGRAM_FEATURES,
        'tagline': '**Download anything, hide the noise, browse invisibly** — in '
                   'Arabic or English.\n\nAlbrhi puts a download button where '
                   'Instagram should have put one, strips the feed back to the '
                   'people you actually follow, and stops the app reporting what '
                   'you watch.',
        'html_tagline': '<strong>Download anything, hide the noise, browse '
                        'invisibly</strong> — in Arabic or English.',
        'app': 'Instagram',
        'tested': 'Instagram 410.1.0',
        'tested_note': 'Tested on Instagram **410.1.0** — the newest build the '
                       'developer\'s phone will still accept. Nothing here is '
                       'pinned to a version number, so newer builds should work. '
                       'If one misbehaves, Settings › Diagnostics writes the bug '
                       'report for you.',
        'rows': [('Based on', 'SCInsta by SoCuul')],
        'footer_html': 'GPLv3 · based on SCInsta by SoCuul · not affiliated with '
                       'Instagram or Meta.',
        'disclaimer': '_Free and open source. Not affiliated with, endorsed by or '
                      'sponsored by Instagram or Meta Platforms._',
    },
    'youtube': {
        'slug': 'albrhi-youtube',
        'title': 'Albrhi for YouTube',
        'accent': '#FF0021',                    # the red the tweak's own panel uses
        'features': YOUTUBE_FEATURES,
        'tagline': '**No ads, skip the sponsored parts, background playback** — in '
                   'Arabic or English.\n\nHooked on YouTube\'s model and service '
                   'layer rather than its views: views get renamed between releases '
                   'and a tweak that hooks them quietly stops working. A player '
                   'response does not.',
        'html_tagline': '<strong>No ads, skip the sponsored parts, background '
                        'playback</strong> — in Arabic or English.',
        'app': 'YouTube',
        'tested': 'YouTube 21.30.5',
        'tested_note': 'Tested on YouTube **21.30.5**. Nothing is pinned to a '
                       'version number: every class is looked up at runtime and '
                       'skipped if it is not there. Hold two fingers anywhere for '
                       'the settings, and the diagnostics page says what attached '
                       'to your build.',
        'rows': [('Segment data', 'SponsorBlock, CC BY-NC-SA 4.0'),
                 ('Markers from', 'iSponsorBlock by Galactic Dev, GPLv3')],
        'footer_html': 'GPLv3 · segment data from SponsorBlock (CC BY-NC-SA 4.0) · '
                       'markers derived from iSponsorBlock by Galactic Dev · not '
                       'affiliated with YouTube or Google.',
        'disclaimer': '_Free and open source. Segment data from SponsorBlock '
                      '(sponsor.ajay.app), CC BY-NC-SA 4.0. The coloured markers are '
                      'derived from iSponsorBlock by Galactic Dev, GPLv3. Not '
                      'affiliated with, endorsed by or sponsored by YouTube or '
                      'Google._',
    },
}

if tweak not in TWEAKS:
    sys.exit('Unknown tweak %r — expected one of: %s'
             % (tweak, ', '.join(sorted(TWEAKS))))

CONFIG = TWEAKS[tweak]
ACCENT = CONFIG['accent']
FEATURES = CONFIG['features']


def _condense(body, limit=170):
    """A bullet's headline: the bold lead it opens with, or its first sentence.

    The changelog is written to explain *why* a change was made, at length. That
    belongs in the file, not on a store page — someone deciding whether to install
    this wants the list, and the reasoning is one tap away on GitHub.

    The bold lead is checked first because these entries are written with one, and
    it is exactly the headline wanted. Looking for a sentence instead used to cut in
    the wrong place: the full stop in "**A proper package page.** Sileo had…" is
    followed by an asterisk rather than a space, so the sentence search walked past
    it and stopped at the end of the line, mid-thought.
    """
    body = re.sub(r'\s+', ' ', body).strip()

    lead = re.match(r'\*\*(.+?)\*\*', body)
    if lead and len(lead.group(0)) <= limit:
        return lead.group(0)

    # Otherwise the first sentence, if it ends early enough to be a headline.
    match = re.search(r'(?<=[.!?])\s', body)
    if match and match.start() <= limit:
        return body[:match.start() + 1].strip()

    if len(body) <= limit:
        return body
    return body[:limit].rsplit(' ', 1)[0].rstrip(' ,;:') + '…'


def changelog_entries(path='CHANGELOG.md', limit=3):
    """The most recent versions, as (title, [headlines]) pairs.

    Parsed rather than pasted. The first version of this dumped three whole entries
    into one markdown view, and Sileo does not render headings — so the page showed
    a literal '## v0.4.1' on top of a wall of prose. Structure has to be built out of
    the views Sileo actually has, which means splitting the file up here.
    """
    try:
        raw = open(path, encoding='utf-8').read()
    except OSError:
        return []

    entries = []

    # sections[0] is the file title and any preamble.
    for section in re.split(r'\n(?=## )', raw)[1:limit + 1]:
        lines = section.strip().split('\n')
        title = lines[0].lstrip('# ').strip()

        # Top-level bullets only, each rejoined from the lines it is wrapped across
        # before being condensed. Reading one physical line was the earlier mistake:
        # a bullet that wrapped came out cut at the margin, mid-sentence.
        #
        # A blank line ends the bullet; the indented paragraphs after it are the
        # reasoning, and are deliberately left out.
        headlines = []
        current = None

        for line in lines[1:]:
            if line.startswith('- '):
                if current:
                    headlines.append(_condense(current))
                current = line[2:]
            elif current is not None:
                if line.strip() and line.startswith(' '):
                    current += ' ' + line.strip()
                else:
                    headlines.append(_condense(current))
                    current = None

        if current:
            headlines.append(_condense(current))

        # A version written as prose rather than bullets still deserves a line.
        if not headlines:
            paragraph = ' '.join(l for l in lines[1:] if l.strip())
            if paragraph:
                headlines.append(_condense(paragraph))

        if headlines:
            entries.append((title, headlines))

    return entries


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
    text(CONFIG['tagline']),
    spacer(),
    {'class': 'DepictionHeaderView', 'title': 'Beta'},
    text(CONFIG['tested_note']),
    separator(),
]

for name, body in FEATURES:
    details += [header(name), text(body), spacer(8)]

# One subheader per version, then its headlines as a list — rather than one markdown
# blob per release, which is what made the page unreadable.
whats_new = []
for entry_title, headlines in changelog_entries():
    whats_new += [
        header(entry_title),
        text('\n'.join('• %s' % line for line in headlines)),
        spacer(10),
    ]

if not whats_new:
    whats_new = [text('_No changelog available._')]

info = [
    row('Version', version),
    row('Developer', 'Ibrahim Ismail AL-Rahn'),
]
info += [row(title, value) for title, value in CONFIG['rows']]
info += [
    row('Licence', 'GNU GPL v3'),
    row('Tested on', CONFIG['tested']),
    separator(),
    link('Source code', REPO),
    link('Report an issue', ISSUES),
    link('Instagram — @Ib.11p', 'https://instagram.com/Ib.11p'),
    link('Telegram — @Ib11p', 'https://t.me/Ib11p'),
    separator(),
    text(CONFIG['disclaimer']),
]

depiction = {
    'minVersion': '0.1',
    'class': 'DepictionTabView',
    'tintColor': ACCENT,
    'tabs': [
        {'class': 'DepictionStackView', 'tabname': 'Details', 'views': details},
        {'class': 'DepictionStackView', 'tabname': "What's New",
         'views': whats_new},
        {'class': 'DepictionStackView', 'tabname': 'Info', 'views': info},
    ],
}

os.makedirs(os.path.join(out_dir, 'depictions'), exist_ok=True)

json_path = os.path.join(out_dir, 'depictions', CONFIG['slug'] + '.json')
with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(depiction, f, indent=2, ensure_ascii=False)

# Plain-HTML fallback for managers without native depiction support.
html_features = '\n'.join(
    '<h2>%s</h2><p>%s</p>' % (n, b) for n, b in FEATURES)

html = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(title)s %(version)s</title>
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
<h1>%(title)s<span class="beta">BETA</span></h1>
<div class="v">%(version)s · by Ibrahim Ismail AL-Rahn</div>
<hr>
<p>%(tagline)s</p>
%(features)s
<hr>
<p class="v">Tested on %(tested)s. Newer builds should work — if one misbehaves, the
diagnostics page writes the report for you.</p>
<footer>
<a href="%(repo)s">Source</a> ·
<a href="%(issues)s">Report an issue</a><br>
%(footer)s
</footer>
</main></body></html>
""" % {'version': version, 'accent': ACCENT, 'features': html_features,
     'repo': REPO, 'issues': ISSUES, 'title': CONFIG['title'],
     'tagline': CONFIG['html_tagline'], 'tested': CONFIG['tested'],
     'footer': CONFIG['footer_html']}

with open(os.path.join(out_dir, 'depictions', CONFIG['slug'] + '.html'), 'w', encoding='utf-8') as f:
    f.write(html)

print('Depiction written: %s %s (%s)' % (CONFIG['title'], version, CONFIG['slug']))
