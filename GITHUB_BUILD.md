# Building Albrhi with GitHub Actions (no local setup)

This builds the rootless `.deb` on GitHub's servers — you don't install anything on Windows.

## One-time setup

### 1. Create a GitHub account
Go to https://github.com and sign up (free).

### 2. Create a new repository
- Click the **+** (top-right) → **New repository**
- Name it e.g. `albrhi`
- Set it **Private** (recommended — it's your build)
- **Don't** initialize with a README
- Click **Create repository**

### 3. Upload the project
Two options:

**A) Web upload (easiest):**
1. Unzip `Albrhi-v3.0.3-source.zip` on your PC — you'll get a `SCInsta-dev` folder.
2. On your new repo page, click **uploading an existing file**.
3. Drag the **contents** of `SCInsta-dev` (not the folder itself — open it first and select everything inside) into the browser.
4. Wait for upload, then click **Commit changes**.

> Important: the `.github` folder must be included. If drag-and-drop skips hidden folders, use GitHub Desktop (option B).

**B) GitHub Desktop (handles the FLEXing submodule properly):**
1. Install GitHub Desktop: https://desktop.github.com
2. Clone your empty repo, copy the `SCInsta-dev` contents in, commit, and push.

## Building

### 4. Run the build
- Go to the **Actions** tab in your repo.
- If prompted, click **"I understand my workflows, enable them"**.
- Select **Build Albrhi tweak for Rootless** on the left.
- Click **Run workflow** → **Run workflow** (green button).
- Wait ~5–10 minutes (first run is slower; later runs use the cached SDK).

### 5. Download the .deb
- When the run finishes (green check), click into it.
- Scroll to **Artifacts** at the bottom.
- Download **`com.albrhi.tweak_3.0.3+rootless.deb`** (it comes zipped — unzip to get the `.deb`).

## Install on your device (Dopamine 2 / rootless)

Transfer the `.deb` to your iPhone and install via **Sileo** or **Zebra** (open the file → install), or over SSH:
```
scp com.albrhi.tweak_3.0.3+rootless.deb mobile@<iphone-ip>:/tmp/
ssh mobile@<iphone-ip> "sudo dpkg -i /tmp/com.albrhi.tweak_3.0.3+rootless.deb && sudo sbreload"
```
Then re-open Instagram. Open settings by holding the ☰ on your profile.

## Notes

- **FLEXing submodule:** the rootless build does **not** need it (it's only used for the non-jailbreak sideload build, gated behind `SIDELOAD`). If the checkout warns about the FLEXing submodule, it's harmless for rootless.
- **Re-building after changes:** any push to `main` re-runs the build automatically. Or use **Run workflow** manually anytime.
- **SDK caching:** the first build downloads the iOS 16.2 SDK (~1 min); subsequent builds reuse it from cache.
- **Build fails?** Open the failed step's log in the Actions run — the error is usually a missing class/selector for your Instagram version. Note it and it can be patched in `src/InstagramHeaders.h`.
