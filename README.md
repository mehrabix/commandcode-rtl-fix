# Command Code Desktop — RTL fix

Makes **Persian / Arabic / Hebrew** text render right-to-left inside the
[Command Code](https://commandcode.ai/) desktop app.

The app ships only English and Chinese interfaces and never sets a `dir`
attribute, so RTL text was laid out left-to-right: Persian paragraphs hugged the
left edge, and mixed Persian + Latin/code content had broken bidirectional
ordering (punctuation and numbers jumping to the wrong side).

Because the desktop app's source is **not public** (the
[`CommandCodeAI/desktop`](https://github.com/CommandCodeAI/desktop) repo contains
only installers and issue templates), there is nothing to send an upstream code
PR to. This project patches the locally installed app instead. Tracking issue:
[CommandCodeAI/desktop#131](https://github.com/CommandCodeAI/desktop/issues/131).

## How it works

A few small files are added to the app's renderer and referenced from its
`index.html` (allowed by the app's own CSP, since they load from its origin):

| File | Purpose |
| --- | --- |
| `assets/rtl-fix.js` | Tags text blocks that contain RTL characters with `dir="auto"`, so each block resolves its own direction and aligns to the correct edge. Latin-only UI is untouched, code is excluded, and it re-scans on DOM changes (streaming messages, new turns). |
| `assets/rtl-fix.css` | Start-alignment for tagged blocks, per-paragraph direction (`unicode-bidi: plaintext`) for the composer and text fields, the Persian font for RTL-resolved content, and forced left-to-right for code / terminal / editor surfaces. |
| `assets/fonts/rtl-fix-font.woff2` | The Persian font (Vazirmatn, variable 100–900), applied only to content whose direction resolves to RTL. |
| `assets/inject.pl` | Inserts the `<link>` and `<script>` tags into `index.html` idempotently. |

Each platform's installer backs up the original `index.html` as
`.index.html.rtl-fix.bak`.

## Font

Persian / Arabic / Hebrew content is rendered in **[Vazirmatn](https://github.com/rastikerdar/vazirmatn)**
(the maintained Vazir font), bundled locally so no network access is needed.
The `[dir]:dir(rtl)` selectors evaluate the *computed* direction, so English-only
UI keeps the app's original font while RTL content — including the composer as
you type — switches to Vazirmatn. Code, terminals and editors keep their
monospace font.

The font is licensed under the **SIL Open Font License 1.1** — see
[`assets/fonts/OFL.txt`](assets/fonts/OFL.txt).


## Install

### Linux (deb / unpacked builds)

```bash
git clone https://github.com/mehrabix/commandcode-rtl-fix.git
cd commandcode-rtl-fix
sudo bash linux/install.sh
```

Default target is `/opt/Command Code/resources/app`. Override with
`COMMAND_CODE_APP=/path/to/resources/app` for other locations.

> **AppImage and snap** builds mount the renderer read-only and are not
> supported by this script. For AppImage, extract it (`--appimage-extract`),
> patch the extracted tree, and run the extracted `AppRun`. For snap, an
> unpacked build (`.deb`) is recommended.

### macOS

```bash
git clone https://github.com/mehrabix/commandcode-rtl-fix.git
cd commandcode-rtl-fix
sudo bash macos/install.sh
```

Targets `/Applications/Command Code.app`. Editing the bundle invalidates its
code signature, so the script re-signs it ad-hoc (`codesign --sign -`) to keep
it launchable locally. Override with `COMMAND_CODE_APP="/path/to/Command Code.app"`.

### Windows

```powershell
git clone https://github.com/mehrabix/commandcode-rtl-fix.git
cd commandcode-rtl-fix
powershell -ExecutionPolicy Bypass -File windows\install.ps1
```

Targets `%LOCALAPPDATA%\Programs\Command Code\resources\app` (per-user install,
no admin needed) and falls back to `%ProgramFiles%`. Override with
`$env:COMMAND_CODE_APP`.

Then **fully quit Command Code and open it again**.

## Uninstall

```bash
sudo bash linux/uninstall.sh      # Linux
sudo bash macos/uninstall.sh      # macOS
powershell -File windows\uninstall.ps1   # Windows
```

Each restores the backed-up `index.html` and removes the two added files.

## After an update

A Command Code update replaces the renderer and removes the fix. Re-run the
install script afterwards.

## Packaged as `app.asar`?

These scripts expect an unpacked `resources/app/` directory (the official Linux
build is unpacked). If a build ships `resources/app.asar`, extract and repack it
with `npx @electron/asar` — the installer detects this case and tells you.

## Verification

The direction logic was validated in headless Chrome (`test/test.html`,
`test/run.sh`): Persian paragraphs/lists and the composer get `dir="auto"` →
`rtl` with `text-align: start`; English content stays `ltr`/left; a Persian
paragraph containing inline `<code>` is handled; `pre`/`code`, terminals and
editors stay LTR; dynamically inserted (React re-rendered) content is picked up
by the MutationObserver; and the Vazirmatn font file loads and is applied only
to RTL content.

```bash
bash test/run.sh
```

## Scope and caveats

- Interface strings stay English/Chinese; this only fixes the **direction of
  content** you read and type, not translation.
- It edits files owned by the installer; keep the backup so uninstall is clean.
- Not affiliated with Command Code.

## License

The scripts and CSS/JS in this repo are MIT — see [LICENSE](LICENSE). The
bundled Vazirmatn font is under the SIL Open Font License 1.1 — see
[`assets/fonts/OFL.txt`](assets/fonts/OFL.txt).
