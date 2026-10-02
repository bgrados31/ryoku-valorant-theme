import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

// Valorant-style lockscreen: navy + red + cream, Bebas Neue headings, angular cut panels.
// Same contract as the other qylock themes (userModel, sessionModel, sddm.*).
Rectangle {
    id: root
    readonly property real s: Screen.height / 768
    width: Screen.width
    height: Screen.height
    color: "#0f1923"

    readonly property color navy: "#0f1923"
    readonly property color panel: "#17222e"
    readonly property color red: "#ff4655"
    readonly property color redDark: "#bd3944"
    readonly property color cream: "#ece8e1"
    readonly property color teal: "#3dd6c6"
    readonly property color muted: "#768079"

    property bool isQuickshell: typeof sddm === "undefined" || sddm.hostName === undefined
    // the in-session lock shim is the only one that defines fingerprintHint; it runs on the
    // shell's compositor, which already draws a real pointer, so the drawn one is greeter-only
    readonly property bool inSessionLock: typeof sddm !== "undefined" && sddm.fingerprintHint === true
    readonly property bool drawCursor: !isQuickshell && !inSessionLock
    property int sessionIndex: 0
    property real uiOpacity: 1
    property bool typing: passInput.text.length > 0
    property bool busy: false
    property string message: ""
    property real clockMs: Date.now()
    property real charge: 0
    property real intro: 0          // 0 = hidden, 1 = fully shown; drives the staged entrance and exit
    property real finale: 0         // fades the unlock flash during the exit
    property real blurAmt: (typing || busy) ? 30 : 0
    Behavior on blurAmt { NumberAnimation { duration: 350 } }
    function seg(a, b) {            // eased 0..1 progress of intro between a and b
        var t = Math.min(1, Math.max(0, (intro - a) / (b - a)))
        return 1 - Math.pow(1 - t, 3)
    }
    property real zoom: 1

    // pointer position drives a light parallax
    property real px: width / 2
    property real py: height / 2
    readonly property real nx: (px - width / 2) / width
    readonly property real ny: (py - height / 2) / height

    // a parallelogram, like the tabs of the game's top menu
    component Para: Shape {
        id: sh
        property color fill: "transparent"
        property color stroke: "transparent"
        property real strokeW: 0
        property real skew: 12 * root.s
        ShapePath {
            fillColor: sh.fill; strokeColor: sh.stroke; strokeWidth: sh.strokeW
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
        ShapePath {
            fillColor: sh.fill; strokeColor: sh.stroke; strokeWidth: sh.strokeW
            startX: 0; startY: 0
            PathLine { x: sh.width - sh.cut; y: 0 }
            PathLine { x: sh.width; y: sh.cut }
            PathLine { x: sh.width; y: sh.height }
            PathLine { x: sh.cut; y: sh.height }
            PathLine { x: 0; y: sh.height - sh.cut }
            PathLine { x: 0; y: 0 }
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
            c.fillStyle = "#ece8e1"; c.fill(); c.lineWidth = 1.2; c.strokeStyle = "#0f1923"; c.stroke()
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.clockMs = Date.now()
    }

    MouseArea {
        anchors.fill: parent; hoverEnabled: true; z: 0
        onPositionChanged: (m) => { root.px = m.x; root.py = m.y }
        onPressed: (m) => { ripple.fire(m.x, m.y); passInput.forceActiveFocus() }
    }

    FontLoader { id: tungsten; source: "font/BebasNeue-Regular.ttf" }
    FontLoader { id: dinCond; source: "font/BarlowCondensed-SemiBold.ttf" }
    FontLoader { id: dinBody; source: "font/Barlow-Medium.ttf" }

    Item {
        id: stage
        anchors.fill: parent
        opacity: root.uiOpacity
        scale: root.zoom

        // ── wallpaper with parallax, slow breathing and blur while typing ──
        Item {
            id: wallWrap
            anchors.fill: parent
            scale: (1 + 0.05 * root.charge) * (1 + 0.22 * (1 - root.seg(0, 0.8)))
            Image {
                id: wall
                source: "wallpaper.png"
                width: parent.width * 1.08; height: parent.height * 1.08
                x: -parent.width * 0.04 - root.nx * 30 * root.s
                y: -parent.height * 0.04 - root.ny * 20 * root.s
                fillMode: Image.PreserveAspectCrop
                smooth: true
                Behavior on x { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.02; duration: 16000; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.02; to: 1.0; duration: 16000; easing.type: Easing.InOutSine }
                }
            }
            layer.enabled: root.blurAmt > 0.5 || root.intro < 0.99
            layer.effect: FastBlur { radius: Math.max(root.blurAmt, (1 - root.seg(0, 0.8)) * 48) }
        }
        // navy wash: stronger on the right so the login card reads, lighter on the left
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#660f1923" }
                GradientStop { position: 0.55; color: "#330f1923" }
                GradientStop { position: 1.0; color: "#e60f1923" }
            }
            opacity: root.typing ? 1 : 0.85
            Behavior on opacity { NumberAnimation { duration: 350 } }
        }
        Rectangle { anchors.fill: parent; color: root.navy; opacity: 1 - root.seg(0, 0.4); visible: opacity > 0.01 }

        // thin diagonal scan lines, like the game's menu backdrop
        Item {
            anchors.fill: parent; opacity: 0.07 * root.seg(0.3, 1)
            Repeater {
                model: 7
                delegate: Rectangle {
                    width: 1.5 * root.s; height: root.height * 1.6
                    rotation: 28; color: root.cream; antialiasing: true
                    x: root.width * (0.08 + index * 0.15) - root.nx * 26 * root.s * (1 + index * 0.2)
                    y: -root.height * 0.3
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
                rotation: 45
                color: "transparent"; border.color: root.red; border.width: 2 * root.s
                opacity: 0
            }
            ParallelAnimation {
                id: rAnim
                NumberAnimation { target: ring; property: "r"; from: 0; to: 240 * root.s; duration: 800; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 800 }
            }
        }

        // ── clock, top-left ──
        Item {
            id: clockBox
            x: 70 * root.s - root.nx * 18 * root.s
            y: 52 * root.s - root.ny * 12 * root.s - (1 - root.seg(0.2, 0.65)) * 40 * root.s
            width: clockCol.width; height: clockCol.height
            opacity: root.seg(0.2, 0.6)
            Behavior on x { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            Column {
                id: clockCol
                spacing: -6 * root.s
                Text {
                    text: Qt.formatTime(new Date(root.clockMs), "hh:mm")
                    color: root.cream; font.family: tungsten.name; font.pixelSize: 150 * root.s
                    style: Text.Outline; styleColor: "#550f1923"
                }
                Row {
                    spacing: 12 * root.s
                    Para {
                        width: 36 * root.s; height: 22 * root.s; fill: root.red; skew: 7 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Qt.formatDate(new Date(root.clockMs), "dddd, d MMMM").toUpperCase()
                        color: root.cream; font.family: dinCond.name; font.pixelSize: 22 * root.s; font.letterSpacing: 4 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // big faint wordmark that glides opposite to the pointer
        Text {
            text: "BLOQUEADO"
            color: root.cream; opacity: 0.06 * root.seg(0.5, 1)
            font.family: tungsten.name; font.pixelSize: 230 * root.s
            anchors.left: parent.left; anchors.bottom: parent.bottom
            anchors.leftMargin: 40 * root.s - root.nx * 40 * root.s
            anchors.bottomMargin: -20 * root.s + root.ny * 24 * root.s
            Behavior on anchors.leftMargin { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
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
            opacity: Math.max(0, root.charge - 0.6) / 0.4 * 0.35 * (1 - root.finale)
        }

        // ── login card ──
        Item {
            id: card
            width: 380 * root.s; height: 400 * root.s
            x: parent.width * 0.79 - width / 2 - root.nx * 14 * root.s
            y: parent.height * 0.5 - height / 2 + 20 * root.s - root.ny * 10 * root.s
            opacity: root.seg(0.3, 0.7)
            transform: Translate { x: (1 - root.seg(0.3, 0.8)) * 60 * root.s }
            Behavior on x { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            Cut { anchors.fill: parent; fill: "#d917222e"; stroke: "#33ece8e1"; strokeW: 1 * root.s }
            // red accent bar on the left edge
            Rectangle { x: 0; y: 0; width: 5 * root.s; height: parent.height - 14 * root.s; color: root.red }

            // diamond emblem with the V inside
            Item {
                id: avatar
                width: 112 * root.s; height: width
                anchors.top: parent.top; anchors.topMargin: 38 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78 + halo.v * 44 * root.s; height: width; rotation: 45
                    color: "transparent"; border.color: root.red; border.width: 2 * root.s
                    opacity: 0.6 * (1 - halo.v)
                }
                NumberAnimation { target: halo; property: "v"; from: 0; to: 1; duration: 2400; loops: Animation.Infinite; running: true; easing.type: Easing.OutQuad }
                QtObject { id: halo; property real v: 0 }
                Rectangle {
                    anchors.centerIn: parent; width: parent.width * 0.78; height: width; rotation: 45
                    color: root.navy; border.color: root.cream; border.width: 2 * root.s
                }
                Image {
                    anchors.centerIn: parent; width: parent.width * 0.52; height: width
                    source: "emblem.png"; fillMode: Image.PreserveAspectFit; smooth: true
                }
                scale: (avMouse.containsMouse ? 1.07 : 1.0) * (1 + 0.3 * root.charge)
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                MouseArea { id: avMouse; anchors.fill: parent; hoverEnabled: true; onClicked: ripple.fire(avatar.mapToItem(stage, width/2, height/2).x, avatar.mapToItem(stage, width/2, height/2).y) }
            }

            Text {
                id: roleText
                anchors.top: avatar.bottom; anchors.topMargin: 14 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                text: "AGENTE"
                color: root.red; font.family: dinCond.name; font.pixelSize: 15 * root.s; font.letterSpacing: 7 * root.s
            }
            Text {
                id: nameText
                anchors.top: roleText.bottom; anchors.topMargin: -2 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                text: (userHelper.currentItem && userHelper.currentItem.uName ? userHelper.currentItem.uName : "Agente").toUpperCase()
                color: root.cream; font.family: tungsten.name; font.pixelSize: 46 * root.s; font.letterSpacing: 3 * root.s
            }

            // password field: dark slab, red underline that fills on focus
            Item {
                id: field
                anchors.top: nameText.bottom; anchors.topMargin: 20 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 56 * root.s; height: 52 * root.s
                property real xShift: 0
                transform: Translate { x: field.xShift }
                Cut { anchors.fill: parent; cut: 10 * root.s; fill: "#cc0f1923"; stroke: passInput.activeFocus ? "#99ece8e1" : "#33ece8e1"; strokeW: 1 * root.s }
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.left: parent.left
                    height: 3 * root.s; color: root.red
                    width: passInput.activeFocus ? parent.width : parent.width * 0.18
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 18 * root.s
                    visible: !root.typing
                    text: "INTRODUCE TU CONTRASEÑA"; color: root.muted
                    font.family: dinCond.name; font.pixelSize: 16 * root.s; font.letterSpacing: 3 * root.s
                }
                // one red diamond per character
                Row {
                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 20 * root.s
                    spacing: 10 * root.s
                    Repeater {
                        model: Math.min(passInput.text.length, 20)
                        delegate: Rectangle {
                            width: 9 * root.s; height: width; rotation: 45; color: root.cream
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
                }
            }

            // unlock button
            Item {
                id: go
                anchors.top: field.bottom; anchors.topMargin: 16 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                width: field.width; height: 46 * root.s
                property bool hot: goMouse.containsMouse
                Cut { anchors.fill: parent; cut: 10 * root.s; fill: go.hot ? root.cream : root.red }
                Text {
                    anchors.centerIn: parent; text: root.busy ? "DESBLOQUEANDO" : "DESBLOQUEAR"
                    color: go.hot ? root.navy : root.cream
                    font.family: tungsten.name; font.pixelSize: 24 * root.s; font.letterSpacing: 4 * root.s
                }
                MouseArea { id: goMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.doLogin() }
            }

            Text {
                anchors.top: go.bottom; anchors.topMargin: 10 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.message
                color: root.message === "ACCESO DENEGADO" ? root.red : root.teal
                font.family: dinCond.name; font.pixelSize: 14 * root.s; font.letterSpacing: 4 * root.s
                opacity: root.message === "" ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "xShift"; to: 14 * root.s; duration: 50 }
                NumberAnimation { target: field; property: "xShift"; to: -14 * root.s; duration: 70 }
                NumberAnimation { target: field; property: "xShift"; to: 8 * root.s; duration: 60 }
                NumberAnimation { target: field; property: "xShift"; to: 0; duration: 50 }
            }
        }

        // ── power actions, bottom-left, as skewed tabs ──
        Row {
            anchors.left: parent.left; anchors.leftMargin: 66 * root.s
            anchors.bottom: parent.bottom; anchors.bottomMargin: 46 * root.s
            spacing: 8 * root.s
            opacity: root.seg(0.85, 1)
            visible: typeof sddm !== "undefined"
            Repeater {
                model: [ { t: "SUSPENDER", a: 0 }, { t: "REINICIAR", a: 1 }, { t: "APAGAR", a: 2 } ]
                delegate: Item {
                    id: act
                    width: lbl.implicitWidth + 44 * root.s; height: 34 * root.s
                    property bool hot: pm.containsMouse
                    Para { anchors.fill: parent; fill: act.hot ? root.red : "#8017222e"; stroke: act.hot ? root.red : "#40ece8e1"; strokeW: 1 * root.s
                           Behavior on fill { ColorAnimation { duration: 160 } } }
                    Text {
                        id: lbl
                        anchors.centerIn: parent
                        text: modelData.t
                        color: act.hot ? root.cream : "#c8ece8e1"
                        font.family: dinCond.name; font.pixelSize: 15 * root.s; font.letterSpacing: 3 * root.s
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

        // fingerprint hint (only the in-session lock defines these)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 50 * root.s
            visible: typeof sddm !== "undefined" && sddm.fingerprintHint === true && sddm.fingerprintReady === true
            text: "◆  COLOCA EL DEDO EN EL SENSOR  ◆"
            color: root.cream; opacity: 0.8
            font.family: dinCond.name; font.pixelSize: 14 * root.s; font.letterSpacing: 4 * root.s
        }
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
        busy = true; message = "VERIFICANDO"
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
    Timer { id: watchdog; interval: 8000; onTriggered: { root.busy = false; root.message = ""; passInput.text = ""; chargeBack.start(); passInput.forceActiveFocus() } }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        ignoreUnknownSignals: true
        function onSurfaceRevealed() { root.playIntro() }
        function onInformationMessage(m) { root.message = (m || "").toUpperCase(); passInput.forceActiveFocus() }
        function onErrorMessage(m) { root.message = (m || "").toUpperCase() }
        function onLoginSucceeded() { watchdog.stop(); root.message = "ACCESO CONCEDIDO"; root.playOutro() }
        function onLoginFailed() {
            watchdog.stop(); unlockSeq.stop(); root.busy = false; root.message = "ACCESO DENEGADO"
            chargeBack.start(); passInput.text = ""; passInput.forceActiveFocus(); shake.start()
        }
    }

    function playIntro() { outroAnim.stop(); introAnim.stop(); root.finale = 0; root.zoom = 1; root.intro = 0; introAnim.start() }
    function playOutro() { introAnim.stop(); outroAnim.start() }
    NumberAnimation { id: introAnim; target: root; property: "intro"; from: 0; to: 1; duration: 1800; easing.type: Easing.Linear }
    ParallelAnimation {
        id: outroAnim
        NumberAnimation { target: root; property: "intro"; to: 0; duration: 800; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "zoom"; to: 1.12; duration: 800; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "finale"; to: 1; duration: 500 }
    }

    Timer { interval: 300; running: true; onTriggered: passInput.forceActiveFocus() }
    Component.onCompleted: {
        if (typeof sessionModel !== "undefined") sessionIndex = preferredSessionIndex()
        if (!root.inSessionLock) playIntro()
    }
}
