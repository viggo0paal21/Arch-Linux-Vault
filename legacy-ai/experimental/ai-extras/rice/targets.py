"""Turns a Theme into config files for every program and reloads them.

Two kinds of targets:
  * generated: a whole file that only this app writes (theme.css, theme.lua ...).
    The program's own config imports it once.
  * edited: programs that can't import files (hyprtoolkit, Kvantum, qt6ct ...).
    Only the lines for our values get replaced, everything else stays.

apply() first builds every new file in memory. Only if that works for all of
them, anything gets written, so a bug can't leave the rice half changed.
"""

import json
import os
import re
import shutil
import subprocess
import time
from dataclasses import dataclass, field
from xml.sax.saxutils import escape as xml_escape

from .theme import alpha_byte, css_rgba, fmt_num, write_atomic

CONFIG = os.path.expanduser("~/.config")
BACKUP_SUFFIX = ".bak-rice-control"

HEADER = "Written by Rice Control (click the cat in Waybar). Changes here get overwritten:\n" \
         "change the values in the app or in ~/.config/rice-control/theme.json."


def _comment(prefix, text, suffix=""):
    lines = text.split("\n")
    if prefix in ("/*",):
        return "/* " + "\n   ".join(lines) + " */"
    return "\n".join(f"{prefix} {line}" for line in lines)


def _border(theme, color):
    if theme.border_width == 0:
        return "none"
    return f"{theme.border_width}px solid {color}"


# ---- generated files ----------------------------------------------------

def hypr_theme(t):
    def hypr_color(hex_color):
        return f"rgba({hex_color[1:]}ff)"

    return f"""{_comment("--", HEADER)}
-- hyprland.lua loads this at its very end, so these values win.

hl.config({{
    general = {{
        border_size = {t.border_width},
        gaps_in     = {t.gaps_in},
        gaps_out    = {t.gaps_out},
        col = {{
            active_border   = "{hypr_color(t.border_active)}",
            inactive_border = "{hypr_color(t.border_inactive)}",
        }},
    }},
    decoration = {{
        rounding = {t.rounding},
        blur = {{
            enabled = {"true" if t.blur else "false"},
            size    = {t.blur_size},
            passes  = {t.blur_passes},
        }},
    }},
}})

-- Rice Control itself floats in the middle of the screen
hl.window_rule({{ match = {{ class = "^(de\\\\.viggo\\\\.RiceControl)$" }}, float = true, size = {{ 1320, 900 }}, center = true }})
"""


def waybar_theme(t):
    return f"""{_comment("/*", HEADER)}
/* style.css imports this file first and can use the colors below. */

@define-color rice_bg {t.background};
@define-color rice_fg {t.foreground};
@define-color rice_glass {t.glass};
@define-color rice_border {t.border_active};

* {{
    font-family: "{t.font}", "JetBrains Mono Nerd Font Propo";
    font-size: {t.bar_font_px}px;
}}

window#waybar {{
    background-color: @rice_glass;
    color: @rice_fg;
}}

/* tooltips (e.g. "meow") */
tooltip,
tooltip.background {{
    background-color: @rice_glass;
    border: {_border(t, "@rice_border")};
    border-radius: {t.rounding}px;
    box-shadow: none;
}}

tooltip decoration {{
    background-color: transparent;
    border: none;
    box-shadow: none;
}}

tooltip label {{
    color: @rice_fg;
}}

/* tray right-click menus */
menu {{
    background-color: @rice_glass;
    border: {_border(t, "@rice_border")};
    border-radius: {t.rounding}px;
}}

menuitem {{
    border-radius: {t.inner_radius}px;
}}

menuitem:hover {{
    background-color: @rice_fg;
    color: @rice_bg;
}}

window.popup,
.csd.popup decoration {{
    border-radius: {t.rounding}px;
}}
"""


