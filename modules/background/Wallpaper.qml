pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services

Item {
    id: root

    property string source: Wallpapers.current
    property CachingImage current
    property bool completed
    readonly property bool sourceIsVideo: Wallpapers.isVideo(source)
    readonly property bool sourceIsGif: Wallpapers.isAnimated(source) && !root.sourceIsVideo
    readonly property bool sourceIsAnimated: Wallpapers.isAnimated(source)
    readonly property url videoSource: sourceIsVideo ? Wallpapers.toFileUrl(source) : ""

    onSourceChanged: {
        if (sourceIsAnimated) {
            current = null;
            if (current === one)
                two.update();
            else
                one.update();
        } else if (!source) {
            current = null;
        } else if (current === one) {
            two.update();
        } else {
            one.update();
        }
    }

    Component.onCompleted: {
        if (sourceIsAnimated) {
            completed = true;
        } else if (source) {
            Qt.callLater(() => {
                one.update();
                completed = true;
            });
        }
    }

    Connections {
        target: WallpaperPauser
        ignoreUnknownSignals: true

        function onPausedChanged(): void {
            if (!root.sourceIsVideo)
                return;

            video.autoStart = !WallpaperPauser.paused;
            if (WallpaperPauser.paused)
                video.pause();
            else
                video.play();
        }
    }

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(5).build()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: Tr.tr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Bold).build()
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.extraLargeIncreased
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: Tr.tr("Select a wallpaper")
                            filterLabel: Tr.tr("Image or video files")
                            filters: Images.validImageExtensions.concat(["*.mp4", "*.webm", "*.mkv"])
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            onClicked: dialog.open()
                        }

                        StyledText {
                            id: selectWallText
                            anchors.centerIn: parent
                            text: Tr.tr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.body.large
                        }
                    }
                }
            }
        }
    }

    Img {
        id: one
    }

    Img {
        id: two
    }

    VideoWallpaper {
        id: video
        anchors.fill: parent
        visible: root.sourceIsVideo
        videoSource: root.videoSource
        autoStart: !WallpaperPauser.paused
    }

    AnimatedImage {
        id: gif
        anchors.fill: parent
        visible: root.sourceIsGif
        source: root.sourceIsGif ? root.source : ""
        fillMode: Image.PreserveAspectCrop
        paused: WallpaperPauser.paused
    }

    component Img: CachingImage {
        id: img

        function update(): void {
            if (root.sourceIsAnimated)
                return;

            const newPath = root.source;
            if (path === newPath) {
                root.current = this;
                return;
            }

            path = newPath;
        }

        anchors.fill: parent
        visible: !root.sourceIsAnimated
        opacity: 0

        onStatusChanged: {
            if (status === Image.Ready)
                root.current = this;
        }

        states: State {
            name: "visible"
            when: root.current === img

            PropertyChanges {
                img.opacity: 1
            }
        }

        transitions: Transition {
            Anim {
                target: img
                properties: "opacity"
            }
        }

        Timer {
            running: root.current !== img && img.status === Image.Ready
            interval: 300
            onTriggered: img.destroy()
        }
    }
}
