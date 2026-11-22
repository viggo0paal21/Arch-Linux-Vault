"""The look of the rice as data.

All values live in ~/.config/rice-control/theme.json. Every program's theme file is
generated from them (see targets.py), so this is the one place that counts.
"""

import json
import os
import re
import tempfile
import time
from dataclasses import asdict, dataclass, fields, replace

RICE_DIR = os.path.expanduser("~/.config/rice-control")
THEME_FILE = os.path.join(RICE_DIR, "theme.json")
HISTORY_DIR = os.path.join(RICE_DIR, "history")
HISTORY_KEEP = 30

_HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
# font names end up in CSS, Lua, XML and ini files: keep them plain
_BAD_FONT_CHARS = re.compile(r'["\\<>&;{}\n\r\t]')


@dataclass(frozen=True)
class Theme:
    border_width: int = 1
    border_active: str = "#ffffff"
    border_inactive: str = "#444444"
    rounding: int = 10
    background: str = "#000000"
    foreground: str = "#ffffff"
    opacity: float = 0.8
    blur: bool = True
    blur_size: int = 2
    blur_passes: int = 2
    gaps_in: int = 5
    gaps_out: int = 10
    font: str = "Noto Sans"
    font_size: int = 10
    mono_font: str = "monospace"
    mono_size: int = 11

    # ---- derived values -------------------------------------------------

    @property
    def inner_radius(self):
        """Radius for things inside a rounded box (menu items, buttons).

        Menus have 4 px padding, so outer radius minus 4 keeps the corners
        parallel instead of the inner ones looking too round.
        """
        return max(0, self.rounding - 4)

    @property
    def glass(self):
        """Background color with the window opacity, as CSS."""
        return css_rgba(self.background, self.opacity)

    @property
    def bar_font_px(self):
        """Waybar has always used px: 10 pt -> 13 px."""
        return round(self.font_size * 4 / 3)

    @property
    def launcher_font_size(self):
        """rofi and Qt read a little bigger than GTK at the same number."""
        return self.font_size + 2

    @property
    def blur_preview_radius(self):
        """Rough gaussian equivalent of Hyprland's blur (size, passes)."""
        if not self.blur:
            return 0
        return min(120, self.blur_size * (2 ** self.blur_passes) * 0.8)


LIMITS = {
    "border_width": (0, 8),
    "rounding": (0, 30),
    "opacity": (0.3, 1.0),
    "blur_size": (1, 20),
    "blur_passes": (1, 8),
    "gaps_in": (0, 30),
    "gaps_out": (0, 60),
    "font_size": (6, 24),
    "mono_size": (6, 30),
}

COLOR_KEYS = ("border_active", "border_inactive", "background", "foreground")
FONT_KEYS = ("font", "mono_font")


# ---- colors -------------------------------------------------------------

def rgb(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def css_rgba(hex_color, alpha):
    r, g, b = rgb(hex_color)
    return f"rgba({r}, {g}, {b}, {fmt_num(alpha)})"


def alpha_byte(alpha):
    """0.8 -> 'cc' (rofi, Hyprland and hyprtoolkit write alpha as hex)."""
    return f"{round(alpha * 255):02x}"


def mix(hex_a, hex_b, amount):
    """amount 0 = a, 1 = b."""
    a, b = rgb(hex_a), rgb(hex_b)
    return "#" + "".join(f"{round(x + (y - x) * amount):02x}" for x, y in zip(a, b))


def fmt_num(value):
    """0.8 -> '0.8', 1.0 -> '1'."""
    return f"{value:.2f}".rstrip("0").rstrip(".")


# ---- validation ---------------------------------------------------------

def clean(theme):
    """Clamp numbers, fix broken colors and fonts. Always returns a valid Theme."""
    default = Theme()
    values = {}
    for f in fields(Theme):
        value = getattr(theme, f.name)
        fallback = getattr(default, f.name)
        if f.name in COLOR_KEYS:
            value = value.lower() if isinstance(value, str) and _HEX.match(value) else fallback
        elif f.name in FONT_KEYS:
            value = value.strip() if isinstance(value, str) else ""
            if not value or _BAD_FONT_CHARS.search(value):
                value = fallback
        elif f.type in (bool, "bool"):
            value = bool(value)
        else:
            try:
                value = float(value)
            except (TypeError, ValueError):
                value = fallback
            lo, hi = LIMITS[f.name]
            value = min(hi, max(lo, value))
            value = round(value, 2) if f.name == "opacity" else int(round(value))
        values[f.name] = value
    return Theme(**values)


def from_dict(data):
    known = {f.name for f in fields(Theme)}
    return clean(replace(Theme(), **{k: v for k, v in data.items() if k in known}))


def differences(a, b):
    """Names of the values that differ between two themes."""
    da, db = asdict(a), asdict(b)
    return [k for k in da if da[k] != db[k]]


# ---- files --------------------------------------------------------------

def write_atomic(path, text, mode=None):
    """Write via a temp file in the same folder, so a crash never leaves half a file."""
    folder = os.path.dirname(path)
    os.makedirs(folder, exist_ok=True)
    if mode is None:
        mode = os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o644
    fd, tmp = tempfile.mkstemp(dir=folder, prefix=".rice-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def load():
    """The saved theme, or the defaults if there is none yet."""
    try:
        with open(THEME_FILE, encoding="utf-8") as f:
            return from_dict(json.load(f))
    except FileNotFoundError:
        return Theme()
    except (OSError, ValueError):
        # broken file: start from the defaults instead of crashing
        return Theme()


def exists():
    return os.path.exists(THEME_FILE)


def save(theme):
    write_atomic(THEME_FILE, json.dumps(asdict(theme), indent=4) + "\n")


# ---- history (undo) -----------------------------------------------------

def _history_files():
    try:
        names = sorted(n for n in os.listdir(HISTORY_DIR) if n.endswith(".json"))
    except FileNotFoundError:
        return []
    return [os.path.join(HISTORY_DIR, n) for n in names]


def push_history(theme):
    stamp = time.strftime("%Y%m%d-%H%M%S") + f"-{time.time_ns() % 1_000_000:06d}"
    write_atomic(os.path.join(HISTORY_DIR, stamp + ".json"),
                 json.dumps(asdict(theme), indent=4) + "\n")
    for old in _history_files()[:-HISTORY_KEEP]:
        os.unlink(old)


def has_history():
    return bool(_history_files())


def pop_history():
    """The theme before the last apply, removed from the history. None if empty."""
    files = _history_files()
    if not files:
        return None
    path = files[-1]
    try:
        with open(path, encoding="utf-8") as f:
            theme = from_dict(json.load(f))
    except (OSError, ValueError):
        theme = None
    os.unlink(path)
    return theme if theme is not None else pop_history()