def gtk3_theme(t):
    return f"""{_comment("/*", HEADER)}
/* gtk.css imports this file first. Applies to all GTK 3 apps. */

@define-color theme_bg_color          {t.background};
@define-color theme_fg_color          {t.foreground};
@define-color theme_base_color        {t.background};
@define-color theme_text_color        {t.foreground};
@define-color theme_selected_bg_color {t.foreground};
@define-color theme_selected_fg_color {t.background};

@define-color theme_unfocused_bg_color          {t.background};
@define-color theme_unfocused_fg_color          {t.foreground};
@define-color theme_unfocused_base_color        {t.background};
@define-color theme_unfocused_text_color        {t.foreground};
@define-color theme_unfocused_selected_bg_color {t.foreground};
@define-color theme_unfocused_selected_fg_color {t.background};

@define-color rice_glass  {t.glass};
@define-color rice_border {t.border_active};

/* glass: only the window gets the color, everything inside stays clear */
window.background {{
    background-color: @rice_glass;
}}

.view:selected,
treeview:selected {{
    background-color: alpha(@theme_fg_color, 0.25);
    color: @theme_fg_color;
}}

menubar > menuitem {{
    color: @theme_fg_color;
}}

button,
entry {{
    border-radius: {t.inner_radius}px;
}}

/* right-click menus */
menu,
.context-menu {{
    background-color: @theme_bg_color;
    border: {_border(t, "@rice_border")};
    border-radius: {t.rounding}px;
}}

menuitem {{
    border-radius: {t.inner_radius}px;
}}

menuitem:hover {{
    background-color: @theme_fg_color;
    color: @theme_bg_color;
}}

window.popup,
.csd.popup decoration {{
    border-radius: {t.rounding}px;
}}

/* tooltips */
tooltip,
tooltip.background {{
    background-color: @theme_bg_color;
    border: {_border(t, "@rice_border")};
    border-radius: {t.rounding}px;
    box-shadow: none;
}}

tooltip decoration {{
    background-color: transparent;
    border: none;
    box-shadow: none;
}}

tooltip label {{
    color: @theme_fg_color;
}}
"""


def gtk4_theme(t):
    return f"""{_comment("/*", HEADER)}
/* gtk.css imports this file first. Applies to all GTK 4 / libadwaita apps. */

:root {{
    --window-bg-color: {t.glass};
    --window-fg-color: {t.foreground};
    --view-bg-color: {t.glass};
    --view-fg-color: {t.foreground};
    --headerbar-fg-color: {t.foreground};
    --sidebar-fg-color: {t.foreground};

    --card-bg-color: {t.background};
    --popover-bg-color: {t.background};

    --accent-bg-color: {t.foreground};
    --accent-fg-color: {t.background};
    --accent-color: {t.foreground};

    --window-radius: {t.rounding}px;
}}

/* menus and popovers */
popover > contents {{
    border: {_border(t, t.border_active)};
    border-radius: {t.rounding}px;
    box-shadow: none;
}}

/* tooltips */
tooltip,
tooltip.background {{
    background-color: {t.background};
    color: {t.foreground};
    border: {_border(t, t.border_active)};
    border-radius: {t.rounding}px;
    box-shadow: none;
}}
"""


def swaync_theme(t):
    r, g, b = (int(t.background[i:i + 2], 16) for i in (1, 3, 5))
    return f"""{_comment("/*", HEADER)}
/* style.css imports the default swaync style first, then this file. */

:root {{
    --noti-bg: {r}, {g}, {b};
    --noti-bg-alpha: {fmt_num(t.opacity)};
    --noti-bg-darker: {t.glass};
    --noti-bg-hover: {css_rgba(t.foreground, 0.1)};
    --cc-bg: {t.glass};
    --text-color: {t.foreground};

    --noti-border-color: {t.border_active};
    --border: {_border(t, "var(--noti-border-color)")};
    --border-radius: {t.rounding}px;
    --notification-shadow: none;
}}

.control-center {{
    border: var(--border);
}}
"""


def rofi_theme(t):
    return f"""{_comment("//", HEADER)}
// config.rasi imports this file and can use the colors below.

* {{
    bg:       {t.background};
    bg-glass: {t.background}{alpha_byte(t.opacity)};
    fg:       {t.foreground};
    accent:   {t.foreground};
    font:     "{t.font} {t.launcher_font_size}";
}}

window {{
    background-color: @bg-glass;
    border:           {t.border_width}px;
    border-color:     {t.border_active};
    border-radius:    {t.rounding}px;
}}

element selected {{
    background-color: @fg;
    text-color:       @bg;
    border-radius:    {t.inner_radius}px;
}}
"""


def kitty_theme(t):
    return f"""{_comment("#", HEADER)}
# kitty.conf includes this file.

background_opacity {fmt_num(t.opacity)}
background         {t.background}
foreground         {t.foreground}
font_family        {t.mono_font}
font_size          {t.mono_size}.0
"""


def fontconfig_theme(t):
    def alias(generic, family):
        return (f"  <alias binding=\"strong\">\n"
                f"    <family>{generic}</family>\n"
                f"    <prefer><family>{xml_escape(family)}</family></prefer>\n"
                f"  </alias>")

    aliases = [alias("sans-serif", t.font), alias("system-ui", t.font)]
    if t.mono_font.lower() != "monospace":
        aliases.append(alias("monospace", t.mono_font))
    comment = HEADER.replace("\n", "\n     ")
    return f"""<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- {comment}
     Apps that ask for the generic fonts (sans-serif, system-ui, monospace) get yours.
     Fonts an app asks for by name stay. -->
<fontconfig>
{chr(10).join(aliases)}
</fontconfig>
"""


