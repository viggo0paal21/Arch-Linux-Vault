"""The window: controls on the left, live preview on the right."""

import threading
from dataclasses import replace

from gi.repository import Gdk, Gio, GLib, Gtk, Pango

from . import targets
from . import theme as model
from .preview import Preview

APP_ID = "de.viggo.RiceControl"

# (key, label, kind, *options). Order = order in the window.
SECTIONS = (
    ("Rahmen", (
        ("border_width", "Breite", "spin", "px"),
        ("border_active", "Aktives Fenster", "color"),
        ("border_inactive", "Inaktive Fenster", "color"),
    )),
    ("Ecken", (
        ("rounding", "Rundung", "scale", "px"),
    )),
    ("Fläche", (
        ("background", "Hintergrund", "color"),
        ("foreground", "Text", "color"),
        ("opacity", "Deckkraft", "scale", "%"),
    )),
    ("Unschärfe", (
        ("blur", "Aktiv", "switch"),
        ("blur_size", "Stärke", "spin", ""),
        ("blur_passes", "Durchgänge", "spin", ""),
    )),
    ("Abstände", (
        ("gaps_in", "Innen", "spin", "px"),
        ("gaps_out", "Außen", "spin", "px"),
    )),
    ("Schrift", (
        ("font", "Oberfläche", "font"),
        ("font_size", "Größe", "spin", "pt"),
        ("mono_font", "Terminal", "font"),
        ("mono_size", "Größe", "spin", "pt"),
    )),
)

HINTS = {
    "gaps_in": "Hyprland nimmt den Wert doppelt: zwischen zwei Fenstern liegen 2 × Innen",
    "gaps_out": "Abstand der Fenster zum Bildschirmrand und zur Leiste",
    "blur_size": "Wie weit jeder Durchgang verwischt",
    "blur_passes": "Mehr Durchgänge = weicher, aber teurer für die GPU",
    "font": "Für GTK, Qt, Waybar, rofi, swaync und alle Apps, die die Systemschrift nutzen",
    "mono_font": "Für kitty und überall, wo eine Monospace-Schrift gebraucht wird",
}


def _hex(rgba):
    return "#" + "".join(f"{round(c * 255):02x}" for c in (rgba.red, rgba.green, rgba.blue))


def _rgba(hex_color):
    c = Gdk.RGBA()
    c.parse(hex_color)
    return c


def app_css(t):
    """The app's own look, built from the applied theme."""
    fg, bg = t.foreground, t.background
    return f"""
window.rice {{
    background-color: {t.glass};
    color: {fg};
}}
.rice scrolledwindow,
.rice viewport {{
    background: none;
}}
.rice .rc-sidebar {{
    padding: 8px 20px 20px 20px;
}}
.rice .rc-section {{
    margin-top: 16px;
    margin-bottom: 4px;
    font-weight: 600;
    opacity: 0.55;
}}
.rice .rc-row {{
    min-height: 34px;
}}
.rice .rc-unit {{
    opacity: 0.55;
    min-width: 18px;
}}
.rice .rc-dim {{
    opacity: 0.55;
}}
.rice .rc-divider {{
    background-color: alpha({fg}, 0.12);
    min-width: 1px;
    min-height: 1px;
}}
.rice .rc-preview {{
    border: 1px solid alpha({fg}, 0.15);
    border-radius: {t.inner_radius}px;
}}
.rice .rc-toolbar {{
    padding: 12px 20px;
}}
.rice .rc-footer {{
    padding: 12px 20px;
}}

.rice button {{
    background: none;
    color: {fg};
    border: 1px solid alpha({fg}, 0.25);
    border-radius: {t.inner_radius}px;
    box-shadow: none;
    padding: 4px 14px;
    min-height: 24px;
}}
.rice button:hover {{
    background-color: alpha({fg}, 0.08);
}}
.rice button:checked {{
    background-color: {fg};
    color: {bg};
    border-color: {fg};
}}
.rice button:disabled {{
    opacity: 0.35;
}}
.rice button.rc-primary {{
    background-color: {fg};
    color: {bg};
    border-color: {fg};
}}
.rice button.rc-primary:hover {{
    background-color: alpha({fg}, 0.85);
}}
.rice .rc-segmented button {{
    border-radius: 0;
    padding: 2px 14px;
}}
.rice .rc-segmented button:first-child {{
    border-radius: {t.inner_radius}px 0 0 {t.inner_radius}px;
}}
.rice .rc-segmented button:last-child {{
    border-radius: 0 {t.inner_radius}px {t.inner_radius}px 0;
    border-left-width: 0;
}}
.rice colorswatch {{
    border-radius: 3px;
    box-shadow: inset 0 0 0 1px alpha({fg}, 0.35);
}}
.rice selection {{
    background-color: alpha({fg}, 0.3);
    color: {fg};
}}
.rice *:focus-visible {{
    outline: 1px solid alpha({fg}, 0.6);
    outline-offset: 1px;
}}
.rice spinbutton:focus-within {{
    border-color: alpha({fg}, 0.6);
    outline: none;
}}

.rice spinbutton {{
    background: none;
    color: {fg};
    border: 1px solid alpha({fg}, 0.25);
    border-radius: {t.inner_radius}px;
    box-shadow: none;
}}
.rice spinbutton button {{
    border: none;
    border-radius: 0;
    padding: 0 8px;
    min-height: 0;
}}
.rice spinbutton text {{
    padding: 0 0 0 8px;
}}

.rice scale trough {{
    background-color: alpha({fg}, 0.2);
    min-height: 2px;
    border: none;
    border-radius: 1px;
}}
.rice scale highlight {{
    background-color: {fg};
    border: none;
    margin: 0;
    border-radius: 1px;
}}
.rice scale slider {{
    background-color: {fg};
    background-image: none;
    border: none;
    box-shadow: none;
    min-width: 14px;
    min-height: 14px;
    margin: -6px;
    border-radius: 7px;
}}
.rice scale value {{
    min-width: 46px;
}}

.rice switch {{
    background-color: alpha({fg}, 0.2);
    background-image: none;
    border: none;
    border-radius: 11px;
    box-shadow: none;
    padding: 0;
    min-height: 22px;
}}
.rice switch:checked {{
    background-color: {fg};
}}
.rice switch slider {{
    background-color: {bg};
    background-image: none;
    border: none;
    box-shadow: none;
    min-width: 16px;
    min-height: 16px;
    margin: 3px;
    border-radius: 8px;
}}
.rice switch:not(:checked) slider {{
    background-color: {fg};
}}
"""


class RiceWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Rice Control")
        self.set_decorated(False)
        self.set_default_size(1320, 900)
        self.add_css_class("rice")

        self.first_run = not model.exists()
        self.applied = model.load()
        self.edit = self.applied
        self.controls = {}
        self.syncing = False

        self.css = Gtk.CssProvider()
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), self.css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self._load_css()

        self.preview = Preview(self.edit)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        body.set_vexpand(True)
        body.append(self._sidebar())
        body.append(self._divider(Gtk.Orientation.VERTICAL))
        body.append(self._preview_column())
        root.append(body)
        root.append(self._divider(Gtk.Orientation.HORIZONTAL))
        root.append(self._footer())
        self.set_child(root)

        self._shortcuts()
        self._sync_controls()
        self._update_state()

    # ---- layout ---------------------------------------------------------

    def _divider(self, orientation):
        d = Gtk.Box(orientation=orientation)
        d.add_css_class("rc-divider")
        return d

    def _sidebar(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.add_css_class("rc-sidebar")
        for title, rows in SECTIONS:
            label = Gtk.Label(label=title, xalign=0)
            label.add_css_class("rc-section")
            box.append(label)
            for key, text, kind, *opts in rows:
                box.append(self._row(key, text, kind, opts[0] if opts else ""))
        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_size_request(400, -1)
        scroller.set_hexpand(False)  # the rows want to expand, the sidebar doesn't
        scroller.set_child(box)
        return scroller

    def _row(self, key, text, kind, unit):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("rc-row")
        label = Gtk.Label(label=text, xalign=0, hexpand=True)
        label.set_ellipsize(Pango.EllipsizeMode.END)
        row.append(label)
        if key in HINTS:
            row.set_tooltip_text(HINTS[key])

        if kind == "spin":
            lo, hi = model.LIMITS[key]
            control = Gtk.SpinButton.new_with_range(lo, hi, 1)
            control.set_digits(0)
            control.set_numeric(True)
            control.set_valign(Gtk.Align.CENTER)
            control.connect("value-changed", lambda w: self._set(key, int(w.get_value())))
            row.append(control)
            unit_label = Gtk.Label(label=unit, xalign=0)
            unit_label.add_css_class("rc-unit")
            row.append(unit_label)
        elif kind == "scale":
            lo, hi = model.LIMITS[key]
            factor = 100 if unit == "%" else 1
            control = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, lo * factor, hi * factor, 1)
            control.set_digits(0)
            control.set_draw_value(True)
            control.set_value_pos(Gtk.PositionType.RIGHT)
            control.set_size_request(190, -1)
            control.set_format_value_func(lambda _s, v, u=unit: f"{round(v)} {u}")
            control.connect("value-changed",
                            lambda w: self._set(key, round(w.get_value()) / factor))
            control._factor = factor
            row.append(control)
        elif kind == "color":
            control = Gtk.ColorDialogButton(dialog=Gtk.ColorDialog(with_alpha=False, title=text))
            control.set_valign(Gtk.Align.CENTER)
            control.connect("notify::rgba", lambda w, _p: self._set(key, _hex(w.get_rgba())))
            row.append(control)
        elif kind == "switch":
            control = Gtk.Switch(valign=Gtk.Align.CENTER)
            control.connect("notify::active", lambda w, _p: self._set(key, w.get_active()))
            row.append(control)
        elif kind == "font":
            dialog = Gtk.FontDialog(title="Schrift wählen")
            control = Gtk.FontDialogButton(dialog=dialog)
            control.set_level(Gtk.FontLevel.FAMILY)
            control.set_use_font(True)
            control.set_valign(Gtk.Align.CENTER)
            control.set_size_request(190, -1)
            control.connect("notify::font-desc", lambda w, _p: self._font_changed(key, w))
            row.append(control)
        else:
            raise ValueError(kind)

        self.controls[key] = (kind, control, row)
        return row

    def _preview_column(self):
        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        column.set_hexpand(True)

        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        bar.add_css_class("rc-toolbar")
        title = Gtk.Label(label="Vorschau", xalign=0, hexpand=True)
        title.add_css_class("rc-section")
        title.set_margin_top(0)
        bar.append(title)

        switch = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        switch.add_css_class("rc-segmented")
        first = None
        for scene, label in (("windows", "Fenster"), ("launcher", "Launcher")):
            button = Gtk.ToggleButton(label=label)
            if first is None:
                first = button
                button.set_active(True)
            else:
                button.set_group(first)
            button.connect("toggled", lambda b, sc=scene: b.get_active() and self.preview.set_scene(sc))
            switch.append(button)
        bar.append(switch)
        column.append(bar)

        frame = Gtk.Box()
        frame.add_css_class("rc-preview")
        frame.set_overflow(Gtk.Overflow.HIDDEN)
        frame.set_margin_start(20)
        frame.set_margin_end(20)
        frame.append(self.preview)
        column.append(frame)

        note = "Originalgröße: 1 px in der Vorschau = 1 px auf dem Bildschirm. Die Unschärfe ist angenähert."
        if abs(self.preview.scale - round(self.preview.scale)) > 0.01:
            note += (f"\nMonitor-Skalierung {self.preview.scale:g}: dünne Linien in Apps "
                     "werden auf zwei Pixel verteilt und können unscharf wirken.")
        info = Gtk.Label(label=note, xalign=0, wrap=True)
        info.add_css_class("rc-dim")
        info.set_margin_start(20)
        info.set_margin_end(20)
        info.set_margin_top(10)
        info.set_margin_bottom(4)
        column.append(info)
        return column

    def _footer(self):
        footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        footer.add_css_class("rc-footer")
        self.status = Gtk.Label(xalign=0, hexpand=True)
        self.status.set_ellipsize(Pango.EllipsizeMode.END)
        self.status.add_css_class("rc-dim")
        footer.append(self.status)

        self.undo_button = Gtk.Button(label="Rückgängig")
        self.undo_button.set_tooltip_text("Zum Stand vor dem letzten Anwenden zurück (Strg+Z)")
        self.undo_button.connect("clicked", lambda _b: self.undo())
        self.discard_button = Gtk.Button(label="Verwerfen")
        self.discard_button.set_tooltip_text("Nicht angewendete Änderungen zurücksetzen")
        self.discard_button.connect("clicked", lambda _b: self.discard())
        self.apply_button = Gtk.Button(label="Anwenden")
        self.apply_button.set_tooltip_text("In alle Programme schreiben und neu laden (Strg+S)")
        self.apply_button.add_css_class("rc-primary")
        self.apply_button.connect("clicked", lambda _b: self.apply())
        for b in (self.undo_button, self.discard_button, self.apply_button):
            footer.append(b)
        return footer

    def _shortcuts(self):
        controller = Gtk.ShortcutController()
        controller.set_scope(Gtk.ShortcutScope.GLOBAL)
        for trigger, action in (("<Control>s", self.apply), ("<Control>z", self.undo),
                                ("Escape", self.close), ("<Control>q", self.close)):
            controller.add_shortcut(Gtk.Shortcut.new(
                Gtk.ShortcutTrigger.parse_string(trigger),
                Gtk.CallbackAction.new(lambda *_a, f=action: (f(), True)[1])))
        self.add_controller(controller)

    # ---- state ----------------------------------------------------------

    def _load_css(self):
        css = app_css(self.applied)
        try:
            self.css.load_from_string(css)       # GTK 4.12+
        except AttributeError:
            self.css.load_from_data(css, -1)

    def _font_changed(self, key, button):
        desc = button.get_font_desc()
        family = desc.get_family() if desc else None
        if family:
            self._set(key, family)

    def _set(self, key, value):
        if self.syncing:
            return
        self.edit = model.clean(replace(self.edit, **{key: value}))
        self.preview.set_theme(self.edit)
        self._update_state()

    def _sync_controls(self):
        """Put the values of self.edit into the controls without triggering _set."""
        self.syncing = True
        try:
            for key, (kind, control, _row) in self.controls.items():
                value = getattr(self.edit, key)
                if kind == "spin":
                    control.set_value(value)
                elif kind == "scale":
                    control.set_value(value * control._factor)
                elif kind == "color":
                    control.set_rgba(_rgba(value))
                elif kind == "switch":
                    control.set_active(value)
                elif kind == "font":
                    desc = Pango.FontDescription()
                    desc.set_family(value)
                    control.set_font_desc(desc)
        finally:
            self.syncing = False
        self.preview.set_theme(self.edit)

    def _update_state(self):
        for key in ("blur_size", "blur_passes"):
            self.controls[key][2].set_sensitive(self.edit.blur)
        changes = len(model.differences(self.edit, self.applied))
        dirty = changes > 0 or self.first_run
        self.apply_button.set_sensitive(dirty)
        self.discard_button.set_sensitive(changes > 0)
        self.undo_button.set_sensitive(model.has_history())
        if self.first_run:
            self.status.set_label("Noch nie angewendet: einmal „Anwenden“, dann kommen alle Werte aus dieser App.")
        elif changes:
            self.status.set_label(f"{changes} {'Änderung' if changes == 1 else 'Änderungen'}, noch nicht angewendet")
        elif not self.status.get_label():
            self.status.set_label("Alles angewendet")

    # ---- actions --------------------------------------------------------

    def _busy(self, busy):
        for b in (self.undo_button, self.discard_button, self.apply_button):
            b.set_sensitive(not busy)

    def _run_apply(self, theme, push_previous):
        """Write + reload in a thread, so the window never freezes."""
        self._busy(True)
        self.status.set_label("Wird angewendet …" if push_previous else "Wird zurückgesetzt …")
        done = "Angewendet." if push_previous else "Zurückgesetzt auf den Stand davor."
        previous = self.applied

        def work():
            try:
                report = targets.apply(theme)
                if push_previous and not self.first_run:
                    model.push_history(previous)
                model.save(theme)
                GLib.idle_add(self._applied, theme, report, None, done)
            except Exception as error:  # report it instead of dying silently
                if not push_previous:
                    model.push_history(theme)  # a failed undo keeps its step
                GLib.idle_add(self._applied, theme, None, error, done)

        threading.Thread(target=work, daemon=True).start()

    def _applied(self, theme, report, error, done):
        if error is not None:
            self.status.set_label(f"Fehler, nichts übernommen: {error}")
            self._update_state()
            return False
        self.first_run = False
        self.applied = theme
        self.edit = theme
        self._load_css()
        self._sync_controls()
        text = done
        if report.reloaded:
            text += " Sofort neu geladen: " + ", ".join(report.reloaded) + "."
        text += " GTK- und Qt-Apps übernehmen es beim nächsten Öffnen."
        if report.errors:
            text += " Nicht geklappt: " + ", ".join(report.errors) + "."
        self.status.set_label(text)
        self._update_state()
        return False

    def apply(self):
        if self.apply_button.get_sensitive():
            self._run_apply(self.edit, push_previous=True)

    def discard(self):
        self.edit = self.applied
        self._sync_controls()
        self.status.set_label("")
        self._update_state()

    def undo(self):
        if not self.undo_button.get_sensitive():
            return
        previous = model.pop_history()
        if previous is not None:
            self._run_apply(previous, push_previous=False)
        else:
            self._update_state()


class RiceApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.DEFAULT_FLAGS)

    def do_activate(self):
        window = self.get_active_window() or RiceWindow(self)
        window.present()
