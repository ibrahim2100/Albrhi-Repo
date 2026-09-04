#!/usr/bin/env bash
#
# Build the store copies: standalone dylibs that take one code, on any number of devices, for
# three months.
#
#   bash tools/build-store.sh                 # na9, ninety days from today
#   bash tools/build-store.sh na9 180         # a different window
#
# **These are a different product from everything else this repository builds, and the difference
# is worth reading before changing anything here.** An ordinary Albrhi licence names one device,
# is signed, and can be withdrawn from the server. A store copy is none of those by request: a
# shop sells copies, and asking its customers for a device code each turns the shop into a support
# desk.
#
# What that costs is not hidden: **the code is inside the dylib the shop hands out, so anybody
# holding it can read it.** A credential that works on any device with no server has nothing left
# to check against. The two things it does buy are real:
#
#   * it works on *these* builds only -- an ordinary Albrhi does not refuse the code, it has no
#     path that would accept one, so there is nothing in it to find;
#   * and each copy stops on a date fixed when it was built, which is the one part of this that
#     cannot be shared away. Three months, then the shop gets a fresh dylib.
#
set -euo pipefail

cd "$(dirname "$0")/.."

STORE="${1:-na9}"
DAYS="${2:-90}"

# The shop this build is for. Read from its own site rather than invented: متجر ناصر للتطبيقات,
# https://na9.me/ -- and it is the store's own name that appears on the licence screen, so it has
# to be right rather than approximately right.
STORE_NAME="متجر ناصر للتطبيقات"
STORE_SITE="na9.me"

STORE_UNTIL=$(date -v+${DAYS}d +%s)
HUMAN=$(date -r "$STORE_UNTIL" "+%Y-%m-%d")

OUT="$HOME/Desktop/Albrhi-${STORE}"
TWEAKS="instagram youtube twitter tiktok"

export THEOS="${THEOS:-$HOME/theos}"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/bin:$PATH"

# The app each dylib belongs in, in the file's own name.
#
# `AlbrhiTT_0.20.2.dylib` is obvious to whoever built it and to nobody else -- and the one mistake
# this naming has to prevent is injecting the wrong dylib into an app, which does not fail loudly:
# the hooks simply attach to nothing and the app looks untweaked.
app_name() {
    case "$1" in
        instagram) echo "Instagram" ;;
        youtube)   echo "YouTube" ;;
        twitter)   echo "X-Twitter" ;;
        tiktok)    echo "TikTok" ;;
        *)         echo "$1" ;;
    esac
}

mkdir -p "$OUT"

echo "store   : $STORE  ($STORE_NAME, $STORE_SITE)"
echo "stops   : $HUMAN  (${DAYS} days)"
echo "into    : $OUT"

for TWEAK in $TWEAKS; do
    echo ""
    echo "=== $TWEAK"
    ( cd "tweaks/$TWEAK" && make clean >/dev/null 2>&1 || true )
    ( cd "tweaks/$TWEAK" && make SELFCONTAINED=1 FINALPACKAGE=1 \
        STORE="$STORE" STORE_UNTIL="$STORE_UNTIL" \
        STORE_NAME="$STORE_NAME" STORE_SITE="$STORE_SITE" \
        >/tmp/albrhi-store-$TWEAK.log 2>&1 ) || {
        echo "  build failed — /tmp/albrhi-store-$TWEAK.log" >&2
        grep -a 'error:' "/tmp/albrhi-store-$TWEAK.log" | head -3 >&2 || true
        exit 1
    }

    DYLIB=$(find "tweaks/$TWEAK/.theos/obj" -name '*.dylib' -type f | head -n1)
    [ -n "$DYLIB" ] || { echo "  no dylib produced" >&2; exit 1; }

    # The same three proofs the ordinary standalone build makes, plus the one that is only true
    # of these: the store code has to actually be in the binary, or the shop hands out a copy
    # nobody can activate.
    if otool -L "$DYLIB" | tail -n +3 | grep -qi 'substrate'; then
        echo "  FAILED: still links CydiaSubstrate" >&2; exit 1
    fi
    if nm -u "$DYLIB" | grep -qE '^_MS'; then
        echo "  FAILED: still expects Substrate symbols" >&2; exit 1
    fi
    if ! nm "$DYLIB" | grep -q 'SCILicenseAllowsProduct'; then
        echo "  FAILED: no licence check compiled in" >&2; exit 1
    fi
    # The bytes, not `strings`.
    #
    # Two wrong answers came out of that tool before this line settled: its default minimum length
    # is four and a code like "na9" is three, and even with -n 3 it did not report the string this
    # binary demonstrably contains -- `otool -s __TEXT __cstring` finds it, so the code is there
    # and the tool is the thing that is wrong. A NUL-terminated match on the file itself cannot be
    # confused by either: "na9\0" is the code, and "na9.me" does not contain it.
    if ! python3 -c "import sys; sys.exit(0 if open(sys.argv[1],'rb').read().find(sys.argv[2].encode()+b'\0') >= 0 else 1)" "$DYLIB" "$STORE"; then
        echo "  FAILED: the store code is not in this binary" >&2; exit 1
    fi

    VERSION=$(grep -m1 '^Version:' "tweaks/$TWEAK/control" | awk '{print $2}')
    NAME=$(basename "$DYLIB" .dylib)
    FILE="$(app_name "$TWEAK")_${NAME}_${VERSION}_${STORE}.dylib"
    cp "$DYLIB" "$OUT/$FILE"

    echo "  standalone · licence inside · code '$STORE' present  ·  $FILE"

    ( cd "tweaks/$TWEAK" && make clean >/dev/null 2>&1 || true; rm -rf .theos )
done

cat > "$OUT/README.txt" <<EOF
نسخ ${STORE_NAME} — ${STORE_SITE}
$(printf '=%.0s' $(seq 1 40))

هذه النسخ مخصّصة لمتجر ناصر للتطبيقات وحده.

التفعيل
-------
كود واحد لكل الأجهزة، بلا حدّ لعدد المستخدمين:

        ${STORE}

الملفات، وكل واحد لتطبيقه:
  Instagram_*.dylib    إنستغرام   com.burbn.instagram
  YouTube_*.dylib      يوتيوب     com.google.ios.youtube
  X-Twitter_*.dylib    X          com.atebits.Tweetie2
  TikTok_*.dylib       تيك توك    com.zhiliaoapp.musically

من داخل التطبيق:
  إنستغرام / يوتيوب : إعدادات الأداة › الترخيص
  X / تيك توك        : مطوّلة بإصبعين على الشاشة › الترخيص

المدّة
-----
تعمل هذه النسخ حتى ${HUMAN}، ثم تتوقّف من نفسها ويوفّر المتجر نسخةً جديدة.

ملاحظة
------
الكود يعمل على هذه النسخ فقط. النسخ العادية من البرهي لا تقبله — ليس رفضاً،
بل إنها لا تحوي المسار الذي يقبله أصلاً.

الحقن في IPA
------------
من المتصفح، بلا أي أداة: https://ibrahim2100.github.io/albrhi-repo/inject/
أو محلياً: انظر tools/inject-dylib.py في مستودع البرهي.

بُنيت في $(date "+%Y-%m-%d")
EOF

echo ""
echo "in $OUT:"
ls -lh "$OUT"
