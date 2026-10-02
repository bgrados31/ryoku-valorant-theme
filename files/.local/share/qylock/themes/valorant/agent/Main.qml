import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

// Valorant-style lockscreen: charcoal + red + cream, Bebas Neue headings, angular cut panels,
// over a looping, colour-graded video (VideoBackdrop.qml, loaded through a Loader).
// Same contract as the other qylock themes (userModel, sessionModel, sddm.*).
// Palette rule: red, cream and charcoal only; nothing blue in the UI chrome.
Rectangle {
    id: root
    readonly property real s: Screen.height / 768
    width: Screen.width
    height: Screen.height
    color: "#0b0f14"

    readonly property color charcoal: "#0b0f14"
    readonly property color panel: "#141a21"
    readonly property color red: "#ff4655"
    readonly property color redDark: "#bd3944"
    readonly property color cream: "#ece8e1"
    readonly property color muted: "#8a8f8c"

    property bool isQuickshell: typeof sddm === "undefined" || sddm.hostName === undefined
    // the in-session lock shim is the only one that defines fingerprintHint; it runs on the
    // shell's compositor, which already draws a real pointer, so the drawn one is greeter-only
    readonly property bool inSessionLock: typeof sddm !== "undefined" && sddm.fingerprintHint === true
    readonly property bool drawCursor: !isQuickshell && !inSessionLock
    // the software scenegraph (weston pixman, no GPU) has no shader effects or curve text:
    // every layer effect and Text.CurveRendering is gated on this (Unknown counts as hardware)
    readonly property bool hwGfx: GraphicsInfo.api !== GraphicsInfo.Software
    readonly property string host: (typeof sddm !== "undefined" && typeof sddm.hostName === "string"
                                    && sddm.hostName !== "" && sddm.hostName !== "localhost")
                                   ? sddm.hostName.toUpperCase() : ""
    readonly property bool fpReady: typeof sddm !== "undefined" && sddm.fingerprintHint === true
                                    && sddm.fingerprintReady === true
    property int sessionIndex: 0
    property real uiOpacity: 1
    property bool typing: passInput.text.length > 0
    property bool busy: false
    property string message: ""
    property string messageKind: ""     // busy | ok | error | info
    property real clockMs: Date.now()
    property string lockedAt: ""
    property real charge: 0
    property real intro: 0          // 0 = hidden, 1 = fully shown; drives the staged entrance and exit
    property real finale: 0         // fades to charcoal during the exit
    property real failFlash: 0      // 1 -> 0 after a failed attempt: brackets and bar turn red
    property bool capsOn: false     // keyboard.capsLock is a stub in the lock shim; inferred from keys
    property real blurAmt: (typing || busy) ? 24 : 0
    Behavior on blurAmt { NumberAnimation { duration: 300 } }
    function seg(a, b) {            // eased 0..1 progress of intro between a and b
        var t = Math.min(1, Math.max(0, (intro - a) / (b - a)))
        return 1 - Math.pow(1 - t, 3)
    }
    function segBack(a, b) {        // OutBack-eased progress (overshoots, then settles)
        var t = Math.min(1, Math.max(0, (intro - a) / (b - a)))
        var c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2)
    }
    property real zoom: 1

    // video lifecycle: paused during the exit, and after 5 min without input
    property bool videoOn: true
    property bool idle: false
    property bool lowPower: false       // lowPowerMode or reduceMotion: poster, no ambient motion
    // the in-session lock waits for performance.json before starting the decoder, so low power never spins it up
    property bool perfKnown: !inSessionLock
    property bool reduceMotion: false   // also skips the intro wipe
    function poke() { if (idle) idle = false; idleTimer.restart() }
    Timer { id: idleTimer; interval: 300000; running: true; onTriggered: root.idle = true }

    // pointer position drives a light UI parallax (never the video)
    property real px: width / 2
    property real py: height / 2
    readonly property real nx: (px - width / 2) / width
    readonly property real ny: (py - height / 2) / height

    // every label: curve-rendered text on the GPU path. Distance-field / native text is drawn
    // with subpixel AA there, which leaves cyan/orange fringes on the stems of small labels;
    // CurveRendering is grey-AA only. The software scenegraph has no curve text.
    component Label: Text {
        renderType: root.hwGfx ? Text.CurveRendering : Text.QtRendering
    }
    // infinite decorative motion (halo pulse, ghost drift) stops when idle, in low-power
    // mode and with reduceMotion, so the scene stops redrawing while nobody is looking
    readonly property bool ambientMotion: !idle && !lowPower

    // a parallelogram, like the tabs of the game's top menu
    component Para: Shape {
        id: sh
        property color fill: "transparent"
        property color stroke: "transparent"
        property real strokeW: 0
        property real skew: 12 * root.s
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: sh.fill; strokeColor: sh.stroke; strokeWidth: sh.strokeW
            joinStyle: ShapePath.MiterJoin
            startX: sh.skew; startY: 0
            PathLine { x: sh.width; y: 0 }
            PathLine { x: sh.width - sh.skew; y: sh.height }
            PathLine { x: 0; y: sh.height }
            PathLine { x: sh.skew; y: 0 }
        }
    }
    // a box with two opposite corners cut off
    component Cut: Shape {
        id: sh
        property color fill: "transparent"
        property color stroke: "transparent"
        property real strokeW: 0
        property real cut: 14 * root.s
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: sh.fill; strokeColor: sh.stroke; strokeWidth: sh.strokeW
            joinStyle: ShapePath.MiterJoin
            startX: 0; startY: 0
            PathLine { x: sh.width - sh.cut; y: 0 }
            PathLine { x: sh.width; y: sh.cut }
            PathLine { x: sh.width; y: sh.height }
            PathLine { x: sh.cut; y: sh.height }
            PathLine { x: 0; y: sh.height - sh.cut }
            PathLine { x: 0; y: 0 }
        }
    }
    // one L-shaped corner bracket; corner 0 = top-left, 1 = top-right, 2 = bottom-right, 3 = bottom-left
    component Corner: Shape {
        id: cn
        property int corner: 0
        property real arm: 14 * root.s
        property real lw: 1.5 * root.s
        property color col: root.cream
        width: arm; height: arm
        preferredRendererType: Shape.CurveRenderer
        readonly property real h: lw / 2
        ShapePath {
            fillColor: "transparent"; strokeColor: cn.col; strokeWidth: cn.lw
            capStyle: ShapePath.FlatCap; joinStyle: ShapePath.MiterJoin
            startX: cn.corner === 0 || cn.corner === 3 ? cn.h : cn.arm - cn.h
            startY: cn.corner === 0 || cn.corner === 1 ? cn.arm : 0
            PathLine {
                x: cn.corner === 0 || cn.corner === 3 ? cn.h : cn.arm - cn.h
                y: cn.corner === 0 || cn.corner === 1 ? cn.h : cn.arm - cn.h
            }
            PathLine {
                x: cn.corner === 0 || cn.corner === 3 ? cn.arm : 0
                y: cn.corner === 0 || cn.corner === 1 ? cn.h : cn.arm - cn.h
            }
        }
    }
    // four corner brackets framing their parent, pushed `gap` outside it
    component Brackets: Item {
        id: br
        property real gap: 6 * root.s
        property real arm: 14 * root.s
        property real lw: 1.5 * root.s
        property color col: Qt.rgba(0.925, 0.91, 0.882, 0.55)
        property color accent: root.red
        property int accentCorner: 0
        property real pop: 1              // 2 -> 1 "snap" during the intro
        anchors.fill: parent
        anchors.margins: -gap * pop
        Corner { corner: 0; arm: br.arm; lw: br.lw; col: br.accentCorner === 0 ? br.accent : br.col; anchors.left: parent.left; anchors.top: parent.top }
        Corner { corner: 1; arm: br.arm; lw: br.lw; col: br.accentCorner === 1 ? br.accent : br.col; anchors.right: parent.right; anchors.top: parent.top }
        Corner { corner: 2; arm: br.arm; lw: br.lw; col: br.accentCorner === 2 ? br.accent : br.col; anchors.right: parent.right; anchors.bottom: parent.bottom }
        Corner { corner: 3; arm: br.arm; lw: br.lw; col: br.accentCorner === 3 ? br.accent : br.col; anchors.left: parent.left; anchors.bottom: parent.bottom }
    }
    // a small outlined rhombus, the HUD's chip icon
    component Rhombus: Item {
        id: rh
        property real size: 10 * root.s
        property color col: root.cream
        property bool filled: false
        width: size; height: size
        Rectangle {
            anchors.centerIn: parent
            width: rh.size / Math.SQRT2; height: width; rotation: 45; antialiasing: true
            color: rh.filled ? rh.col : "transparent"; border.color: rh.col; border.width: 1.5 * root.s
        }
    }

    // software cursor for the SDDM greeter (weston draws none)
    HoverHandler { id: swPointer; enabled: root.drawCursor }
    Canvas {
        width: 26 * root.s; height: 26 * root.s; z: 2000000
        visible: root.drawCursor && swPointer.hovered
        x: swPointer.point.position.x; y: swPointer.point.position.y
        onPaint: {
            var c = getContext("2d"); c.reset(); c.scale(root.s, root.s)
            c.beginPath(); c.moveTo(0,0); c.lineTo(0,16); c.lineTo(4,12.5); c.lineTo(6.5,19)
            c.lineTo(9,18); c.lineTo(6.5,11.5); c.lineTo(11,11.5); c.closePath()
            c.fillStyle = "#ece8e1"; c.fill(); c.lineWidth = 1.2; c.strokeStyle = "#0b0f14"; c.stroke()
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.clockMs = Date.now()
    }

    MouseArea {
        anchors.fill: parent; hoverEnabled: true; z: 0
        onPositionChanged: (m) => { root.px = m.x; root.py = m.y; root.poke() }
        onPressed: (m) => { ripple.fire(m.x, m.y); passInput.forceActiveFocus(); root.poke() }
    }

    FontLoader { id: tungsten; source: "font/BebasNeue-Regular.ttf" }
    FontLoader { id: dinCond; source: "font/BarlowCondensed-SemiBold.ttf" }
    FontLoader { id: dinBody; source: "font/Barlow-Medium.ttf" }

    Item {
        id: stage
        anchors.fill: parent
        opacity: root.uiOpacity
        scale: root.zoom

        // ── background: poster + looping video, graded away from blue, blurred while typing ──
        Item {
            id: bg
            anchors.fill: parent
            scale: 1 + 0.04 * root.charge
            // poster: frame 0 of background.mp4, pre-graded with the same Desaturate 0.6 the video
            // gets below (Qt's Desaturate mixes toward the RGB mean), so the swap is seamless and
            // the software scenegraph, which has no shader effects, still shows the graded still
            Image {
                anchors.fill: parent
                source: "wallpaper.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true; asynchronous: false
            }
            Item {
                id: graded
                anchors.fill: parent
                Loader {
                    id: videoBg
                    anchors.fill: parent
                    active: root.perfKnown && !root.lowPower && root.hwGfx   // VideoOutput draws nothing on the software scenegraph
                    asynchronous: false
                    Component.onCompleted: setSource("VideoBackdrop.qml", { source: Qt.resolvedUrl("background.mp4") })
                    onLoaded: item.playing = Qt.binding(function() { return root.videoOn && !root.idle })
                    onStatusChanged: if (status === Loader.Error) active = false   // the poster stays
                }
                visible: videoBg.status === Loader.Ready && videoBg.item !== null && (videoBg.item.showing || videoBg.item.opacity > 0.001)
                layer.enabled: root.hwGfx && visible
                layer.effect: Desaturate { desaturation: 0.6 }
            }
            layer.enabled: root.hwGfx && (root.blurAmt > 0.5 || root.intro < 0.99)
            layer.effect: FastBlur { radius: Math.max(root.blurAmt, (1 - root.seg(0, 0.35)) * 40) }
        }

        // grade: charcoal veil + a faint red cast so the blue clip reads as slate with red light
        Rectangle { anchors.fill: parent; color: root.charcoal; opacity: 0.30 }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#1fff4655" }
                GradientStop { position: 0.6; color: "#0aff4655" }
                GradientStop { position: 1.0; color: "#05ff4655" }
            }
        }
        // warm red floor light behind the subject
        RadialGradient {
            anchors.fill: parent
            visible: root.hwGfx
            horizontalOffset: -parent.width * 0.08; verticalOffset: parent.height * 0.48
            horizontalRadius: parent.width * 0.55; verticalRadius: parent.height * 0.62
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#38ff4655" }
                GradientStop { position: 1.0; color: "#00ff4655" }
            }
        }
        // scrims: the left keeps the clock legible, the right carries the login card
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#8c0b0f14" }
                GradientStop { position: 0.45; color: "#260b0f14" }
                GradientStop { position: 0.58; color: "#1a0b0f14" }
                GradientStop { position: 1.0; color: "#d90b0f14" }
            }
            opacity: root.typing ? 1 : 0.92
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        Rectangle {        // bottom vignette
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: parent.height * 0.24
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#000b0f14" }
                GradientStop { position: 1.0; color: "#c00b0f14" }
            }
        }
        Rectangle {        // top shade under the HUD strip
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            height: parent.height * 0.18
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#990b0f14" }
                GradientStop { position: 1.0; color: "#000b0f14" }
            }
        }
        // static scanlines: 1px dark line every 3px
        Canvas {
            anchors.fill: parent
            opacity: 0.10
            renderStrategy: Canvas.Immediate
            onPaint: {
                var c = getContext("2d"); c.reset(); c.fillStyle = "#000000"
                for (var y = 0; y < height; y += 3) c.fillRect(0, y, width, 1)
            }
        }
        Rectangle { anchors.fill: parent; color: root.charcoal; opacity: 1 - root.seg(0, 0.25); visible: opacity > 0.01 }

        // three long diagonal hairlines that stop before the card
        Item {
            width: card.x - 30 * root.s; height: parent.height
            clip: true
            opacity: 0.045 * root.seg(0.3, 0.8)
            Repeater {
                model: 3
                delegate: Rectangle {
                    width: 1.5 * root.s; height: root.height * 1.6
                    rotation: 28; color: root.cream; antialiasing: true
                    x: root.width * (0.22 + index * 0.17)
                    y: -root.height * 0.3
                }
            }
        }

        // ghost wordmark: outline-only, two stacked rows, slow horizontal drift. It lives in the
        // gap between the clock block and the card (behind the agent), never behind the clock
        // text: sized to fit that gap (at most 200*s), hidden when the gap is too narrow (5:4)
        Item {
            id: ghost
            property real drift: 0
            SequentialAnimation on drift {
                loops: Animation.Infinite
                running: root.ambientMotion
                NumberAnimation { from: -1; to: 1; duration: 30000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: -1; duration: 30000; easing.type: Easing.InOutSine }
            }
            // advance width of "BLOQUEADO" per pixel of font size
            TextMetrics { id: ghostTm; font.family: tungsten.name; font.pixelSize: 100; text: "BLOQUEADO" }
            readonly property real ratio: Math.max(0.1, ghostTm.advanceWidth / 100)
            readonly property real swing: 10 * root.s            // drift amplitude
            // clear of the clock brackets (20*s outside clockCol) and the card brackets (6*s)
            readonly property real gapL: 72 * root.s + clockCol.width + 44 * root.s + swing
            readonly property real gapR: card.restX - 24 * root.s - swing
            // two rows, the second shifted right by 0.12 em
            readonly property real step: 0.12
            readonly property real px: Math.min(200 * root.s, Math.max(0, gapR - gapL) / (ratio + step))
            visible: px >= 80 * root.s
            width: px * (ratio + step); height: px * 1.74
            x: gapL + (Math.max(0, gapR - gapL) - width) / 2 + ghost.drift * swing
            y: root.height * 0.60 - height / 2
            opacity: root.seg(0.3, 0.8)
            Repeater {
                model: 2
                delegate: Shape {
                    width: ghost.ratio * ghost.px; height: ghost.px * 0.93
                    y: index * ghost.px * 0.81
                    x: index * ghost.step * ghost.px
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.rgba(0.925, 0.91, 0.882, index === 0 ? 0.10 : 0.055)
                        strokeWidth: 1.2 * root.s
                        PathText {
                            x: 0; y: 0
                            text: "BLOQUEADO"
                            font.family: tungsten.name; font.pixelSize: ghost.px
                        }
                    }
                }
            }
        }

        // click ripple: an expanding diamond
        Item {
            id: ripple
            anchors.fill: parent
            property real rx: 0; property real ry: 0
            function fire(x, y) { rx = x; ry = y; ring.r = 0; ring.opacity = 0.8; rAnim.restart() }
            Rectangle {
                id: ring
                property real r: 0
                width: r * 1.4; height: width
                x: ripple.rx - width / 2; y: ripple.ry - height / 2
                rotation: 45; antialiasing: true
                color: "transparent"; border.color: root.red; border.width: 2 * root.s
                opacity: 0
            }
            ParallelAnimation {
                id: rAnim
                NumberAnimation { target: ring; property: "r"; from: 0; to: 240 * root.s; duration: 800; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 800 }
            }
        }

        // ── top HUD strip, like the client's nav bar ──
        Item {
            id: hud
            width: parent.width; height: 44 * root.s
            y: -(1 - root.seg(0.10, 0.30)) * height
            opacity: root.seg(0.08, 0.3)
            Rectangle { anchors.fill: parent; color: root.charcoal; opacity: 0.80 }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.cream; opacity: 0.10 }

            // red skewed "BLOQUEADO" tab
            Item {
                id: hudTab
                x: 40 * root.s; width: 176 * root.s; height: parent.height
                Para { anchors.fill: parent; fill: root.red; skew: 14 * root.s }
                Row {
                    anchors.centerIn: parent
                    spacing: 9 * root.s
                    Image {
                        width: 18 * root.s; height: width; anchors.verticalCenter: parent.verticalCenter
                        source: "emblem.png"; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1.5 * root.s
                        text: "BLOQUEADO"; color: root.cream
                        font.family: tungsten.name; font.pixelSize: 26 * root.s
                        font.letterSpacing: 1 * root.s
                        renderType: root.hwGfx ? Text.CurveRendering : Text.QtRendering   // grey AA on big glyphs (no colour fringes)
                    }
                }
            }
            // icon-only ghost tabs; the first one (the lock) is the current state
            Row {
                anchors.left: hudTab.right; anchors.leftMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * root.s
                Repeater {
                    model: 4
                    delegate: Item {
                        width: 40 * root.s; height: 30 * root.s
                        readonly property bool current: index === 0
                        Para {
                            anchors.fill: parent; skew: 10 * root.s
                            fill: parent.current ? root.cream : "transparent"
                            stroke: parent.current ? root.cream : Qt.rgba(0.925, 0.91, 0.882, 0.18); strokeW: 1 * root.s
                        }
                        // padlock
                        Item {
                            visible: index === 0
                            anchors.centerIn: parent; width: 12 * root.s; height: 14 * root.s
                            Rectangle {
                                x: 2 * root.s; width: 8 * root.s; height: 9 * root.s; radius: 4 * root.s
                                color: "transparent"; border.color: root.charcoal; border.width: 1.8 * root.s
                            }
                            Rectangle { y: 5.5 * root.s; width: 12 * root.s; height: 8.5 * root.s; color: root.charcoal }
                        }
                        // decorative glyphs
                        Rhombus { visible: index === 1; anchors.centerIn: parent; size: 11 * root.s; col: Qt.rgba(0.925, 0.91, 0.882, 0.6) }
                        Column {
                            visible: index === 2; anchors.centerIn: parent; spacing: 2.5 * root.s
                            Repeater { model: 3; delegate: Rectangle { width: 12 * root.s; height: 1.5 * root.s; color: Qt.rgba(0.925, 0.91, 0.882, 0.6) } }
                        }
                        Rectangle {
                            visible: index === 3; anchors.centerIn: parent
                            width: 10 * root.s; height: width; radius: width / 2
                            color: "transparent"; border.color: Qt.rgba(0.925, 0.91, 0.882, 0.6); border.width: 1.5 * root.s
                        }
                    }
                }
            }

            // status chips, right side
            Row {
                anchors.right: parent.right; anchors.rightMargin: 44 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 22 * root.s
                Loader {
                    id: batLoader
                    anchors.verticalCenter: parent.verticalCenter
                    active: root.inSessionLock
                    visible: status === Loader.Ready && item !== null && item.shown === true
                    Component.onCompleted: if (active) setSource("HudStatus.qml", { part: "battery", s: root.s, labelFont: dinCond.name, bodyFont: dinBody.name })
                    onStatusChanged: if (status === Loader.Error) active = false
                }
                Row {
                    visible: root.host !== ""
                    spacing: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    Rhombus { anchors.verticalCenter: parent.verticalCenter }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.host; color: root.cream
                        font.family: dinCond.name; font.pixelSize: 14 * root.s; font.letterSpacing: 1 * root.s
                    }
                }
                Row {
                    spacing: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    Rhombus { anchors.verticalCenter: parent.verticalCenter; col: root.red; filled: true }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(new Date(root.clockMs), "HH:mm"); color: root.cream
                        font.family: dinCond.name; font.pixelSize: 14 * root.s; font.letterSpacing: 1 * root.s
                    }
                }
            }
        }

        // ── clock block, top-left ──
        Item {
            id: clockBox
            x: 72 * root.s - root.nx * 8 * root.s - (1 - root.seg(0.14, 0.40)) * 40 * root.s
            y: 104 * root.s - root.ny * 6 * root.s
            width: clockCol.width; height: clockCol.height
            opacity: root.seg(0.14, 0.36)
            Behavior on x { enabled: root.intro >= 1; NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            Brackets {
                gap: 20 * root.s; arm: 16 * root.s
                accentCorner: 0
                pop: 2 - root.segBack(0.45, 0.62)
                opacity: root.seg(0.45, 0.55)
            }
            Column {
                id: clockCol
                spacing: 0
                Item {
                    width: timeText.width + 16 * root.s + 4 * root.s
                    height: timeText.y + timeText.baselineOffset + 22 * root.s
                    TextMetrics { id: digits; font: timeText.font; text: "00:00" }
                    Label {
                        id: timeText
                        y: -(timeText.baselineOffset + digits.tightBoundingRect.y)   // glyph tops flush with the block
                        text: Qt.formatTime(new Date(root.clockMs), "HH:mm")
                        color: root.cream; font.family: tungsten.name; font.pixelSize: 168 * root.s
                        renderType: root.hwGfx ? Text.CurveRendering : Text.QtRendering   // grey AA on big glyphs (no colour fringes)
                        layer.enabled: root.hwGfx
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.6; shadowBlur: 0.7; shadowVerticalOffset: 3 * root.s; shadowHorizontalOffset: 0 }
                    }
                    // seconds: a vertical bar beside the minutes that fills bottom-up each minute
                    Item {
                        x: timeText.width + 16 * root.s
                        y: 0
                        width: 4 * root.s; height: timeText.y + timeText.baselineOffset
                        Rectangle { anchors.fill: parent; color: root.cream; opacity: 0.14 }
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width; color: root.red
                            height: parent.height * (new Date(root.clockMs).getSeconds() + 1) / 60
                        }
                    }
                }
                Row {
                    spacing: 12 * root.s
                    Para {
                        width: 36 * root.s; height: 20 * root.s; fill: root.red; skew: 7 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: new Date(root.clockMs).toLocaleDateString(Qt.locale("es_ES"), "dddd d 'de' MMMM").toUpperCase()
                        color: root.cream; font.family: dinCond.name; font.pixelSize: 21 * root.s; font.letterSpacing: 2 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        layer.enabled: root.hwGfx
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.5; shadowBlur: 0.5; shadowVerticalOffset: 2 * root.s; shadowHorizontalOffset: 0 }
                    }
                }
                Item { width: 1; height: 10 * root.s }
                Label {
                    text: root.lockedAt !== "" ? "BLOQUEADO DESDE LAS " + root.lockedAt : ""
                    color: root.muted; font.family: dinBody.name; font.pixelSize: 13 * root.s; font.letterSpacing: 1 * root.s
                }
            }
        }

        // unlock: a red diagonal sweep and a cream flash
        Item {
            anchors.fill: parent; clip: true
            Rectangle {
                width: root.width * 0.5; height: root.height * 2.2
                rotation: 18; color: root.red
                y: -root.height * 0.6
                x: -width + root.charge * (root.width + width * 1.6)
                opacity: root.charge > 0 ? 0.9 : 0
            }
        }
        Rectangle {
            anchors.fill: parent; color: root.cream
            opacity: Math.max(0, root.charge - 0.6) / 0.4 * 0.30 * (1 - root.finale)
        }

        // ── login card ──
        Item {
            id: card
            readonly property real pad: 30 * root.s
            width: 380 * root.s; height: cardCol.height + 2 * pad
            // centred on 80% of the width, but clamped inside the screen with room for the
            // brackets: s follows the height only, so on 5:4 the 80% centre would push it off
            readonly property real restX: Math.min(parent.width * 0.80 - width / 2,
                                                   parent.width - width - 56 * root.s)
            x: restX - root.nx * 8 * root.s
            y: parent.height * 0.5 - height / 2 + 22 * root.s - root.ny * 6 * root.s
            opacity: root.seg(0.22, 0.45)
            transform: Translate { x: (1 - root.seg(0.22, 0.50)) * 60 * root.s }
            Behavior on x { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Cut { anchors.fill: parent; fill: "#e0141a21"; stroke: "#2eece8e1"; strokeW: 1 * root.s }
            // red accent bar on the left edge (flashes on failure)
            Rectangle {
                id: sideBar
                x: 0; y: 0; width: 5 * root.s; height: parent.height - 14 * root.s
                color: root.red
            }
            Brackets {
                gap: (root.typing ? 2 : 6) * root.s; arm: 16 * root.s
                col: root.failFlash > 0.01 ? root.red : Qt.rgba(0.925, 0.91, 0.882, 0.45)
                accentCorner: 2
                pop: 2 - root.segBack(0.45, 0.62)
                opacity: root.seg(0.45, 0.55)
                Behavior on gap { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            Column {
                id: cardCol
                x: card.pad; y: card.pad
                width: card.width - 2 * card.pad
                spacing: 0

                // header row
                Item {
                    width: parent.width; height: 18 * root.s
                    Label {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "PERFIL"; color: root.muted
                        font.family: dinCond.name; font.pixelSize: 13 * root.s; font.letterSpacing: 1.5 * root.s
                    }
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 6 * root.s
                        Rhombus { anchors.verticalCenter: parent.verticalCenter; size: 9 * root.s; col: root.red; filled: true }
                        Label {
                            text: "01"; color: root.red
                            font.family: dinCond.name; font.pixelSize: 13 * root.s; font.letterSpacing: 1.5 * root.s
                        }
                    }
                }
                Item { width: 1; height: 10 * root.s }

                // diamond emblem with the V inside, flanked by chevrons
                Item {
                    width: parent.width; height: 112 * root.s
                    Label {
                        anchors.right: avatar.left; anchors.rightMargin: 14 * root.s; anchors.verticalCenter: avatar.verticalCenter
                        text: "‹"; color: root.cream; opacity: 0.6
                        font.family: dinCond.name; font.pixelSize: 30 * root.s
                    }
                    Label {
                        anchors.left: avatar.right; anchors.leftMargin: 14 * root.s; anchors.verticalCenter: avatar.verticalCenter
                        text: "›"; color: root.cream; opacity: 0.6
                        font.family: dinCond.name; font.pixelSize: 30 * root.s
                    }
                    Item {
                        id: avatar
                        width: 112 * root.s; height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle {
                            anchors.centerIn: parent
                            visible: haloAnim.running
                            width: parent.width * 0.72 + halo.v * 44 * root.s; height: width; rotation: 45; antialiasing: true
                            color: "transparent"; border.color: root.red; border.width: 2 * root.s
                            opacity: 0.6 * (1 - halo.v)
                        }
                        NumberAnimation { id: haloAnim; target: halo; property: "v"; from: 0; to: 1; duration: 2400; loops: Animation.Infinite; running: root.ambientMotion; easing.type: Easing.OutQuad }
                        QtObject { id: halo; property real v: 0 }
                        Rectangle {
                            anchors.centerIn: parent; width: parent.width * 0.72; height: width; rotation: 45; antialiasing: true
                            color: root.charcoal; border.color: root.cream; border.width: 2 * root.s
                        }
                        Image {
                            anchors.centerIn: parent; width: parent.width * 0.48; height: width
                            source: "emblem.png"; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                        }
                        scale: (avMouse.containsMouse ? 1.07 : 1.0) * (1 + 0.3 * root.charge)
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                        MouseArea { id: avMouse; anchors.fill: parent; hoverEnabled: true; onClicked: ripple.fire(avatar.mapToItem(stage, width/2, height/2).x, avatar.mapToItem(stage, width/2, height/2).y) }
                    }
                }
                Item { width: 1; height: 12 * root.s }

                Label {
                    id: nameText
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: {
                        var n = (userHelper.currentItem && userHelper.currentItem.uName) ? userHelper.currentItem.uName
                              : (typeof userModel !== "undefined" && userModel.lastUser ? userModel.lastUser : "JUGADOR")
                        return n.toUpperCase()
                    }
                    color: root.cream; font.family: tungsten.name; font.pixelSize: 48 * root.s
                        font.letterSpacing: 1 * root.s
                        renderType: root.hwGfx ? Text.CurveRendering : Text.QtRendering   // grey AA on big glyphs (no colour fringes)
                    lineHeight: 0.9
                }
                Label {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.host !== "" ? "AGENTE  ·  " + root.host : "AGENTE"
                    color: root.red; font.family: dinCond.name; font.pixelSize: 14 * root.s; font.letterSpacing: 1.5 * root.s
                }
                Item { width: 1; height: 18 * root.s }

                // broken hairline, like the weapon tiles' bottom rule
                Item {
                    width: parent.width; height: 1 * root.s
                    readonly property real g: 8 * root.s
                    Rectangle { x: 0; width: parent.width * 0.30 - parent.g / 2; height: parent.height; color: root.cream; opacity: 0.22 }
                    Rectangle { x: parent.width * 0.30 + parent.g / 2; width: parent.width * 0.40 - parent.g; height: parent.height; color: root.cream; opacity: 0.22 }
                    Rectangle { x: parent.width * 0.70 + parent.g / 2; width: parent.width * 0.30 - parent.g / 2; height: parent.height; color: root.red; opacity: 0.8 }
                }
                Item { width: 1; height: 18 * root.s }

                // password field: dark slab, red underline that fills on focus
                Item {
                    id: field
                    width: parent.width; height: 52 * root.s
                    property real xShift: 0
                    transform: Translate { x: field.xShift }
                    Cut { anchors.fill: parent; cut: 10 * root.s; fill: "#d90b0f14"; stroke: passInput.activeFocus ? "#80ece8e1" : "#2eece8e1"; strokeW: 1 * root.s }
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.leftMargin: 10 * root.s
                        height: 2 * root.s; color: root.red
                        width: passInput.activeFocus ? parent.width - 10 * root.s : (parent.width - 10 * root.s) * 0.18
                        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 18 * root.s
                        visible: !root.typing
                        text: "CONTRASEÑA"; color: root.muted
                        font.family: dinCond.name; font.pixelSize: 15 * root.s; font.letterSpacing: 1.5 * root.s
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 16 * root.s
                        text: "ENTER ↵"; color: root.muted; opacity: root.typing ? 1 : 0.6
                        font.family: dinCond.name; font.pixelSize: 12 * root.s; font.letterSpacing: 1 * root.s
                    }
                    // one cream rhombus per character
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 20 * root.s
                        spacing: 10 * root.s
                        Repeater {
                            model: Math.min(passInput.text.length, 18)
                            delegate: Rectangle {
                                width: 9 * root.s; height: width; rotation: 45; color: root.cream; antialiasing: true
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                            }
                        }
                    }
                    TextInput {
                        id: passInput
                        anchors.fill: parent; opacity: 0
                        echoMode: TextInput.Password; focus: true
                        onAccepted: root.doLogin()
                        Keys.onEscapePressed: text = ""
                        Keys.onPressed: (event) => {
                            root.poke()
                            // caps-lock heuristic: a letter whose case disagrees with Shift
                            var t = event.text || ""
                            if (t.length === 1 && t.toUpperCase() !== t.toLowerCase()) {
                                var upper = t === t.toUpperCase()
                                var shift = (event.modifiers & Qt.ShiftModifier) !== 0
                                root.capsOn = upper !== shift
                            } else if (event.key === Qt.Key_CapsLock) {
                                root.capsOn = !root.capsOn
                            }
                            event.accepted = false
                        }
                    }
                }

                // caps-lock warning
                Item {
                    width: parent.width
                    height: root.capsOn ? 24 * root.s : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Label {
                        anchors.left: parent.left; anchors.bottom: parent.bottom
                        text: "▲  BLOQ MAYÚS ACTIVADO"; color: root.red
                        font.family: dinCond.name; font.pixelSize: 12 * root.s; font.letterSpacing: 1.5 * root.s
                    }
                }
                Item { width: 1; height: 14 * root.s }

                // unlock button
                Item {
                    id: go
                    width: parent.width; height: 46 * root.s
                    property bool hot: goMouse.containsMouse && !root.busy
                    Cut {
                        anchors.fill: parent; cut: 10 * root.s
                        fill: go.hot ? root.cream : root.red
                        Behavior on fill { ColorAnimation { duration: 140 } }
                    }
                    // busy: a diagonal hatch moving through the button (GPU path: masked to the
                    // cut shape). The software scenegraph cannot clip Shapes, so there the button
                    // just pulses to the dark red instead.
                    Cut {
                        anchors.fill: parent; cut: 10 * root.s
                        visible: root.busy && !root.hwGfx
                        fill: root.redDark
                        SequentialAnimation on opacity {
                            running: root.busy && !root.hwGfx; loops: Animation.Infinite
                            NumberAnimation { from: 0.2; to: 1; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1; to: 0.2; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }
                    Item {
                        anchors.fill: parent
                        visible: root.busy && root.hwGfx
                        layer.enabled: root.busy && root.hwGfx
                        layer.effect: OpacityMask { maskSource: goMask }
                        Item {
                            id: hatch
                            property real off: 0
                            NumberAnimation on off { from: 0; to: 22 * root.s; duration: 1200; loops: Animation.Infinite; running: root.busy && root.hwGfx }
                            x: -44 * root.s + hatch.off; height: parent.height
                            Repeater {
                                model: Math.ceil(go.width / (22 * root.s)) + 4
                                delegate: Para {
                                    x: index * 22 * root.s; width: 20 * root.s; height: hatch.height
                                    skew: 12 * root.s; fill: root.redDark
                                }
                            }
                        }
                    }
                    Cut { id: goMask; anchors.fill: parent; cut: 10 * root.s; fill: "white"; visible: false; layer.enabled: root.hwGfx }
                    // hover: a red bar slides in from the left
                    Item {
                        anchors.fill: parent; clip: true
                        Rectangle {
                            width: 4 * root.s; height: parent.height - 10 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            x: go.hot ? 10 * root.s : -8 * root.s
                            color: root.red
                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                    }
                    Label {
                        anchors.centerIn: parent; anchors.verticalCenterOffset: 1.5 * root.s
                        text: root.busy ? "VERIFICANDO" : "DESBLOQUEAR"
                        color: go.hot ? root.charcoal : root.cream
                        font.family: tungsten.name; font.pixelSize: 24 * root.s
                        font.letterSpacing: 2 * root.s
                        renderType: root.hwGfx ? Text.CurveRendering : Text.QtRendering   // grey AA on big glyphs (no colour fringes)
                    }
                    MouseArea { id: goMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.doLogin() }
                }

                // status line
                Item {
                    width: parent.width
                    readonly property bool shown: root.message !== "" && root.messageKind !== "busy"   // the button already says VERIFICANDO
                    height: shown ? 30 * root.s : 0
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                        spacing: 8 * root.s
                        opacity: parent.shown ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Rhombus {
                            visible: root.messageKind === "ok" || root.messageKind === "error"
                            anchors.verticalCenter: parent.verticalCenter
                            size: 9 * root.s; col: root.red; filled: true
                        }
                        Label {
                            text: root.message
                            color: root.messageKind === "error" ? root.red : root.cream
                            opacity: root.messageKind === "busy" ? 0.7 : 1
                            font.family: dinCond.name; font.pixelSize: 14 * root.s; font.letterSpacing: 1.5 * root.s
                        }
                    }
                }

                // fingerprint row (only the in-session lock defines these)
                Item {
                    width: parent.width
                    height: root.fpReady ? 32 * root.s : 0
                    visible: root.fpReady
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                        spacing: 8 * root.s
                        Rhombus { anchors.verticalCenter: parent.verticalCenter; size: 10 * root.s }
                        Label {
                            text: "O COLOCA EL DEDO EN EL SENSOR"; color: root.cream; opacity: 0.8
                            font.family: dinCond.name; font.pixelSize: 13 * root.s; font.letterSpacing: 1.5 * root.s
                        }
                    }
                }
            }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "xShift"; to: 14 * root.s; duration: 50 }
                NumberAnimation { target: field; property: "xShift"; to: -14 * root.s; duration: 70 }
                NumberAnimation { target: field; property: "xShift"; to: 8 * root.s; duration: 60 }
                NumberAnimation { target: field; property: "xShift"; to: 0; duration: 50 }
            }
            SequentialAnimation {
                id: failAnim
                PropertyAction { target: root; property: "failFlash"; value: 1 }
                SequentialAnimation {
                    loops: 3
                    ColorAnimation { target: sideBar; property: "color"; to: root.redDark; duration: 90 }
                    ColorAnimation { target: sideBar; property: "color"; to: root.red; duration: 110 }
                }
                PropertyAction { target: root; property: "failFlash"; value: 0 }
            }
        }

        // ── bottom bar ──
        Item {
            id: bottomBar
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 66 * root.s; anchors.rightMargin: 44 * root.s; anchors.bottomMargin: 40 * root.s
            height: 34 * root.s
            opacity: root.seg(0.30, 0.55)
            transform: Translate { y: (1 - root.seg(0.30, 0.55)) * 20 * root.s }

            // power actions as ghost skewed tabs
            Row {
                id: powerRow
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s
                visible: typeof sddm !== "undefined"
                Repeater {
                    model: [ { t: "SUSPENDER", a: 0 }, { t: "REINICIAR", a: 1 }, { t: "APAGAR", a: 2 } ]
                    delegate: Item {
                        id: act
                        width: lbl.implicitWidth + 44 * root.s; height: 34 * root.s
                        property bool hot: pm.containsMouse
                        Para {
                            anchors.fill: parent
                            fill: act.hot ? root.red : "#590b0f14"
                            stroke: act.hot ? root.red : (modelData.a === 2 ? root.red : Qt.rgba(0.925, 0.91, 0.882, 0.18))
                            strokeW: 1 * root.s
                            Behavior on fill { ColorAnimation { duration: 160 } }
                        }
                        Label {
                            id: lbl
                            anchors.centerIn: parent
                            text: modelData.t
                            color: act.hot ? root.cream : "#ccece8e1"
                            font.family: dinCond.name; font.pixelSize: 14 * root.s; font.letterSpacing: 1.5 * root.s
                        }
                        MouseArea {
                            id: pm; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof sddm === "undefined") return
                                if (modelData.a === 0 && sddm.suspend) sddm.suspend()
                                else if (modelData.a === 1) sddm.reboot()
                                else if (modelData.a === 2) sddm.powerOff()
                            }
                        }
                    }
                }
            }

            // now playing (in-session only), centred; it shrinks to the room left between the
            // power tabs and the footer (both sides, so it stays centred) and is hidden below 220*s
            Loader {
                id: mediaLoader
                anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter
                readonly property real room: bottomBar.width
                                             - 2 * (Math.max(powerRow.visible ? powerRow.width : 0, footRow.width) + 32 * root.s)
                width: Math.min(360 * root.s, room); height: 40 * root.s
                visible: room >= 220 * root.s
                active: root.inSessionLock
                Component.onCompleted: if (active) setSource("HudStatus.qml", { part: "media", s: root.s, labelFont: dinCond.name, bodyFont: dinBody.name })
                onStatusChanged: if (status === Loader.Error) active = false
            }

            Row {
                id: footRow
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s
                Rhombus { anchors.verticalCenter: parent.verticalCenter; size: 8 * root.s; col: root.red; filled: true }
                Label {
                    text: "RYOKU  ·  VALORANT"; color: root.muted
                    font.family: dinCond.name; font.pixelSize: 12 * root.s; font.letterSpacing: 1.5 * root.s
                }
            }
        }

        // ── intro: a red skewed slab sweeps across and "deploys" the UI ──
        Para {
            id: wipe
            width: root.width * 0.4; height: root.height
            skew: 60 * root.s
            fill: root.red
            readonly property real p: root.seg(0.0, 0.32)
            x: -width + p * (root.width + width)
            visible: introAnim.running && p > 0 && p < 1
        }

        // exit: cut to charcoal
        Rectangle { anchors.fill: parent; color: root.charcoal; opacity: root.finale * 0.85; visible: opacity > 0.01 }
    }

    // ── session / user helpers (same contract as the other qylock themes) ──
    ListView {
        id: userHelper; width: 1; height: 1; opacity: 0
        currentIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
        model: typeof userModel !== "undefined" ? userModel : null
        delegate: Item { property string uName: model.realName || model.name || ""; property string uLogin: model.name || "" }
    }
    Item {
        visible: false
        Repeater {
            id: sessionScan
            model: (typeof sessionModel !== "undefined") ? sessionModel : null
            delegate: Item { property string sName: model.name || "" }
        }
    }
    function preferredSessionIndex() {
        if (typeof sessionModel === "undefined") return 0
        var want = (typeof sessionModel.desktopName === "string") ? sessionModel.desktopName : ""
        var exact = -1, loose = -1
        for (var i = 0; i < sessionScan.count; i++) {
            var it = sessionScan.itemAt(i); if (!it) continue
            var low = (it.sName || "").toLowerCase()
            if (low.indexOf("uwsm") >= 0) continue
            if (want !== "" && low === want) exact = i
            else if (want !== "" && low.indexOf(want) >= 0 && loose < 0) loose = i
        }
        if (exact >= 0) return exact
        if (loose >= 0) return loose
        return (sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    }

    function doLogin() {
        if (busy) return
        busy = true; message = "VERIFICANDO"; messageKind = "busy"
        shake.stop(); chargeBack.stop(); unlockSeq.restart()
    }
    function authenticate() {
        var uname = (userHelper.currentItem && userHelper.currentItem.uLogin) ? userHelper.currentItem.uLogin
                  : (typeof userModel !== "undefined" ? userModel.lastUser : "user")
        if (typeof sddm !== "undefined") sddm.login(uname, passInput.text, root.sessionIndex)
        watchdog.restart()
    }
    SequentialAnimation {
        id: unlockSeq
        NumberAnimation { target: root; property: "charge"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutCubic }
        ScriptAction { script: root.authenticate() }
    }
    NumberAnimation { id: chargeBack; target: root; property: "charge"; to: 0; duration: 450; easing.type: Easing.OutCubic }
    Timer { id: watchdog; interval: 8000; onTriggered: { root.busy = false; root.message = ""; root.messageKind = ""; passInput.text = ""; chargeBack.start(); passInput.forceActiveFocus() } }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        ignoreUnknownSignals: true
        function onSurfaceRevealed() { root.playIntro() }
        function onInformationMessage(m) { root.message = (m || "").toUpperCase(); root.messageKind = "info"; passInput.forceActiveFocus() }
        function onErrorMessage(m) { root.message = (m || "").toUpperCase(); root.messageKind = "error" }
        function onLoginSucceeded() { watchdog.stop(); root.message = "ACCESO CONCEDIDO"; root.messageKind = "ok"; root.playOutro() }
        function onLoginFailed() {
            watchdog.stop(); unlockSeq.stop(); root.busy = false; root.message = "ACCESO DENEGADO"; root.messageKind = "error"
            chargeBack.start(); passInput.text = ""; passInput.forceActiveFocus(); shake.start(); failAnim.restart()
        }
    }

    // reduceMotion: no red wipe or staged entrance, the UI is simply there
    function playIntro() {
        outroAnim.stop(); introAnim.stop(); root.videoOn = true; root.finale = 0; root.zoom = 1
        if (root.reduceMotion) { root.intro = 1; return }
        root.intro = 0; introAnim.start()
    }
    // performance.json is read asynchronously: if it lands mid-intro, jump to the end
    onReduceMotionChanged: if (reduceMotion && introAnim.running) { introAnim.stop(); root.intro = 1 }
    function playOutro() { introAnim.stop(); root.videoOn = false; outroAnim.start() }
    NumberAnimation { id: introAnim; target: root; property: "intro"; from: 0; to: 1; duration: 1500; easing.type: Easing.Linear }
    ParallelAnimation {
        id: outroAnim
        NumberAnimation { target: root; property: "intro"; to: 0; duration: 800; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "zoom"; to: 1.08; duration: 800; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "finale"; to: 1; duration: 500 }
    }

    // low-power: the in-session lock may read ~/.config/ryoku/performance.json (lock.sh exports
    // QML_XHR_ALLOW_FILE_READ=1); lowPowerMode or reduceMotion keeps the poster instead of the video
    function readPerformance() {
        var here = Qt.resolvedUrl(".").toString()
        var cut = here.indexOf("/.local/share/")
        if (cut < 0) { root.perfKnown = true; return }
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            root.perfKnown = true
            if (xhr.responseText === "") return
            try {
                var p = JSON.parse(xhr.responseText)
                root.reduceMotion = p.reduceMotion === true
                root.lowPower = p.lowPowerMode === true || root.reduceMotion
            } catch (e) { }
        }
        xhr.open("GET", here.substring(0, cut) + "/.config/ryoku/performance.json")
        xhr.send()
    }

    Timer { interval: 300; running: true; onTriggered: passInput.forceActiveFocus() }
    Timer { interval: 400; running: !root.perfKnown; onTriggered: root.perfKnown = true }   // never wait forever on the file read
    Component.onCompleted: {
        root.lockedAt = Qt.formatTime(new Date(), "HH:mm")
        if (typeof sessionModel !== "undefined") sessionIndex = preferredSessionIndex()
        if (root.inSessionLock) readPerformance()
        if (!root.inSessionLock) playIntro()
    }
}
