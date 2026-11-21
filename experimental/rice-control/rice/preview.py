"""Live preview: a piece of the desktop at real size, drawn on the current wallpaper.

Everything is painted by hand with Gtk.Snapshot, so it reacts to every slider
move without touching a single config file. 1 px here is 1 px on the screen.
Hyprland's blur is approximated with a gaussian blur.
"""

import configparser
import json
import os
import subprocess
import time

from gi.repository import Gdk, Graphene, Gsk, Gtk, Pango

from .theme import mix

BAR_HEIGHT = 30
WAYPAPER_CONFIG = os.path.expanduser("~/.config/waypaper/config.ini")

LAUNCHER_APPS = (
    ("Firefox", "firefox"),
    ("Files", "org.gnome.Nautilus"),
    ("kitty", "kitty"),
    ("Steam", "steam"),
    ("OBS Studio", "com.obsproject.Studio"),
    ("Bluetooth Manager", "blueman"),
)


# ---- small drawing helpers ----------------------------------------------

# Graphene/Gsk structs: create first, then init. "Graphene.Rect().init(...)"
# would return a view of a struct Python frees right away.

def _rect(x, y, w, h):
    r = Graphene.Rect()
    r.init(x, y, max(0, w), max(0, h))
    return r


def _rrect(x, y, w, h, radius):
    radius = max(0, min(radius, w / 2, h / 2))
    rr = Gsk.RoundedRect()
    rr.init_from_rect(_rect(x, y, w, h), radius)
    return rr


def _point(x, y):
    p = Graphene.Point()
    p.init(x, y)
    return p


def _color(hex_color, alpha=1.0):
    c = Gdk.RGBA()
    c.parse(hex_color)
    c.alpha = alpha
    return c


def _font(family, pt=None, px=None, weight=Pango.Weight.NORMAL):
    desc = Pango.FontDescription()
    desc.set_family(family)
    if px is not None:
        desc.set_absolute_size(px * Pango.SCALE)
    else:
        desc.set_size(int(pt * Pango.SCALE))
    desc.set_weight(weight)
    return desc


def _wallpaper_path():
    parser = configparser.ConfigParser(interpolation=None)
    try:
        parser.read(WAYPAPER_CONFIG, encoding="utf-8")
        path = parser.get("Settings", "wallpaper", fallback="")
    except (OSError, configparser.Error):
        return None
    path = os.path.expanduser(path.strip())
    return path if path and os.path.isfile(path) else None


def monitor_info():
    """(logical width, logical height, scale) of the focused monitor."""
    try:
        out = subprocess.run(["hyprctl", "-j", "monitors"], capture_output=True,
                             text=True, timeout=2).stdout
        monitors = json.loads(out)
        m = next((m for m in monitors if m.get("focused")), monitors[0])
        scale = float(m.get("scale", 1)) or 1.0
        return m["width"] / scale, m["height"] / scale, scale
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, IndexError, StopIteration):
        return 2560.0, 1440.0, 1.0


