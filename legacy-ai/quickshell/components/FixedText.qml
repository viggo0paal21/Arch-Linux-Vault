import QtQuick
import qs.config

// Text with tabular digits (tnum): every digit has the same width, so "23:13:59" -> "23:14:00" or
// "62%" -> "64%" never changes the width and nothing next to it moves. Otherwise a normal Txt with its
// natural width (no reserved space).
Txt {
    font.features: ({
            "tnum": 1
        })
}