# ---- edited files -------------------------------------------------------

def set_key(text, key, value, sep=" = "):
    """Replace 'key = old' (any spacing) with 'key = value', or append it."""
    pattern = re.compile(rf"^([ \t]*{re.escape(key)}[ \t]*=[ \t]*).*$", re.M)
    if pattern.search(text):
        return pattern.sub(lambda m: m.group(1) + value, text, count=1)
    return text.rstrip("\n") + f"\n{key}{sep}{value}\n"


def set_ini(text, section, key, value):
    """Set key=value inside [section], keeping every other line as it is."""
    lines = text.split("\n")
    start = None
    for i, line in enumerate(lines):
        if line.strip() == f"[{section}]":
            start = i
            break
    if start is None:
        return text.rstrip("\n") + f"\n\n[{section}]\n{key}={value}\n"
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].startswith("["):
            end = i
            break
    for i in range(start + 1, end):
        if lines[i].split("=", 1)[0].strip() == key:
            lines[i] = f"{key}={value}"
            return "\n".join(lines)
    insert = end
    while insert > start + 1 and not lines[insert - 1].strip():
        insert -= 1
    lines.insert(insert, f"{key}={value}")
    return "\n".join(lines)


def get_ini(text, section, key):
    current = None
    for line in text.split("\n"):
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            current = s[1:-1]
        elif current == section and "=" in s and s.split("=", 1)[0].strip() == key:
            return s.split("=", 1)[1].strip()
    return None


def edit_gtk_settings(t, text):
    return set_ini(text, "Settings", "gtk-font-name", f"{t.font} {t.font_size}")


def edit_hyprtoolkit(t, text):
    def argb(hex_color, alpha=1.0):
        return f"0x{alpha_byte(alpha)}{hex_color[1:]}".upper().replace("0X", "0x")

    for key, value in (
        ("background", argb(t.background, t.opacity)),
        ("base", argb(t.background)),
        ("text", argb(t.foreground)),
        ("font_family", t.font),
        ("font_family_monospace", t.mono_font),
        ("font_size", str(t.font_size + 1)),
        ("small_font_size", str(t.font_size)),
        ("h1_size", str(t.font_size + 3)),
        ("h2_size", str(t.font_size + 2)),
        ("h3_size", str(t.font_size + 1)),
        ("rounding_large", str(t.rounding)),
        ("rounding_small", str(t.rounding)),
    ):
        text = set_key(text, key, value)
    return text


def edit_kvantum(t, text):
    text = set_ini(text, "%General", "reduce_window_opacity", str(round((1 - t.opacity) * 100)))
    for key in ("window.color", "base.color", "alt.base.color", "button.color"):
        text = set_ini(text, "GeneralColors", key, t.background)
    for key in ("text.color", "window.text.color", "button.text.color", "tooltip.text.color",
                "highlight.text.color", "progress.indicator.text.color"):
        text = set_ini(text, "GeneralColors", key, t.foreground)
    return text


QT_FONT_TAIL = "-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"


def _qt_font(old, family, size):
    """qt6ct stores fonts as "Family,size,..."; keep everything after the size."""
    tail = QT_FONT_TAIL
    if old and old.startswith('"') and old.endswith('"'):
        parts = old[1:-1].split(",")
        if len(parts) > 2:
            tail = ",".join(parts[2:])
    return f'"{family},{size},{tail}"'


def edit_qt6ct(t, text):
    text = set_ini(text, "Fonts", "general",
                   _qt_font(get_ini(text, "Fonts", "general"), t.font, t.launcher_font_size))
    text = set_ini(text, "Fonts", "fixed",
                   _qt_font(get_ini(text, "Fonts", "fixed"), t.mono_font, t.mono_size + 1))
    return text


def edit_noctis(t, text):
    new = re.sub(r'("miniPlayerBackgroundOpacity"\s*:\s*)-?[0-9.eE+-]+',
                 lambda m: m.group(1) + fmt_num(t.opacity), text, count=1)
    json.loads(new)  # never write broken JSON
    return new


def _kvantum_theme_file():
    """The active Kvantum theme, but only if it is a user theme in ~/.config/Kvantum."""
    try:
        with open(os.path.join(CONFIG, "Kvantum", "kvantum.kvconfig"), encoding="utf-8") as f:
            name = get_ini(f.read(), "General", "theme")
    except OSError:
        return None
    if not name or "/" in name:
        return None
    path = os.path.join(CONFIG, "Kvantum", name, name + ".kvconfig")
    return path if os.path.exists(path) else None


