pragma ComponentBehavior: Bound

import "items"
import QtQuick
import Quickshell
import Selestis.Config
import qs.components.controls
import qs.services

PathView {
    id: root

    required property SearchBar search
    required property var screenState
    required property var panels
    required property var content

    readonly property int itemWidth: Tokens.sizes.launcher.wallpaperWidth * 0.8 + Tokens.padding.medium * 2

    readonly property int numItems: {
        const screen = (QsWindow.window as QsWindow)?.screen;
        if (!screen)
            return 0;

        // Screen width - 4x outer rounding - 2x max side thickness (cause centered)
        const barMargins = Math.max(Config.border.thickness, panels.bar.implicitWidth);
        let outerMargins = 0;
        if (panels.popouts.hasCurrent && panels.popouts.currentCenter + panels.popouts.nonAnimHeight / 2 > screen.height - content.implicitHeight - Config.border.thickness * 2)
            outerMargins = panels.popouts.nonAnimWidth;
        if ((screenState.utilities || screenState.sidebar) && panels.utilities.implicitWidth > outerMargins)
            outerMargins = panels.utilities.implicitWidth;
        const maxWidth = screen.width - Config.border.rounding * 4 - (barMargins + outerMargins) * 2;

        if (maxWidth <= 0)
            return 0;

        const maxItemsOnScreen = Math.floor(maxWidth / itemWidth);
        const visible = Math.min(maxItemsOnScreen, Config.launcher.maxWallpapers, scriptModel.values.length);

        if (visible === 2)
            return 1;
        if (visible > 1 && visible % 2 === 0)
            return visible - 1;
        return visible;
    }

    // SEL-AW: separate static/animated sections matching the reference fork's picker UX.
    Row {
        id: tabBar

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.small
        height: 40
        z: 20

        Repeater {
            model: [
                { mode: "static", icon: "image", label: Tr.tr("Static") },
                { mode: "animated", icon: "movie", label: Tr.tr("Animated") }
            ]

            delegate: StyledRect {
                required property var modelData
                property bool selected: Wallpapers.wallpaperMode === modelData.mode

                implicitHeight: parent.height
                implicitWidth: labelItem.implicitWidth + Tokens.padding.large * 2
                radius: Tokens.rounding.full
                color: selected ? Colours.palette.m3primary : Colours.palette.m3surfaceContainer

                StateLayer {
                    radius: parent.radius
                    color: selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    onClicked: Wallpapers.setWallpaperMode(modelData.mode)
                }

                Row {
                    id: labelItem
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: modelData.icon
                        color: selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: modelData.label
                        color: selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        font: Tokens.font.label.large
                    }
                }
            }
        }

        StyledRect {
            visible: Wallpapers.wallpaperMode === "animated"
            implicitHeight: parent.height
            implicitWidth: height
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainer

            StateLayer {
                radius: parent.radius
                color: Colours.palette.m3onSurface
                onClicked: Wallpapers.refreshAnimatedThumbs()
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "refresh"
                color: Colours.palette.m3onSurface
                fontStyle: Tokens.font.icon.small
            }
        }
    }

    model: ScriptModel {
        id: scriptModel

        readonly property string search: root.search.text.split(" ").slice(1).join(" ")

        values: Wallpapers.query(search)
        onValuesChanged: root.currentIndex = search ? 0 : values.findIndex(w => w.path === Wallpapers.actualCurrent)
    }

    Component.onCompleted: currentIndex = Wallpapers.list.findIndex(w => w.path === Wallpapers.actualCurrent)
    Component.onDestruction: Wallpapers.stopPreview()

    onCurrentItemChanged: {
        if (currentItem)
            Wallpapers.preview((currentItem as WallpaperItem).modelData.path);
    }

    implicitWidth: Math.min(numItems, count) * itemWidth
    y: tabBar.height
    height: Math.max(0, parent.height - tabBar.height)
    pathItemCount: numItems
    cacheItemCount: 4

    snapMode: PathView.SnapToItem
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange

    delegate: WallpaperItem {
        screenState: root.screenState
    }

    path: Path {
        startY: root.height / 2

        PathAttribute {
            name: "z"
            value: 0
        }
        PathLine {
            x: root.width / 2
            relativeY: 0
        }
        PathAttribute {
            name: "z"
            value: 1
        }
        PathLine {
            x: root.width
            relativeY: 0
        }
    }

    CustomMouseArea {
        function onWheel(event: WheelEvent): void {
            if (event.angleDelta.y > 0)
                root.decrementCurrentIndex();
            else if (event.angleDelta.y < 0)
                root.incrementCurrentIndex();
        }

        anchors.fill: parent
    }
}
