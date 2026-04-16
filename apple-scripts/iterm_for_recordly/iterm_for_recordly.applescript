#!/usr/bin/osascript
--
-- iterm_for_recordly.applescript
--
-- Opens a NEW iTerm2 window positioned at the exact coordinates used for
-- recording screencasts with Recordly. Captures the new window object on
-- creation (rather than referencing it by name/title), so renames or other
-- windows opening in parallel do not affect targeting.
--
-- ---------------------------------------------------------------------------
-- REFERENCE COORDINATES (captured 2026-04-16)
-- ---------------------------------------------------------------------------
--
--   Window bounds  : {423, 83, 1807, 953}   -- {x1, y1, x2, y2}
--   Top-left       : (423, 83)              -- position
--   Bottom-right   : (1807, 953)
--   Size           : 1384 x 870             -- width x height (points)
--
-- Screen context at capture time:
--
--   Main display   : HP 27q
--   Resolution     : 2560 x 1440 (QHD) @ 60Hz
--   UI scale       : 2560 x 1440 (no Retina scaling on this monitor)
--
-- NOTE: macOS reports window coordinates in POINTS, relative to the
-- top-left of the MAIN display. If you switch the main display, change
-- its resolution, or rearrange displays in System Settings > Displays,
-- these coordinates may land in a different place (or off-screen).
-- Re-capture with:
--
--   osascript -e 'tell application "iTerm2" to get bounds of front window'
--
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- USAGE
-- ---------------------------------------------------------------------------
--
--   ./iterm_for_recordly.applescript                -> FunForrest colours (default)
--   ./iterm_for_recordly.applescript --default      -> Dark Background colours
--   ./iterm_for_recordly.applescript --funforrest   -> explicit FunForrest (same as no arg)
--
-- Regardless of flag, the window always gets:
--   - the reference bounds set above
--   - Menlo Bold 16, non-blinking box cursor, silenced bells
--   - zsh with the minimal recording prompt (via ZDOTDIR, see below)
-- Only the colour scheme differs between flags.
--
-- ---------------------------------------------------------------------------
-- PROFILES
-- ---------------------------------------------------------------------------
--
-- Both profiles below are iTerm2 Dynamic Profiles, stored in this folder and
-- symlinked into ~/Library/Application Support/iTerm2/DynamicProfiles/.
--
-- FunForrest: "Recording" profile, warm autumn palette.
--   Source: recording.iterm-profile.json
--
-- Dark Background: "Recording Default" profile, colours snapshotted from the
-- user's main 'Default' iTerm2 profile (which has the 'Dark Background' preset).
--   Source: recording-default.iterm-profile.json
--
-- ---------------------------------------------------------------------------
-- SHELL / PROMPT
-- ---------------------------------------------------------------------------
--
-- Launches zsh with ZDOTDIR pointing at the sibling "recording-zsh" folder,
-- whose .zshrc sources the user's regular startup files and then overrides
-- PROMPT and RPROMPT to minimal values. This gives a clean prompt from the
-- very first frame - nothing is typed on-screen, nothing briefly flashes.
--
-- The ZDOTDIR path is derived from `path to me` at runtime, so this folder
-- can be relocated (or copied to another machine) without editing any paths
-- inside this file.
--
-- To tweak the recording prompt, edit recording-zsh/.zshrc next to this script.
-- ---------------------------------------------------------------------------

on run argv
	-- Parse the single flag we care about. Default behaviour: FunForrest.
	set useDefaultProfile to false
	repeat with i from 1 to count of argv
		set thisArg to item i of argv as string
		if thisArg is "--default" then
			set useDefaultProfile to true
		else if thisArg is "--funforrest" then
			set useDefaultProfile to false
		end if
	end repeat

	-- Resolve the folder this script lives in, so ZDOTDIR moves with the folder.
	-- `path to me` returns the currently running script's file; dirname it.
	set scriptDir to do shell script "dirname " & quoted form of (POSIX path of (path to me))
	set shellCommand to "/usr/bin/env ZDOTDIR=" & quoted form of (scriptDir & "/recording-zsh") & " /bin/zsh -i"

	tell application "iTerm2"
		activate
		-- `create window` RETURNS the new window object; hold the reference
		-- so we don't depend on titles or front-window order.
		if useDefaultProfile then
			set newWindow to (create window with profile "Recording Default" command shellCommand)
		else
			set newWindow to (create window with profile "Recording" command shellCommand)
		end if
		set bounds of newWindow to {423, 83, 1807, 953}
	end tell
end run
