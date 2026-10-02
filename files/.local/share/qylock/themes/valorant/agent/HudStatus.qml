// In-session-only HUD chips: battery (UPower) and now playing (MPRIS).
//
// Main.qml loads this through a Loader, and only inside the Quickshell lock
// (the SDDM greeter has no Quickshell modules). If an import fails, only that
// Loader goes to Error and the rest of the lockscreen is untouched.
import QtQuick
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

Item {
    id: hs
    property string part: "battery"       // "battery" | "media"
    property real s: 1
    property color cream: "#ece8e1"
    property color red: "#ff4655"
    property color muted: "#8a8f8c"
    property string labelFont: ""
    property string bodyFont: ""
    // grey-AA curve text on the GPU path: distance-field text leaves subpixel colour fringes
    readonly property bool hwGfx: GraphicsInfo.api !== GraphicsInfo.Software

    implicitWidth: part === "battery" ? batRow.implicitWidth : (hasMedia ? 360 * s : 0)
    implicitHeight: part === "battery" ? batRow.implicitHeight : 40 * s
    // Main.qml reads `shown` (not `visible`, which also depends on the Loader's own visibility)
    readonly property bool shown: part === "battery" ? hasBattery : hasMedia
    visible: shown

    // ── battery ──
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev !== null && dev.ready && dev.isLaptopBattery
    readonly property int pct: hasBattery ? Math.round(dev.percentage * 100) : 0
    readonly property bool charging: !UPower.onBattery

    Row {
        id: batRow
        visible: hs.part === "battery"
        spacing: 7 * hs.s
        // battery glyph: body + nub + fill
        Item {
            width: 22 * hs.s; height: 11 * hs.s
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: parent.width - 3 * hs.s; height: parent.height
                color: "transparent"; border.color: hs.cream; border.width: 1.5 * hs.s
                Rectangle {
                    x: 2.5 * hs.s; y: 2.5 * hs.s; height: parent.height - 5 * hs.s
                    width: Math.max(1, (parent.width - 5 * hs.s) * hs.pct / 100)
                    color: hs.pct <= 15 && !hs.charging ? hs.red : hs.cream
                }
            }
            Rectangle {
                x: parent.width - 2 * hs.s; y: parent.height * 0.3
                width: 2 * hs.s; height: parent.height * 0.4; color: hs.cream
            }
        }
        Text {
            renderType: hs.hwGfx ? Text.CurveRendering : Text.QtRendering
            anchors.verticalCenter: parent.verticalCenter
            text: hs.pct + "%" + (hs.charging ? (hs.pct >= 99 ? "  ·  CONECTADO" : "  ·  CARGANDO") : "")
            color: hs.pct <= 15 && !hs.charging ? hs.red : hs.cream
            font.family: hs.labelFont; font.pixelSize: 14 * hs.s; font.letterSpacing: 1 * hs.s
        }
    }

    // ── now playing ──
    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: {
        var p = hs.players, first = null
        for (var i = 0; i < p.length; i++) {
            if (!p[i]) continue
            if (p[i].isPlaying) return p[i]
            if (first === null && (p[i].trackTitle || "") !== "") first = p[i]
        }
        return first
    }
    readonly property bool hasMedia: player !== null && (player.trackTitle || "") !== ""

    Timer {
        interval: 1000; repeat: true
        running: hs.part === "media" && hs.hasMedia && hs.player.isPlaying
        onTriggered: if (hs.player) hs.player.positionChanged()
    }

    Item {
        visible: hs.part === "media" && hs.hasMedia
        anchors.fill: parent
        // rhombus play marker
        Rectangle {
            id: mark
            width: 9 * hs.s; height: width; rotation: 45
            x: 2 * hs.s; anchors.verticalCenter: parent.verticalCenter
            color: hs.player && hs.player.isPlaying ? hs.red : "transparent"
            border.color: hs.red; border.width: 1.5 * hs.s
        }
        Column {
            anchors.left: mark.right; anchors.leftMargin: 14 * hs.s
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1 * hs.s
            Text {
            renderType: hs.hwGfx ? Text.CurveRendering : Text.QtRendering
                width: parent.width; elide: Text.ElideRight
                text: hs.player ? (hs.player.trackTitle || "").toUpperCase() : ""
                color: hs.cream; font.family: hs.labelFont; font.pixelSize: 15 * hs.s; font.letterSpacing: 1 * hs.s
            }
            Text {
            renderType: hs.hwGfx ? Text.CurveRendering : Text.QtRendering
                width: parent.width; elide: Text.ElideRight
                text: hs.player ? (hs.player.trackArtist || hs.player.identity || "").toUpperCase() : ""
                color: hs.muted; font.family: hs.labelFont; font.pixelSize: 12 * hs.s; font.letterSpacing: 1 * hs.s
            }
            Item {
                width: parent.width; height: 2 * hs.s
                Rectangle { anchors.fill: parent; color: hs.cream; opacity: 0.15 }
                Rectangle {
                    height: parent.height; color: hs.red
                    width: (hs.player && hs.player.lengthSupported && hs.player.length > 0)
                           ? parent.width * Math.min(1, hs.player.position / hs.player.length) : 0
                }
            }
        }
    }
}