# ---- the list of targets ------------------------------------------------

@dataclass
class Target:
    program: str
    path: str
    generate: object = None   # theme -> text
    edit: object = None       # theme, old text -> text (only if the file exists)


def targets():
    c = lambda *p: os.path.join(CONFIG, *p)
    items = [
        Target("Hyprland", c("hypr", "theme.lua"), generate=hypr_theme),
        Target("Waybar", c("waybar", "theme.css"), generate=waybar_theme),
        Target("GTK 3", c("gtk-3.0", "theme.css"), generate=gtk3_theme),
        Target("GTK 3", c("gtk-3.0", "settings.ini"), edit=edit_gtk_settings),
        Target("GTK 4", c("gtk-4.0", "theme.css"), generate=gtk4_theme),
        Target("GTK 4", c("gtk-4.0", "settings.ini"), edit=edit_gtk_settings),
        Target("swaync", c("swaync", "theme.css"), generate=swaync_theme),
        Target("rofi", c("rofi", "theme.rasi"), generate=rofi_theme),
        Target("kitty", c("kitty", "theme.conf"), generate=kitty_theme),
        Target("Schriften", c("fontconfig", "conf.d", "55-rice-fonts.conf"), generate=fontconfig_theme),
        Target("Bildschirmfreigabe", c("hypr", "hyprtoolkit.conf"), edit=edit_hyprtoolkit),
        Target("Qt", c("qt6ct", "qt6ct.conf"), edit=edit_qt6ct),
        Target("Noctis", c("Noctis", "settings.json"), edit=edit_noctis),
    ]
    kvantum = _kvantum_theme_file()
    if kvantum:
        items.append(Target("Qt", kvantum, edit=edit_kvantum))
    return items


# ---- applying -----------------------------------------------------------

@dataclass
class Report:
    changed: list = field(default_factory=list)    # programs whose files changed
    reloaded: list = field(default_factory=list)   # programs reloaded live
    errors: list = field(default_factory=list)


def _read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return None


def plan(theme):
    """[(target, old text, new text)] for every file that would change."""
    changes = []
    for target in targets():
        old = _read(target.path)
        if target.generate:
            new = target.generate(theme)
        elif old is None:
            continue  # nothing to edit: the program isn't set up
        else:
            new = target.edit(theme, old)
        if new != old:
            changes.append((target, old, new))
    return changes


def write_files(theme, report=None):
    report = report or Report()
    for target, old, new in plan(theme):
        backup = target.path + BACKUP_SUFFIX
        if old is not None and not os.path.exists(backup):
            shutil.copy2(target.path, backup)  # one backup of the original, never overwritten
        write_atomic(target.path, new)
        if target.program not in report.changed:
            report.changed.append(target.program)
    return report


def _run(args, timeout=5):
    try:
        return subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                              timeout=timeout).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def _running(name):
    return _run(["pgrep", "-x", name], timeout=2)


def set_system_fonts(theme, report):
    """GTK apps (and everything asking the desktop settings) read the fonts from gsettings."""
    interface = "org.gnome.desktop.interface"
    ok = all(_run(["gsettings", "set", interface, key, value]) for key, value in (
        ("font-name", f"{theme.font} {theme.font_size}"),
        ("document-font-name", f"{theme.font} {theme.font_size}"),
        ("monospace-font-name", f"{theme.mono_font} {theme.mono_size}"),
    ))
    if not ok:
        report.errors.append("Systemschrift (gsettings) konnte nicht gesetzt werden")
    return report


def _restart_waybar():
    """Full restart instead of SIGUSR2: the signal reload dropped style.css once (21.11.)."""
    if not _run(["pkill", "-x", "waybar"], timeout=2):
        return False
    for _ in range(50):  # wait up to 5 s until the old bar is gone
        if not _running("waybar"):
            break
        time.sleep(0.1)
    try:
        subprocess.Popen(["waybar"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    except OSError:
        return False
    return True


def reload_programs(report):
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        (report.reloaded if _run(["hyprctl", "reload"]) else report.errors).append("Hyprland")
    if _running("waybar"):
        (report.reloaded if _restart_waybar() else report.errors).append("Waybar")
    if _running("swaync"):
        (report.reloaded if _run(["swaync-client", "--reload-css"]) else report.errors).append("swaync")
    if _running("kitty"):
        (report.reloaded if _run(["pkill", "-USR1", "-x", "kitty"]) else report.errors).append("kitty")
    return report


def apply(theme, fonts=True, reload=True):
    """Write all files; then set the system fonts and reload the running programs."""
    report = write_files(theme)
    if fonts:
        set_system_fonts(theme, report)
    if reload:
        reload_programs(report)
    return report
