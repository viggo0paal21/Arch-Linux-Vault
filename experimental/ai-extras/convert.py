"""Switches the config files to the AI extras (Rice Control + screen corners) and back.
Used by enable.sh / disable.sh.

    python3 convert.py HOME check      only check that every file looks as expected
    python3 convert.py HOME on         rewrite the look files to import theme files
    python3 convert.py HOME hypr-on    add the AI EXTRAS block at the end of hyprland.lua
    python3 convert.py HOME hypr-off   remove it again
    python3 convert.py HOME off        put every original back, delete the theme files and corners

"on" knows the exact text of the configs in this vault. If a file looks
different, nothing at all is changed. Originals: <file>.bak-rice-control
"""

import glob
import os
import shutil
import sys
import tempfile

HOME = sys.argv[1]
C = os.path.join(HOME, ".config")
SUFFIX = ".bak-rice-control"

HYPR = os.path.join(C, "hypr/hyprland.lua")
HYPR_BLOCK = ("\n\n\n-- ==== AI EXTRAS (experimental, vault: experimental/ai-extras) ==== --\n"
              "-- Rice Control: border, colors, rounding, blur, gaps (click the cat in Waybar),\n"
              "-- saved in theme.lua. Loaded last, so its values win over the ones in SETTINGS above\n"
              "-- (those only count if theme.lua is missing).\n"
              "package.loaded.theme = nil  -- read the newest theme.lua on every reload\n"
              'require("theme")\n'
              "-- screen corners: black rounded corners under the bar, drawn by Quickshell\n"
              '-- (switch: "screen-corners" in waybar/config.jsonc, -n = never twice)\n'
              'hl.on("hyprland.start", function() hl.exec_cmd("MANGOHUD=0 qs -n -p ~/.config/quickshell/corners") end)\n'
              'hl.on("config.reloaded", function() hl.exec_cmd("sleep 2 && MANGOHUD=0 qs -n -p ~/.config/quickshell/corners") end)\n')

# files only the AI extras write; "off" deletes them
GENERATED = (
    "hypr/theme.lua", "waybar/theme.css", "gtk-3.0/theme.css", "gtk-4.0/theme.css",
    "swaync/theme.css", "rofi/theme.rasi", "kitty/theme.conf", "fontconfig/conf.d/55-rice-fonts.conf",
    "quickshell/corners/shell.qml",
)
# folders enable.sh may have created; "off" removes them again if they are empty
CREATED_DIRS = ("quickshell/corners", "quickshell")
# the old Quickshell font file would fight with Rice Control's: parked while it is on
QS_FONT = "fontconfig/conf.d/60-qs-system-font.conf"

# ---------------------------------------------------------------------------
# "on": (file, exact old text, new text)

