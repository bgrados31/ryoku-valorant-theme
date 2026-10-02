// Looping, muted video backdrop for the valorant/agent lockscreen.
//
// Main.qml loads this file through a Loader and never imports QtMultimedia itself:
// if the multimedia stack is missing or broken only this Loader fails and the poster
// (wallpaper.png, frame 0 of background.mp4) stays on screen.
//
// Only MediaPlayer + VideoOutput are used. The in-session lock puts a QtMultimedia
// shim first on the import path that exports exactly those two (plus a Qt5 `Video`
// wrapper we avoid); AudioOutput does not resolve reliably there, and the clip has
// no audio track anyway.
import QtQuick
import QtMultimedia

Item {
    id: vb
    property url source
    property bool playing: true          // Main.qml: videoOn && !idle
    property bool failed: false
    property string why: ""

    // VideoOutput draws nothing under the software scenegraph (weston pixman, no GPU).
    // GraphicsInfo.Unknown (no window yet) counts as "try".
    readonly property bool softwareRenderer: GraphicsInfo.api === GraphicsInfo.Software
    readonly property bool decoding: player.playbackState === MediaPlayer.PlayingState
                                     && player.hasVideo
                                     && (player.mediaStatus === MediaPlayer.BufferedMedia
                                         || player.mediaStatus === MediaPlayer.BufferingMedia
                                         || player.mediaStatus === MediaPlayer.EndOfMedia)
    // frames have reached the screen at least once
    property bool everShown: false
    onDecodingChanged: if (decoding && !softwareRenderer) frameGate.restart()
    Timer { id: frameGate; interval: 120; onTriggered: if (vb.decoding) vb.everShown = true }

    // true while frames are (or, when paused, were last) on screen
    readonly property bool showing: !failed && !softwareRenderer && everShown
                                    && player.playbackState !== MediaPlayer.StoppedState

    opacity: showing ? 1 : 0
    visible: opacity > 0.001
    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    MediaPlayer {
        id: player
        source: vb.source
        videoOutput: out
        loops: MediaPlayer.Infinite
        onErrorOccurred: (error, errorString) => { vb.failed = true; vb.why = errorString }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.InvalidMedia) { vb.failed = true; vb.why = "invalid media" }
            else if (mediaStatus === MediaPlayer.LoadedMedia) vb.sync()
        }
        // play() must be triggered here, not on vb: vb's change fires before this binding updates
        onSourceChanged: vb.sync()
    }

    function sync() {
        if (vb.failed) return
        if (vb.playing && !vb.softwareRenderer && player.source.toString() !== "") player.play()
        else if (player.playbackState === MediaPlayer.PlayingState) player.pause()
    }
    onPlayingChanged: sync()
    onSoftwareRendererChanged: sync()
    Component.onCompleted: sync()
}