class Preview(Gtk.Widget):
    __gtype_name__ = "RicePreview"

    def __init__(self, theme):
        super().__init__()
        self.theme = theme
        self.scene = "windows"
        self.set_hexpand(True)
        self.set_vexpand(True)
        self.set_overflow(Gtk.Overflow.HIDDEN)
        self.monitor_w, self.monitor_h, self.scale = monitor_info()
        self.wallpaper = None
        path = _wallpaper_path()
        if path:
            try:
                self.wallpaper = Gdk.Texture.new_from_filename(path)
            except Exception:  # unreadable image: fall back to a plain color
                self.wallpaper = None
        self._icons = {}

    def set_theme(self, theme):
        self.theme = theme
        self.queue_draw()

    def set_scene(self, scene):
        self.scene = scene
        self.queue_draw()

    # ---- text ----

    def _layout(self, text, desc):
        layout = self.create_pango_layout(text)
        layout.set_font_description(desc)
        return layout

    def _text(self, s, x, y, text, desc, color):
        layout = self._layout(text, desc)
        s.save()
        s.translate(_point(round(x), round(y)))
        s.append_layout(layout, color)
        s.restore()
        return layout.get_pixel_size()

    def _text_size(self, text, desc):
        return self._layout(text, desc).get_pixel_size()

    # ---- building blocks ----

    def _wallpaper_rect(self):
        """Where the wallpaper sits: cover-fit to the monitor, the preview shows the middle-top part."""
        w, h = self.get_width(), self.get_height()
        mw, mh = max(self.monitor_w, w), max(self.monitor_h, h)
        tw, th = self.wallpaper.get_width(), self.wallpaper.get_height()
        scale = max(mw / tw, mh / th)
        dw, dh = tw * scale, th * scale
        left = (mw - w) / 2
        return _rect((mw - dw) / 2 - left, (mh - dh) / 2, dw, dh)

    def _backdrop(self, s, blur):
        if self.wallpaper is None:
            s.append_color(_color("#3a3a3a"), _rect(0, 0, self.get_width(), self.get_height()))
            return
        if blur > 0:
            s.push_blur(blur)
        s.append_texture(self.wallpaper, self._wallpaper_rect())
        if blur > 0:
            s.pop()

    def _glass(self, s, x, y, w, h, radius, color=None):
        """A see-through surface: blurred wallpaper + background color, like Hyprland draws it."""
        t = self.theme
        clip = _rrect(x, y, w, h, radius)
        s.push_rounded_clip(clip)
        self._backdrop(s, t.blur_preview_radius)
        s.append_color(color or _color(t.background, t.opacity), _rect(x, y, w, h))
        s.pop()

    def _solid(self, s, x, y, w, h, radius, color):
        s.push_rounded_clip(_rrect(x, y, w, h, radius))
        s.append_color(color, _rect(x, y, w, h))
        s.pop()

    def _border(self, s, x, y, w, h, radius, width, color):
        if width <= 0:
            return
        s.append_border(_rrect(x, y, w, h, radius), [width] * 4, [color] * 4)

    def _window(self, s, x, y, w, h, active):
        """A Hyprland window: border outside the rounded content, like Hyprland draws it."""
        t = self.theme
        bw = t.border_width
        outer_radius = t.rounding + bw if t.rounding else 0
        self._glass(s, x + bw, y + bw, w - 2 * bw, h - 2 * bw, t.rounding)
        self._border(s, x, y, w, h, outer_radius, bw,
                     _color(t.border_active if active else t.border_inactive))
        return x + bw, y + bw, w - 2 * bw, h - 2 * bw

    def _icon(self, name, size):
        key = (name, size)
        if key not in self._icons:
            theme = Gtk.IconTheme.get_for_display(self.get_display())
            self._icons[key] = theme.lookup_icon(name, ["application-x-executable"], size,
                                                 self.get_scale_factor(), Gtk.TextDirection.NONE, 0)
        return self._icons[key]

    # ---- scene ----

    def do_snapshot(self, s):
        t = self.theme
        w, h = self.get_width(), self.get_height()
        if w <= 0 or h <= 0:
            return
        self._backdrop(s, 0)

        fg = _color(t.foreground)
        dim = _color(mix(t.foreground, t.background, 0.5))

        # two tiled windows under the bar
        top = BAR_HEIGHT + t.gaps_out
        area_w = w - 2 * t.gaps_out
        area_h = h - top - t.gaps_out
        left_w = round((area_w - 2 * t.gaps_in) * 0.55)
        right_x = t.gaps_out + left_w + 2 * t.gaps_in
        right_w = area_w - left_w - 2 * t.gaps_in
        if area_h > 40 and left_w > 40 and right_w > 40:
            self._terminal(s, t.gaps_out, top, left_w, area_h, fg, dim)
            self._files(s, right_x, top, right_w, area_h, fg, dim)

        self._bar(s, w, fg, dim)

        if self.scene == "launcher":
            self._launcher(s, w, h, fg, dim)
        else:
            self._notification(s, w, fg, dim)
            if area_h > 260 and right_w > 260:
                self._menu(s, right_x + right_w - 250, top + area_h - 170, fg)

    def _bar(self, s, w, fg, dim):
        t = self.theme
        self._glass(s, 0, 0, w, BAR_HEIGHT, 0)
        bar = _font(t.font, px=t.bar_font_px, weight=Pango.Weight.SEMIBOLD)
        cat = _font("JetBrainsMono Nerd Font", px=t.bar_font_px, weight=Pango.Weight.SEMIBOLD)

        def centered_y(desc, text="X"):
            return (BAR_HEIGHT - self._text_size(text, desc)[1]) / 2

        x = 8
        tw, _ = self._text(s, x, centered_y(cat), "(=^.^=)", cat, fg)
        x += tw + 12
        for label, color in (("●", fg), ("○", fg), ("○", dim)):
            tw, _ = self._text(s, x, centered_y(bar, label), label, bar, color)
            x += tw + 24
        self._text(s, x + 8, centered_y(bar), "kitty", bar, fg)

        clock = time.strftime("%a %d.%m.  %H:%M")
        cw, _ = self._text_size(clock, bar)
        clock_x = (w - cw) / 2
        self._text(s, clock_x, centered_y(bar), clock, bar, fg)

        right = " 5%     63%     80%"
        rw, _ = self._text_size(right, bar)
        self._text(s, w - rw - 8, centered_y(bar), right, bar, fg)

        if self.scene == "windows":
            self._tooltip(s, clock_x + cw / 2, BAR_HEIGHT + 6, "meow", bar, fg)

    def _tooltip(self, s, center_x, y, text, desc, fg):
        t = self.theme
        tw, th = self._text_size(text, desc)
        pad_x, pad_y = 10, 6
        w, h = tw + 2 * pad_x, th + 2 * pad_y
        x = center_x - w / 2
        self._glass(s, x, y, w, h, t.rounding)
        self._border(s, x, y, w, h, t.rounding, t.border_width, _color(t.border_active))
        self._text(s, x + pad_x, y + pad_y, text, desc, fg)

    def _terminal(self, s, x, y, w, h, fg, dim):
        t = self.theme
        cx, cy, cw, ch = self._window(s, x, y, w, h, active=True)
        mono = _font(t.mono_font, pt=t.mono_size)
        mono_bold = _font(t.mono_font, pt=t.mono_size, weight=Pango.Weight.BOLD)
        line_h = self._text_size("X", mono)[1]
        logo = ("      /\\      ", "     /  \\     ", "    /    \\    ", "   /      \\   ",
                "  /   ,,   \\  ", " /   |  |   \\ ", "/_-''    ''-_\\")
        info = (("User", "viggo"), ("OS", "Arch (btw)"), ("WM", "Hyprland"), ("Shell", "bash"),
                ("Font", t.font), ("Mono", t.mono_font), ("Look", f"{round(t.opacity * 100)} % · {t.rounding} px"))
        s.push_rounded_clip(_rrect(cx, cy, cw, ch, t.rounding))
        px, py = cx + 10, cy + 8
        self._text(s, px, py, "[viggo@archlinux ~]$ fastfetch", mono, fg)
        py += line_h * 1.5
        logo_w = self._text_size(logo[0], mono)[0]
        for art, (key, value) in zip(logo, info):
            self._text(s, px, py, art, mono, fg)
            kw, _ = self._text(s, px + logo_w + 12, py, key + ":", mono_bold, dim)
            self._text(s, px + logo_w + 12 + kw + 8, py, value, mono, fg)
            py += line_h
        py += line_h * 0.5
        pw, _ = self._text(s, px, py, "[viggo@archlinux ~]$ ", mono, fg)
        s.append_color(fg, _rect(px + pw, py + 1, max(2, line_h * 0.5), line_h - 2))
        s.pop()

    def _files(self, s, x, y, w, h, fg, dim):
        t = self.theme
        cx, cy, cw, ch = self._window(s, x, y, w, h, active=False)
        ui = _font(t.font, pt=t.font_size)
        ui_bold = _font(t.font, pt=t.font_size + 1, weight=Pango.Weight.SEMIBOLD)
        s.push_rounded_clip(_rrect(cx, cy, cw, ch, t.rounding))
        self._text(s, cx + 16, cy + 14, "Home", ui_bold, fg)
        row_h = round(self._text_size("X", ui)[1] * 2.1)
        ry = cy + 52
        rows = (("Downloads", "23 items"), ("Music", "112 items"), ("Wallpapers", "41 items"),
                (".config", "31 items"), ("Arch-Linux-Vault", "18 items"), ("AppImages", "8 items"))
        for i, (name, size) in enumerate(rows):
            if ry + row_h > cy + ch:
                break
            if i == 1:  # a selected row shows the selection color
                self._solid(s, cx + 8, ry, cw - 16, row_h, t.inner_radius, _color(t.foreground, 0.25))
            text_y = ry + (row_h - self._text_size(name, ui)[1]) / 2
            self._text(s, cx + 18, text_y, name, ui, fg)
            sw, _ = self._text_size(size, ui)
            self._text(s, cx + cw - sw - 18, text_y, size, ui, dim)
            ry += row_h
        s.pop()

    def _menu(self, s, x, y, fg):
        """A GTK right-click menu: solid background, 4 px padding, rounded items."""
        t = self.theme
        ui = _font(t.font, pt=t.font_size)
        items = ("Open", "Rename…", "Move to Trash")
        item_h = self._text_size("X", ui)[1] + 8
        w, h = 230, len(items) * item_h + 8
        bg = _color(t.background)
        self._solid(s, x, y, w, h, t.rounding, bg)
        self._border(s, x, y, w, h, t.rounding, t.border_width, _color(t.border_active))
        iy = y + 4
        for i, label in enumerate(items):
            color = fg
            if i == 1:  # hovered
                self._solid(s, x + 4, iy, w - 8, item_h, t.inner_radius, fg)
                color = bg
            self._text(s, x + 12, iy + 4, label, ui, color)
            iy += item_h

    def _notification(self, s, w, fg, dim):
        """A swaync notification in the top right corner."""
        t = self.theme
        summary = _font(t.font, px=16, weight=Pango.Weight.BOLD)
        body = _font(t.font, px=15)
        nw = min(380, w - 40)
        sh = self._text_size("X", summary)[1]
        bh = self._text_size("X", body)[1]
        nh = 12 + sh + 4 + bh + 12
        x, y = w - nw - 12, BAR_HEIGHT + 6
        self._glass(s, x, y, nw, nh, t.rounding)
        self._border(s, x, y, nw, nh, t.rounding, t.border_width, _color(t.border_active))
        self._text(s, x + 14, y + 12, "Rice Control", summary, fg)
        self._text(s, x + 14, y + 12 + sh + 4, "Vorschau: so sehen Benachrichtigungen aus", body, dim)

    def _launcher(self, s, w, h, fg, dim):
        """rofi: 600 px wide, 12 px padding, selected entry inverted."""
        t = self.theme
        font = _font(t.font, pt=t.launcher_font_size)
        line_h = self._text_size("X", font)[1]
        entry_h = line_h + 8
        rows = LAUNCHER_APPS
        lw = min(600, w - 40)
        lh = 12 + line_h + 10 + len(rows) * entry_h + (len(rows) - 1) * 4 + 12
        x = (w - lw) / 2
        y = max(BAR_HEIGHT + 20, (h - lh) * 0.35)
        self._glass(s, x, y, lw, lh, t.rounding)
        self._border(s, x, y, lw, lh, t.rounding, t.border_width, _color(t.border_active))

        inner_x = x + t.border_width + 12
        inner_w = lw - 2 * (t.border_width + 12)
        ey = y + t.border_width + 12
        self._text(s, inner_x, ey, "search", font, _color("#737373"))
        ey += line_h + 10
        for i, (name, icon) in enumerate(rows):
            color = fg
            if i == 0:
                self._solid(s, inner_x, ey, inner_w, entry_h, t.inner_radius, fg)
                color = _color(t.background)
            paintable = self._icon(icon, 20)
            if paintable is not None:
                s.save()
                s.translate(_point(inner_x + 8, ey + (entry_h - 20) / 2))
                paintable.snapshot(s, 20, 20)
                s.restore()
            self._text(s, inner_x + 8 + 20 + 10, ey + 4, name, font, color)
            ey += entry_h + 4
