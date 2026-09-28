import QtQuick
import QtMultimedia

// Animated wallpaper renderer adapted from AdiAmbassador's Caelestia-AW shell fork.

Item {
    id: root

    // Kept intentionally self-contained: Wallpaper.qml only has to supply a media URL.
    property url videoSource
    property bool autoStart: true

    property alias playbackState: root._activePlaybackState
    property alias mediaStatus: root._activeMediaStatus
    property alias error: root._activeError
    property alias errorString: root._activeErrorString

    property bool _usePlayerA: true
    property int _activePlaybackState: _usePlayerA ? playerA.playbackState : playerB.playbackState
    property int _activeMediaStatus: _usePlayerA ? playerA.mediaStatus : playerB.mediaStatus
    property int _activeError: _usePlayerA ? playerA.error : playerB.error
    property string _activeErrorString: _usePlayerA ? playerA.errorString : playerB.errorString
    property bool _swapping: false
    property bool forceFrameRenderA: false
    property bool forceFrameRenderB: false
    property bool _pendingSwapToA: true

    function play(): void {
        const active = _swapping ? (_pendingSwapToA ? playerA : playerB) : (_usePlayerA ? playerA : playerB);
        if (videoSource != "" && videoSource.toString() !== "")
            active.play();
    }

    function pause(): void {
        const active = _swapping ? (_pendingSwapToA ? playerA : playerB) : (_usePlayerA ? playerA : playerB);
        active.pause();
    }

    function stop(): void {
        // Clearing source handles cleanup; this method keeps the component easy to control.
    }

    anchors.fill: parent

    VideoOutput {
        id: outputA
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: root._usePlayerA
    }

    AudioOutput {
        id: mutedOutputA
        muted: true
        volume: 0
    }

    MediaPlayer {
        id: playerA
        videoOutput: outputA
        audioOutput: mutedOutputA
        loops: MediaPlayer.Infinite
        autoPlay: false

        onErrorOccurred: (errorCode, errorString) => {
            if (errorCode !== MediaPlayer.NoError)
                console.warn("VideoPlayer A: error:", errorString);
        }

        onPositionChanged: {
            if (root.forceFrameRenderA && position > 0) {
                root.forceFrameRenderA = false;
                playerA.pause();
            }
        }

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.InvalidMedia)
                console.warn("VideoPlayer A: invalid media:", playerA.source, playerA.errorString);

            if (!root._usePlayerA && !root._swapping && mediaStatus === MediaPlayer.LoadedMedia)
                root._performSwap(true);

            if (root._usePlayerA && mediaStatus === MediaPlayer.LoadedMedia && playerB.source == "" && !root._swapping) {
                if (root.autoStart) {
                    playerA.play();
                } else {
                    root.forceFrameRenderA = true;
                    playerA.play();
                }
            }
        }
    }

    VideoOutput {
        id: outputB
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: !root._usePlayerA
    }

    AudioOutput {
        id: mutedOutputB
        muted: true
        volume: 0
    }

    MediaPlayer {
        id: playerB
        videoOutput: outputB
        audioOutput: mutedOutputB
        loops: MediaPlayer.Infinite
        autoPlay: false

        onErrorOccurred: (errorCode, errorString) => {
            if (errorCode !== MediaPlayer.NoError)
                console.warn("VideoPlayer B: error:", errorString);
        }

        onPositionChanged: {
            if (root.forceFrameRenderB && position > 0) {
                root.forceFrameRenderB = false;
                playerB.pause();
            }
        }

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.InvalidMedia)
                console.warn("VideoPlayer B: invalid media:", playerB.source, playerB.errorString);

            if (root._usePlayerA && !root._swapping && mediaStatus === MediaPlayer.LoadedMedia)
                root._performSwap(false);
        }
    }

    // Defer playback slightly so the launcher gets a frame to render before multimedia starts.
    Timer {
        id: deferredPlayTimer
        interval: 100
        repeat: false
        onTriggered: root._executeDeferredSwap()
    }

    function _performSwap(swapToA: bool): void {
        _swapping = true;
        _pendingSwapToA = swapToA;

        const oldPlayer = swapToA ? playerB : playerA;
        oldPlayer.pause();
        deferredPlayTimer.restart();
    }

    function _executeDeferredSwap(): void {
        const swapToA = _pendingSwapToA;
        const newPlayer = swapToA ? playerA : playerB;
        const oldPlayer = swapToA ? playerB : playerA;

        if (root.autoStart) {
            newPlayer.play();
        } else {
            if (swapToA)
                root.forceFrameRenderA = true;
            else
                root.forceFrameRenderB = true;
            newPlayer.play();
        }

        root._usePlayerA = swapToA;

        Qt.callLater(() => {
            oldPlayer.source = "";
            root._swapping = false;
        });
    }

    onVideoSourceChanged: {
        if (videoSource == "" || videoSource.toString() === "") {
            playerA.source = "";
            playerB.source = "";
            return;
        }

        if (playerA.source == "" && playerB.source == "") {
            playerA.source = videoSource;
            _usePlayerA = true;
            return;
        }

        const inactivePlayer = _usePlayerA ? playerB : playerA;
        inactivePlayer.source = videoSource;
    }

    Component.onCompleted: {
        if (videoSource != "" && videoSource.toString() !== "") {
            playerA.source = videoSource;
            _usePlayerA = true;
        }
    }
}
