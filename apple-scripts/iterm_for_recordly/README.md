# iterm_for_recordly

AppleScript that opens a pristine iTerm2 window at a fixed position and size,
with a clean prompt, quiet bells, and a large bold font. Designed for
consistent screencast recordings (Recordly, QuickTime, etc.).

## Files

```
iterm_for_recordly/
├── iterm_for_recordly.applescript     # Entry point. Run this.
├── recording.iterm-profile.json       # iTerm2 Dynamic Profile "Recording"         (FunForrest colours)
├── recording-default.iterm-profile.json  # iTerm2 Dynamic Profile "Recording Default" (Dark Background colours)
├── recording-zsh/
│   └── .zshrc                         # Minimal prompt (`$ `, no right prompt)
└── README.md
```

## Usage

```
./iterm_for_recordly.applescript                # FunForrest colours (default behaviour)
./iterm_for_recordly.applescript --default      # Dark Background colours
./iterm_for_recordly.applescript --funforrest   # explicit FunForrest (same as no arg)
```

Every run opens a **new** iTerm2 window. The existing window is not touched,
resized, or renamed. Both variants share:

- Fixed bounds `{423, 83, 1807, 953}` (top-left + bottom-right, in points)
- Menlo Bold 16 font
- Non-blinking box cursor
- All bells and alerts silenced
- No thin-stroke anti-aliasing (survives video compression)
- zsh with a minimal `$ ` prompt, plus the full user `.zshrc` environment

The only difference between the two profiles is the colour scheme.

## Setup on a new machine

The folder is fully relocatable - no paths are hardcoded inside the scripts
or JSON. Drop it anywhere, then do the four steps below.

### 1. Create the two symlinks into iTerm2's DynamicProfiles folder

iTerm2 only auto-loads profiles from `~/Library/Application Support/iTerm2/DynamicProfiles/`.
The profiles in this repo live elsewhere, so they need to be symlinked in:

```bash
mkdir -p ~/Library/Application\ Support/iTerm2/DynamicProfiles

ln -s  "$PWD/recording.iterm-profile.json"          ~/Library/Application\ Support/iTerm2/DynamicProfiles/recording.iterm-profile.json
ln -s  "$PWD/recording-default.iterm-profile.json"  ~/Library/Application\ Support/iTerm2/DynamicProfiles/recording-default.iterm-profile.json
```

Run those two `ln -s` commands from inside this folder. iTerm2 picks up new
dynamic profiles on launch and when the folder contents change; quit and
relaunch iTerm2 once to be sure.

To verify: in iTerm2, Preferences > Profiles - you should see both "Recording"
and "Recording Default" listed, each annotated as a Dynamic Profile.

### 2. Make the AppleScript executable

```bash
chmod +x iterm_for_recordly.applescript
```

### 3. Grant Automation permission

First run will trigger a macOS prompt asking whether your shell (Terminal or
iTerm2) may control iTerm2. Approve. You can review and revoke later in
System Settings > Privacy & Security > Automation.

### 4. Re-capture window coordinates for the new screen

The bounds `{423, 83, 1807, 953}` are specific to the original capture setup:

- Main display: HP 27q, 2560 x 1440 QHD
- Coordinates are in points, relative to the top-left of the MAIN display

On a different screen or a different primary-monitor arrangement, these
coordinates may put the window off-screen, or sized wrong for recording.
Capture new bounds from a window you have positioned the way you want:

```bash
osascript -e 'tell application "iTerm2" to get bounds of front window'
```

Paste the four numbers into `iterm_for_recordly.applescript` on the line
starting with `set bounds of newWindow to ...`. Update the reference comments
at the top of the file too so future you has the right metadata.

This is the **only** edit needed inside the scripts after moving machines;
the `ZDOTDIR` path is resolved at runtime from the script's own location.

## Customising

### Change the prompt

Edit `recording-zsh/.zshrc`. The file sources your real `~/.zshrc` first, then
overrides `PROMPT` and `RPROMPT` at the end. Some common alternatives:

```zsh
PROMPT='$ '            # dollar sign (default)
PROMPT='%# '           # shows # for root, % otherwise
PROMPT='> '            # neutral, no shell hint
PROMPT='%F{244}❯%f '   # subtle grey chevron
```

### Change the colours

Both colour schemes live in their respective `*.iterm-profile.json` files. iTerm2
hot-reloads dynamic profiles on file change, so edits take effect without
restarting iTerm2.

To swap in a different `.itermcolors` preset, extract its RGB values and
paste them into the matching colour blocks in the JSON.

### Re-sync "Recording Default" to match your current Default profile

The colours in `recording-default.iterm-profile.json` are a one-time snapshot
of your main iTerm2 Default profile (which has the "Dark Background" preset
applied). If you later change colours in the Default profile and want the
recording variant to follow, re-extract with a small Python script using
`plistlib` against `~/Library/Preferences/com.googlecode.iterm2.plist`, read
the profile whose `Guid` equals `Default Bookmark Guid`, and overwrite the
colour blocks in `recording-default.iterm-profile.json`.

### Change the window bounds

Edit the single `set bounds of newWindow to {...}` line in the AppleScript.
Update the reference comments at the top so the recorded metadata stays
truthful.

## Troubleshooting

**"No such profile: Recording" (or "Recording Default")**
The symlink into DynamicProfiles is missing or broken, or iTerm2 has not
picked up the new profile yet. Check the symlink, then quit and relaunch iTerm2.

**Window opens in the wrong place**
Main display has changed (different monitor, different arrangement, different
resolution). Re-capture bounds - see step 5 above.

**Minimal prompt is not applied**
The `ZDOTDIR` path in the AppleScript is pointing somewhere that does not
exist on this machine. Verify the path, or update it as per step 1.

**`.zcompdump` keeps appearing inside recording-zsh/**
Harmless. zsh writes its completion cache to `$ZDOTDIR` when that variable
is set, and your real `.zshrc` runs `compinit`. Safe to `.gitignore` or
delete - it regenerates automatically.
