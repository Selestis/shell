pragma ComponentBehavior: Bound

import QtQuick
import Selestis.Config
import qs.components
import qs.components.images
import qs.services

Item {
    id: root

    property string source: Wallpapers.current
    property Item current
    property bool completed

    // SEL-AW: two independent layers keep the current frame visible while the next
    // image/video is prepared. This mirrors the reference fork's non-blocking swap.
    property Item _activeLayer
    property string settledSource: ""

    function _cleanPath(path: string): string {
        let clean = String(path || "").split(/[?#]/)[0];
        if (clean.indexOf("file://") === 0)
            clean = clean.substring(7);
        return clean;
    }

    function _setLayer(layer: Item, path: string): void {
        layer.path = _cleanPath(path);
        layer.visible = true;
        layer.z = (_activeLayer === layer) ? 1 : 0;
        layer.opacity = 0;
    }

    function _activateLayer(layer: Item): void {
        const old = _activeLayer;
        _activeLayer = layer;
        layer.z = 1;
        layer.targetOpacity = 1;
        if (old && old !== layer) {
            old.targetOpacity = 0;
            old.z = 0;
        }
        current = layer;
    }

    function _applySource(): void {
        const clean = _cleanPath(source);
        if (clean === settledSource && _activeLayer?.path === clean)
            return;
        settledSource = clean;

        if (!clean) {
            layerA.path = "";
            layerB.path = "";
            _activeLayer = null;
            current = null;
            return;
        }

        const next = _activeLayer === layerA ? layerB : layerA;
        _setLayer(next, clean);
        _activateLayer(next);
    }

    onSourceChanged: Qt.callLater(_applySource)

    Component.onCompleted: {
        completed = true;
        Qt.callLater(_applySource);
    }

    Loader {
        anchors.fill: parent
        asynchronous: true
        active: root.completed && !root.source
        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer
        }
    }

    component WallpaperLayer: Item {
        id: layer

        property string path: ""
        property real targetOpacity: 0
        property bool isVideo: Wallpapers.isVideo(path)
        property bool renderActive: targetOpacity > 0

        anchors.fill: parent
        opacity: 0
        visible: false

        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.InOutQuad
            }
        }

        // SEL-AW: video files use cached thumbnails until QtMultimedia has a ready
        // frame; static images keep the existing CachingImage path.
        CachingImage {
            id: preview
            anchors.fill: parent
            asynchronous: true
            path: layer.isVideo ? Wallpapers.getWallpaperThumb(layer.path, Wallpapers.cacheBuster) : layer.path
            visible: !layer.isVideo || !(videoLoader.item && videoLoader.item["playing"])

            onStatusChanged: {
                if (layer.targetOpacity > 0 && status === Image.Ready && !layer.isVideo)
                    layer.opacity = layer.targetOpacity;
            }
        }

        Loader {
            id: videoLoader
            anchors.fill: parent
            asynchronous: true
            active: layer.isVideo && layer.path !== "" && layer.renderActive
            source: "VideoWallpaper.qml"

            onLoaded: {
                if (item) {
                    item.videoSource = `file://${root._cleanPath(layer.path)}`;
                    item.autoStart = !WallpaperPauser.paused;
                }
            }

            Connections {
                target: WallpaperPauser
                ignoreUnknownSignals: true

                function onPausedChanged(): void {
                    if (!videoLoader.item || !layer.isVideo)
                        return;
                    if (WallpaperPauser.paused) {
                        videoLoader.item.pause();
                    } else if (layer.renderActive) {
                        videoLoader.item.play();
                    }
                }
            }

            Connections {
                target: videoLoader.item
                ignoreUnknownSignals: true

                function onPlayingChanged(): void {
                    if (videoLoader.item && videoLoader.item.playing && layer.targetOpacity > 0)
                        layer.opacity = layer.targetOpacity;
                }
            }
        }

        onTargetOpacityChanged: {
            if (!targetOpacity) {
                opacity = 0;
                visible = false;
                if (videoLoader.item)
                    videoLoader.item.pause();
                return;
            }
            visible = true;
            if (!isVideo && preview.status === Image.Ready)
                opacity = targetOpacity;
            else if (isVideo && videoLoader.item && videoLoader.item.playing)
                opacity = targetOpacity;
        }

        onPathChanged: {
            opacity = 0;
            visible = !!path;
        }
    }

    WallpaperLayer { id: layerA }
    WallpaperLayer { id: layerB }
}
