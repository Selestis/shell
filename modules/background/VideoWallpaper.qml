import QtQuick
import QtMultimedia

Item {
    id: root

    property url videoSource
    property bool autoStart: true

    // SEL-AW: dual MediaPlayers allow a new source to load on the inactive
    // decoder before switching the visible output, avoiding visible stalls.
    property bool _usePlayerA: true
    property bool _swapping: false
    property bool _pendingSwapToA: true
    property bool forceFrameRenderA: false
    property bool forceFrameRenderB: false

    readonly property int playbackState: _usePlayerA ? playerA.playbackState : playerB.playbackState
    readonly property int mediaStatus: _usePlayerA ? playerA.mediaStatus : playerB.mediaStatus
    readonly property int error: _usePlayerA ? playerA.error : playerB.error
    readonly property string errorString: _usePlayerA ? playerA.errorString : playerB.errorString
    readonly property bool playing: playbackState === MediaPlayer.PlayingState

    anchors.fill: parent

    function play(): void {
        const active = _swapping ? (_pendingSwapToA ? playerA : playerB) : (_usePlayerA ? playerA : playerB);
        if (videoSource !== "" && videoSource.toString() !== "")
            active.play();
    }

    function pause(): void {
        const active = _swapping ? (_pendingSwapToA ? playerA : playerB) : (_usePlayerA ? playerA : playerB);
        active.pause();
    }

    function stop(): void {
        // Clearing source handles decoder cleanup; retained for Wallpaper.qml API parity.
    }

    VideoOutput {
        id: outputA
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: root._usePlayerA
    }

    MediaPlayer {
        id: playerA
        videoOutput: outputA
        audioOutput: null
        loops: MediaPlayer.Infinite
        autoPlay: false

        onErrorOccurred: (errorCode, errorString) => {
            if (errorCode !== MediaPlayer.NoError)
                console.warn("Selestis VideoPlayer A:", errorString);
        }
        onPositionChanged: {
            if (root.forceFrameRenderA && position > 0) {
                root.forceFrameRenderA = false;
                pause();
            }
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.InvalidMedia)
                console.warn("Selestis VideoPlayer A: invalid media:", source, errorString);
            if (!root._usePlayerA && !root._swapping && mediaStatus === MediaPlayer.LoadedMedia)
                root._performSwap(true);
            if (root._usePlayerA && mediaStatus === MediaPlayer.LoadedMedia && playerB.source == "" && !root._swapping) {
                if (root.autoStart)
                    play();
                else {
                    root.forceFrameRenderA = true;
                    play();
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

    MediaPlayer {
        id: playerB
        videoOutput: outputB
        audioOutput: null
        loops: MediaPlayer.Infinite
        autoPlay: false

        onErrorOccurred: (errorCode, errorString) => {
            if (errorCode !== MediaPlayer.NoError)
                console.warn("Selestis VideoPlayer B:", errorString);
        }
        onPositionChanged: {
            if (root.forceFrameRenderB && position > 0) {
                root.forceFrameRenderB = false;
                pause();
            }
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.InvalidMedia)
                console.warn("Selestis VideoPlayer B: invalid media:", source, errorString);
            if (root._usePlayerA && !root._swapping && mediaStatus === MediaPlayer.LoadedMedia)
                root._performSwap(false);
        }
    }

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

        if (root.autoStart)
            newPlayer.play();
        else {
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
        if (videoSource === "" || videoSource.toString() === "") {
            playerA.source = "";
            playerB.source = "";
            return;
        }
        if (playerA.source === "" && playerB.source === "") {
            playerA.source = videoSource;
            _usePlayerA = true;
            return;
        }
        const inactivePlayer = _usePlayerA ? playerB : playerA;
        inactivePlayer.source = videoSource;
    }

    Component.onCompleted: {
        if (videoSource !== "" && videoSource.toString() !== "") {
            playerA.source = videoSource;
            _usePlayerA = true;
        }
    }
}
