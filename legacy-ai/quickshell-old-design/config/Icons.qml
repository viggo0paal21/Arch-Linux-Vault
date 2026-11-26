pragma Singleton

import QtQuick
import Quickshell

// Nerd Font glyphs (Material Design Icons from "JetBrainsMono Nerd Font").
// Codepoints checked against nerd-fonts/glyphnames.json.
Singleton {
    readonly property string arch: String.fromCodePoint(0xF303)
    readonly property string tux: String.fromCodePoint(0xF31A)
    readonly property string volHigh: String.fromCodePoint(0xF057E)
    readonly property string volMed: String.fromCodePoint(0xF0580)
    readonly property string volLow: String.fromCodePoint(0xF057F)
    readonly property string volOff: String.fromCodePoint(0xF0581)
    readonly property string volMute: String.fromCodePoint(0xF075F)
    readonly property string mic: String.fromCodePoint(0xF036C)
    readonly property string micOff: String.fromCodePoint(0xF036D)
    readonly property string bell: String.fromCodePoint(0xF009A)
    readonly property string bellOutline: String.fromCodePoint(0xF009C)
    readonly property string bellOff: String.fromCodePoint(0xF009B)
    readonly property string bellBadge: String.fromCodePoint(0xF116B)
    readonly property string power: String.fromCodePoint(0xF0425)
    readonly property string lock: String.fromCodePoint(0xF033E)
    readonly property string logout: String.fromCodePoint(0xF0343)
    readonly property string restart: String.fromCodePoint(0xF0709)
    readonly property string sleep: String.fromCodePoint(0xF04B2)
    readonly property string cog: String.fromCodePoint(0xF0493)
    readonly property string search: String.fromCodePoint(0xF0349)
    readonly property string cpu: String.fromCodePoint(0xF4BC) // oct-cpu
    readonly property string ram: String.fromCodePoint(0xEFC5) // fa-memory
    readonly property string temp: String.fromCodePoint(0xF050F)
    readonly property string disk: String.fromCodePoint(0xF02CA)
    readonly property string gpu: String.fromCodePoint(0xF08AE)
    readonly property string ethernet: String.fromCodePoint(0xF0200)
    readonly property string wifiOff: String.fromCodePoint(0xF05AA)
    readonly property string wifi1: String.fromCodePoint(0xF091F)
    readonly property string wifi2: String.fromCodePoint(0xF0922)
    readonly property string wifi3: String.fromCodePoint(0xF0925)
    readonly property string wifi4: String.fromCodePoint(0xF0928)
    readonly property string lanOff: String.fromCodePoint(0xF0319)
    readonly property string bluetooth: String.fromCodePoint(0xF00AF)
    readonly property string bluetoothOff: String.fromCodePoint(0xF00B2)
    readonly property string bluetoothOn: String.fromCodePoint(0xF00B1)
    readonly property string play: String.fromCodePoint(0xF040A)
    readonly property string pause: String.fromCodePoint(0xF03E4)
    readonly property string next: String.fromCodePoint(0xF04AD)
    readonly property string prev: String.fromCodePoint(0xF04AE)
    readonly property string music: String.fromCodePoint(0xF0387)
    readonly property string close: String.fromCodePoint(0xF0156)
    readonly property string left: String.fromCodePoint(0xF0141)
    readonly property string right: String.fromCodePoint(0xF0142)
    readonly property string down: String.fromCodePoint(0xF0140)
    readonly property string up: String.fromCodePoint(0xF0143)
    readonly property string calendar: String.fromCodePoint(0xF00ED)
    readonly property string clock: String.fromCodePoint(0xF0150)
    readonly property string coffee: String.fromCodePoint(0xF0176)
    readonly property string coffeeOutline: String.fromCodePoint(0xF06CA)
    readonly property string arrowDown: String.fromCodePoint(0xF0045)
    readonly property string arrowUp: String.fromCodePoint(0xF005D)
    readonly property string clearAll: String.fromCodePoint(0xF039F)
    readonly property string apps: String.fromCodePoint(0xF003B)
    readonly property string terminal: String.fromCodePoint(0xF018D)
    readonly property string calculator: String.fromCodePoint(0xF00EC)
    readonly property string check: String.fromCodePoint(0xF012C)
    readonly property string moon: String.fromCodePoint(0xF0F65)
    readonly property string sun: String.fromCodePoint(0xF0599)
    readonly property string account: String.fromCodePoint(0xF0004)
    readonly property string timer: String.fromCodePoint(0xF051B)
    readonly property string screenshot: String.fromCodePoint(0xF0E51)
    readonly property string battery: String.fromCodePoint(0xF0079)
    readonly property string batteryCharging: String.fromCodePoint(0xF0084)
    readonly property string headphones: String.fromCodePoint(0xF02CB)
    readonly property string speaker: String.fromCodePoint(0xF04C3)
    readonly property string info: String.fromCodePoint(0xF02FD)
    readonly property string message: String.fromCodePoint(0xF0365)
    readonly property string reload: String.fromCodePoint(0xF0453)
    readonly property string tune: String.fromCodePoint(0xF062E)
    readonly property string minus: String.fromCodePoint(0xF0374)
    readonly property string plus: String.fromCodePoint(0xF0415)
    readonly property string dot: String.fromCodePoint(0xF09DF)
    readonly property string pulse: String.fromCodePoint(0xF0430)
    readonly property string monitor: String.fromCodePoint(0xF0379)
    readonly property string fan: String.fromCodePoint(0xF0210)
    // Settings tabs
    readonly property string palette: String.fromCodePoint(0xF0E0C) // md-palette_outline
    readonly property string dockTop: String.fromCodePoint(0xF1513) // md-dock_top
    readonly property string cogOutline: String.fromCodePoint(0xF08BB) // md-cog_outline
    readonly property string consoleLine: String.fromCodePoint(0xF07B7) // md-console_line
    // Settings > Wallpaper
    readonly property string image: String.fromCodePoint(0xF0976) // md-image_outline
    readonly property string shuffle: String.fromCodePoint(0xF049F) // md-shuffle_variant
    readonly property string refresh: String.fromCodePoint(0xF0450) // md-refresh
}