EDITS = [
    ("waybar/config.jsonc", '    "margin-right": 0,\n\n\n    // MODULES',
     '    "margin-right": 0,\n\n'
     '    // SCREEN CORNERS (drawn by ~/.config/quickshell/corners, experimental AI extra)\n'
     '    // true = all 4 corners, "top" = only the 2 under the bar, false = off\n'
     '    "screen-corners": "top",\n\n\n    // MODULES'),
    ("waybar/config.jsonc",
     '    "custom/cat": {\n    "format": "(=^.^=)",\n    "tooltip-format": "meow"\n     },',
     '    "custom/cat": {\n    "format": "(=^.^=)",\n    "tooltip-format": "meow",\n'
     '    "on-click": "~/.local/bin/rice-control"\n     },'),

    ("waybar/style.css", '''/* * = APPLIES TO EVERYTHING */
* {
    font-family: "Noto Sans", "JetBrains Mono Nerd Font Propo";
    font-size: 13px;
    font-weight: 600;
}

/* TOOLTIPS (e.g. "meow") */
tooltip,
tooltip.background {
    background-color: rgba(0, 0, 0, 0.85);
    border: 1px solid #ffffff;
    border-radius: 10px;
    box-shadow: none;
}

/* the invisible window frame around the tooltip: no extra line or shadow */
tooltip decoration {
    border: none;
    box-shadow: none;
    background-color: transparent;
}

tooltip label {
    color: #ffffff;
    padding: 2px 4px;
}


/* BAR ITSELF */
window#waybar {
    background: rgba(0, 0, 0, 0.85);
    color: #ffffff;
    transition: background-color 250ms ease;
}

window#waybar.solo {
    background-color: #000000;
}

window#waybar.solo.kitty {
    background-color: rgba(0, 0, 0, 0.85);
}
''', '''/* Colors, font, borders and rounding: theme.css, written by Rice Control (click the cat).
   It also defines @rice_bg, @rice_fg, @rice_glass and @rice_border for this file. */
@import url("theme.css");

/* * = APPLIES TO EVERYTHING */
* {
    font-weight: 600;
}

/* TOOLTIPS (e.g. "meow") */
tooltip label {
    padding: 2px 4px;
}


/* BAR ITSELF */
window#waybar {
    transition: background-color 250ms ease;
}

window#waybar.solo {
    background-color: @rice_bg;
}

window#waybar.solo.kitty {
    background-color: @rice_glass;
}
'''),
    ("waybar/style.css", '@define-color text #ffffff;\n@define-color middle #5a5a5a;',
     '@define-color middle #5a5a5a;'),
    ("waybar/style.css", '#workspaces button {\n    color: @text;', '#workspaces button {\n    color: @rice_fg;'),
    ("waybar/style.css", '''/* TRAY RIGHT-CLICK MENUS */
menu {
    background-color: rgba(0, 0, 0, 0.85);
    border: 1px solid #ffffff;
    border-radius: 10px;
    padding: 4px;
}

menuitem {
    padding: 4px 8px;
    border-radius: 6px;
}

menuitem:hover {
    background-color: #ffffff;
    color: #000000;
}

/* POPUP EXTRA BORDER IS INVISIBLE */
window.popup,
.csd.popup decoration {
    background-color: transparent;
    border: none;
    border-radius: 10px;
    box-shadow: none;
}''', '''/* TRAY RIGHT-CLICK MENUS */
menu {
    padding: 4px;
}

menuitem {
    padding: 4px 8px;
}

/* POPUP EXTRA BORDER IS INVISIBLE */
window.popup,
.csd.popup decoration {
    background-color: transparent;
    border: none;
    box-shadow: none;
}'''),

    ("gtk-3.0/gtk.css", None, '''/* Colors, borders and rounding: theme.css, written by Rice Control (click the cat in Waybar). */
@import url("theme.css");

/* GLASS EFFECT: only the window gets the color (theme.css), everything inside
   stays see-through, otherwise the layers stack up and get darker */
.view, treeview, iconview, scrolledwindow, viewport, menubar, toolbar {
    background-color: transparent;
}

/* RIGHT-CLICK MENUS */
menu, .context-menu {
    padding: 4px;
}

menuitem {
    padding: 4px 8px;
}

/* the popup window around a menu: no second frame, no shadow */
window.popup,
.csd.popup decoration {
    background-color: transparent;
    border: none;
    box-shadow: none;
}
'''),

    ("gtk-4.0/gtk.css", None, '''/* Colors, borders and rounding: theme.css, written by Rice Control (click the cat in Waybar). */
@import url("theme.css");

/* headerbar and sidebar stay see-through, the window color shows through */
:root {
    --headerbar-bg-color: transparent;
    --headerbar-backdrop-color: transparent;
    --sidebar-bg-color: transparent;
    --sidebar-backdrop-color: transparent;
}
'''),

    ("swaync/style.css", '''
/* my look: 75 % black like kitty, the blur comes from Hyprland */
:root {
    --noti-bg: 0, 0, 0;
    --noti-bg-alpha: 0.85;
    --noti-bg-hover: rgba(255, 255, 255, 0.1);
    --noti-bg-darker: rgba(0, 0, 0, 0.85);
    --cc-bg: rgba(0, 0, 0, 0.85);
    --border-radius: 10px;
    --notification-shadow: none;
}''', '''
/* Colors, border and rounding: theme.css, written by Rice Control (click the cat in Waybar).
   The blur comes from Hyprland. */
@import url("theme.css");
'''),

    ("rofi/config.rasi", '''@theme "/dev/null"


*{
    bg: #000000;
    bg-glass: #000000d9;
    fg: #FFFFFF;
    dim: #737373;
    accent: #FFFFFF;

    font: "Noto Sans 12";
    background-color: transparent;
    text-color: @fg;
}


window {
    background-color: @bg-glass;
    width: 600px;
    //    background-color: @bg;
    border: 1px;
    border-radius: 10px;
    border-color: @accent;
    padding: 12px;
}''', '''@theme "/dev/null"

// colors (@bg, @bg-glass, @fg, @accent), font, border and rounding:
// theme.rasi, written by Rice Control (click the cat in Waybar)
@import "~/.config/rofi/theme.rasi"


*{
    dim: #737373;

    background-color: transparent;
    text-color: @fg;
}


window {
    width: 600px;
    padding: 12px;
}'''),
    ("rofi/config.rasi", '''element selected {
    background-color: @accent;
    text-color: @bg;
    border-radius: 5px;
}

''', ''),

    ("kitty/kitty.conf", "background_opacity 0.85",
     "# opacity, colors and font: theme.conf, written by Rice Control (click the cat in Waybar)\n"
     "include theme.conf\n"),
]

