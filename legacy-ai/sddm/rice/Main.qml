// SDDM-Theme "rice": Login-Bildschirm passend zum Hyprland-Rice.
// Schwarz-weiss, Noto Sans, Flaechen 80 % Schwarz wie Waybar, kitty und rofi.
// Gleiches Layout wie ~/.config/hypr/hyprlock.conf (Uhr, Datum, Profilbild, Name, Passwortfeld).
//
// SDDM stellt dem Theme diese Objekte bereit:
//   sddm          login(), powerOff(), reboot(), Signale loginFailed / loginSucceeded
//   userModel     Benutzer (Rollen name, realName, icon), lastIndex = zuletzt angemeldet
//   sessionModel  Sitzungen (Rolle name), lastIndex = zuletzt benutzt
//   keyboard      capsLock
//   config        Werte aus theme.conf

import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    width: 2560
    height: 1440
    color: "black"

    // ---- Farben und Masse (wie im restlichen Rice) ----
    readonly property color glass: "#cc000000"     // 80 % Schwarz
    readonly property color hairline: "#26ffffff"  // 1-px-Rand, 15 % Weiss
    readonly property color subtle: "#bfffffff"    // Nebentext, 75 % Weiss
    readonly property real radius: 10              // wie rounding = 10 in hyprland.lua
    readonly property int maxDots: 22              // so viele Punkte passen ins Feld
    readonly property string fontName: config.font !== "" ? config.font : "Noto Sans"

    // ---- Benutzer und Sitzung ----
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property string userName: ""
    property string realName: ""
    property string userIcon: ""
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property var sessionNames: []

    // Rollen der Models lassen sich nur ueber Delegates lesen: unsichtbare Repeater
    Repeater {
        model: userModel
        delegate: Item {
            visible: false
            Component.onCompleted: {
                if (index === root.userIndex) {
                    root.userName = model.name
                    root.realName = model.realName
                    root.userIcon = model.icon
                }
            }
        }
    }
    Repeater {
        model: sessionModel
        delegate: Item {
            visible: false
            Component.onCompleted: {
                var names = root.sessionNames.slice()
                names[index] = model.name
                root.sessionNames = names
            }
        }
    }

    // ---- Uhrzeit ----
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // ---- Anmelden ----
    function login() {
        if (password.text.length === 0)
            return
        message.text = ""
        sddm.login(root.userName, password.text, root.sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            message.text = "Wrong password"
            shake.restart()
            password.forceActiveFocus()
        }
    }

    // ---- Hintergrund: Bild, geblurrt und leicht abgedunkelt ----
    Image {
        id: background
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: background
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: config.blur !== "" ? Number(config.blur) : 0.6
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: config.dim !== "" ? Number(config.dim) : 0.4
    }

    // ---- Uhr und Datum ----
    Text {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -270
        text: Qt.formatTime(root.now, "HH:mm")
        color: "white"
        font.family: root.fontName
        font.pixelSize: 120
        font.weight: Font.Light
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -185
        // englisch wie die Waybar-Uhr, unabhaengig von der Systemsprache
        text: root.now.toLocaleDateString(Qt.locale("en_US"), "dddd, dd.MM.")
        color: root.subtle
        font.family: root.fontName
        font.pixelSize: 20
    }

    // ---- Profilbild: Kreis mit Haarlinie ----
    Item {
        id: avatar
        width: 96
        height: 96
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -30

        Image {
            id: face
            anchors.fill: parent
            // theme.conf "avatar" zuerst, sonst das Kontobild vom System
            source: config.avatar !== "" ? config.avatar : root.userIcon
            sourceSize: Qt.size(192, 192)
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        Rectangle {
            id: faceMask
            anchors.fill: parent
            radius: width / 2
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: face
            maskEnabled: true
            maskSource: faceMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            visible: face.status === Image.Ready
        }
        // ohne Bild: Anfangsbuchstabe auf Glas
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.glass
            visible: face.status !== Image.Ready
            Text {
                anchors.centerIn: parent
                text: (root.realName || root.userName || "?").charAt(0).toUpperCase()
                color: "white"
                font.family: root.fontName
                font.pixelSize: 40
                font.weight: Font.Light
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: root.hairline
        }
    }

    // ---- Name ----
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 42
        text: root.realName !== "" ? root.realName : root.userName
        color: "white"
        font.family: root.fontName
        font.pixelSize: 18
    }

    // ---- Passwortfeld ----
    Rectangle {
        id: field
        width: 320
        height: 44
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 110
        radius: root.radius
        color: root.glass
        border.width: 1
        border.color: password.activeFocus ? "#4dffffff" : root.hairline
        Behavior on border.color { ColorAnimation { duration: 200 } }

        transform: Translate { id: shakeOffset }
        // falsches Passwort: kurz seitlich schuetteln
        SequentialAnimation {
            id: shake
            NumberAnimation { target: shakeOffset; property: "x"; to: -10; duration: 50 }
            NumberAnimation { target: shakeOffset; property: "x"; to: 10; duration: 80 }
            NumberAnimation { target: shakeOffset; property: "x"; to: -6; duration: 80 }
            NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 60 }
        }

        TextInput {
            id: password
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            echoMode: TextInput.Password
            // eigener Text unsichtbar, die Punkte zeichnet die Row darunter
            color: "transparent"
            selectionColor: "transparent"
            selectedTextColor: "transparent"
            font.family: root.fontName
            font.pixelSize: 14
            font.letterSpacing: 3
            clip: true
            focus: true
            cursorDelegate: Item {}   // kein Strich: die Punkte zeigen schon, dass getippt wird
            Keys.onReturnPressed: root.login()
            Keys.onEnterPressed: root.login()
            // pro Zeichen ein Eintrag in dotModel: neue Punkte kommen dazu, alte bleiben stehen
            onTextChanged: {
                var n = Math.min(text.length, root.maxDots)
                while (dotModel.count < n) dotModel.append({})
                while (dotModel.count > n) dotModel.remove(dotModel.count - 1)
            }
        }

        // Punkte wie bei hyprlock: echte Kreise, jeder neue ploppt weich auf
        ListModel { id: dotModel }
        Row {
            id: dots
            // nicht per anchors zentriert, sondern ueber x mit Animation:
            // kommt ein Punkt dazu, gleitet die Reihe weich zur neuen Mitte statt zu springen
            x: (parent.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Repeater {
                model: dotModel
                delegate: Rectangle {
                    id: dot
                    width: 9
                    height: 9
                    radius: width / 2
                    color: "white"
                    scale: 0
                    opacity: 0
                    ParallelAnimation {
                        running: true
                        NumberAnimation { target: dot; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                        NumberAnimation { target: dot; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: "Password"
            color: root.subtle
            font.family: root.fontName
            font.pixelSize: 14
            visible: password.text.length === 0
        }
    }

    // ---- Meldung unter dem Feld (falsches Passwort / Feststelltaste) ----
    Text {
        id: message
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 160
        color: root.subtle
        font.family: root.fontName
        font.pixelSize: 14
        visible: text !== ""
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 160
        text: "Caps Lock is on"
        color: root.subtle
        font.family: root.fontName
        font.pixelSize: 14
        visible: message.text === "" && typeof keyboard !== "undefined" && keyboard !== null && keyboard.capsLock
    }

    // ---- Knopf als kleine Glas-Pille (wie die Leiste) ----
    component Pill: Rectangle {
        id: pill
        property alias label: pillText.text
        signal clicked()
        width: pillText.implicitWidth + 28
        height: 34
        radius: root.radius
        color: pillMouse.containsMouse ? "#26ffffff" : root.glass
        border.width: 1
        border.color: root.hairline
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
            id: pillText
            anchors.centerIn: parent
            color: "white"
            font.family: root.fontName
            font.pixelSize: 13
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    // unten links: Sitzung (Klick wechselt, falls mehrere installiert sind)
    Pill {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 10
        label: root.sessionNames.length > 0 ? root.sessionNames[root.sessionIndex] : "Session"
        onClicked: {
            if (root.sessionNames.length > 1)
                root.sessionIndex = (root.sessionIndex + 1) % root.sessionNames.length
        }
    }

    // unten rechts: Neustart und Herunterfahren
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 10
        Pill {
            label: "Restart"
            visible: sddm.canReboot
            onClicked: sddm.reboot()
        }
        Pill {
            label: "Shut down"
            visible: sddm.canPowerOff
            onClicked: sddm.powerOff()
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
