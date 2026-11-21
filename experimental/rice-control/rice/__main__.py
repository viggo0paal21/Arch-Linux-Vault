"""Command line entry.

    rice-control              open the app
    rice-control apply        write ~/.config/rice-control/theme.json into every program again
    rice-control apply --no-reload    write the files and set the system font, reload nothing
    rice-control apply --files-only   only write the files (no system font, no reloads)
    rice-control undo         go back to the look before the last apply
"""

import sys

USAGE = __doc__.strip()


def _print_report(report):
    if report.changed:
        print("Geändert:", ", ".join(report.changed))
    else:
        print("Alles war schon aktuell.")
    if report.reloaded:
        print("Neu geladen:", ", ".join(report.reloaded))
    for error in report.errors:
        print("Nicht geklappt:", error, file=sys.stderr)


def main(argv):
    command = argv[1] if len(argv) > 1 else None

    if command in ("-h", "--help", "help"):
        print(USAGE)
        return 0

    if command == "apply":
        from . import targets, theme
        files_only = "--files-only" in argv[2:]
        no_reload = files_only or "--no-reload" in argv[2:]
        t = theme.load()
        report = targets.apply(t, fonts=not files_only, reload=not no_reload)
        if not theme.exists():
            theme.save(t)
        _print_report(report)
        return 1 if report.errors else 0

    if command == "undo":
        from . import targets, theme
        previous = theme.pop_history()
        if previous is None:
            print("Kein älterer Stand vorhanden.")
            return 1
        report = targets.apply(previous)
        theme.save(previous)
        _print_report(report)
        return 0

    if command is not None:
        print(USAGE, file=sys.stderr)
        return 2

    import gi
    for namespace in ("Gtk", "Gdk", "Gsk"):
        gi.require_version(namespace, "4.0")
    from .app import RiceApp
    return RiceApp().run([argv[0]])


if __name__ == "__main__":
    sys.exit(main(sys.argv))