# whole files replaced (old = None): only if they still contain this
WHOLE_FILE_MARKERS = {
    "gtk-3.0/gtk.css": "@define-color theme_bg_color          #000000;",
    "gtk-4.0/gtk.css": "--window-bg-color: rgba(0, 0, 0, 0.85);",
}


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    """Temp file + rename in the same folder: never half a file."""
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".rice-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.chmod(tmp, os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o644)
    os.replace(tmp, path)


def plan_on():
    """New text per file, or a list of problems. Changes nothing."""
    problems, new = [], {}
    for rel, old, replacement in EDITS:
        path = os.path.join(C, rel)
        if path not in new:
            try:
                new[path] = read(path)
            except OSError as e:
                problems.append(f"{rel}: {e.strerror}")
                new[path] = None
        text = new[path]
        if text is None:
            continue
        if old is None:
            if WHOLE_FILE_MARKERS[rel] not in text:
                problems.append(f"{rel}: sieht anders aus als erwartet")
                continue
            new[path] = replacement
        elif text.count(old) != 1:
            problems.append(f"{rel}: Stelle nicht genau einmal gefunden: {old.strip()[:50]!r}")
        else:
            new[path] = text.replace(old, replacement)
    hypr = read(HYPR)
    if 'require("theme")' in hypr or "quickshell/corners" in hypr:
        problems.append("hypr/hyprland.lua: die AI-Extras stehen schon (teilweise) drin")
    if os.path.exists(os.path.join(C, "quickshell/corners")):
        problems.append("quickshell/corners: den Ordner gibt es schon")
    return problems, new


def cmd_check():
    problems, _ = plan_on()
    if problems:
        print("Die AI-Extras können deine Configs nicht umstellen, NICHTS geändert:")
        print("\n".join("  " + p for p in problems))
        return 1
    return 0


def cmd_on():
    problems, new = plan_on()
    if problems:
        return cmd_check()
    for path, text in new.items():
        shutil.copy2(path, path + SUFFIX)
        write(path, text)
        print("umgestellt:", os.path.relpath(path, HOME))
    qs = os.path.join(C, QS_FONT)
    if os.path.exists(qs):
        os.rename(qs, qs + SUFFIX)
    return 0


def cmd_hypr(on):
    text = read(HYPR)
    if on:
        if HYPR_BLOCK in text:
            return 0
        if not os.path.exists(os.path.join(C, "hypr/theme.lua")):
            print("hyprland.lua: theme.lua fehlt, keine require-Zeile eingefügt")
            return 1
        write(HYPR, (text if text.endswith("\n") else text + "\n") + HYPR_BLOCK)
    else:
        if HYPR_BLOCK not in text:
            if 'require("theme")' in text or "quickshell/corners" in text:
                print("hyprland.lua: der AI-EXTRAS-Block steht drin, aber anders als erwartet. Bitte selbst entfernen.")
                return 1
            return 0
        write(HYPR, text.replace(HYPR_BLOCK, "", 1))
    return 0


def cmd_off():
    """Every <file>.bak-rice-control goes back over its file; theme files go away."""
    for backup in sorted(glob.glob(os.path.join(C, "**", "*" + SUFFIX), recursive=True)):
        path = backup[:-len(SUFFIX)]
        rel = os.path.relpath(path, HOME)
        if path == HYPR:
            os.unlink(backup)              # only the LOOK block was added (hypr-off removes it)
        elif path.endswith("Noctis/settings.json"):
            os.unlink(backup)              # app data: disable.sh puts only the opacity back
        else:
            os.replace(backup, path)
            print("zurück:", rel)
    for rel in GENERATED:
        path = os.path.join(C, rel)
        if os.path.exists(path):
            os.unlink(path)
    for rel in CREATED_DIRS:
        path = os.path.join(C, rel)
        if os.path.isdir(path) and not os.listdir(path):
            os.rmdir(path)
    return 0


if __name__ == "__main__":
    command = sys.argv[2]
    sys.exit({
        "check": cmd_check,
        "on": cmd_on,
        "hypr-on": lambda: cmd_hypr(True),
        "hypr-off": lambda: cmd_hypr(False),
        "off": cmd_off,
    }[command]())
