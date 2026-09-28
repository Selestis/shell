pragma ComponentBehavior: Bound

import "items"
import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

PathView {
    id: root

    required property SearchBar search
    required property var screenState
    required property var panels
    required property var content

    // Stage 1 additive feature: the existing wallpaper carousel is retained, with
    // explicit filters for all/static/animated wallpapers layered on top.
    property string mode: "all"

    readonly property int itemWidth: Tokens.sizes.launcher.wallpaperWidth * 0.8 + Tokens.padding.medium * 2

    readonly property int numItems: {
        const screen = (QsWindow.window as QsWindow)?.screen;
        if (!screen)
            return 0;

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

    model: ScriptModel {
        id: scriptModel

        readonly property string searchText: root.search.text.split(" ").slice(1).join(" ")

        values: {
            const staticValues = Wallpapers.queryStatic(searchText);
            const animatedValues = Wallpapers.queryAnimated(searchText);
            if (root.mode === "static")
                return staticValues;
            if (root.mode === "animated")
                return animatedValues;
            return staticValues.concat(animatedValues);
        }

        onValuesChanged: {
            const index = values.findIndex(w => w.path === Wallpapers.actualCurrent);
            root.currentIndex = searchText ? 0 : Math.max(0, index);
        }
    }

    Component.onCompleted: {
        const index = scriptModel.values.findIndex(w => w.path === Wallpapers.actualCurrent);
        currentIndex = Math.max(0, index);
    }

    Component.onDestruction: Wallpapers.stopPreview()

    onCurrentIndexChanged: {
        const entry = scriptModel.values[currentIndex];
        if (entry)
            Wallpapers.preview(entry.path);
    }

    implicitWidth: Math.min(numItems, count) * itemWidth
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

    // The underlying wheel interaction remains unchanged; the toolbar is layered above it.
    CustomMouseArea {
        function onWheel(event: WheelEvent): void {
            if (event.angleDelta.y > 0)
                root.decrementCurrentIndex();
            else if (event.angleDelta.y < 0)
                root.incrementCurrentIndex();
        }

        anchors.fill: parent
    }

    StyledRect {
        id: wallpaperFilter
        z: 100
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }
        implicitWidth: filterRow.implicitWidth + Tokens.padding.small * 2
        implicitHeight: filterRow.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainer

        Row {
            id: filterRow
            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            StyledRect {
                id: allButton
                implicitWidth: allText.implicitWidth + Tokens.padding.large
                implicitHeight: allText.implicitHeight + Tokens.padding.small
                radius: Tokens.rounding.full
                color: root.mode === "all" ? Colours.tPalette.m3primary : "transparent"

                StateLayer {
                    radius: parent.radius
                    color: root.mode === "all" ? Colours.tPalette.m3onPrimary : Colours.tPalette.m3onSurface
                    onClicked: root.mode = "all"
                }

                StyledText {
                    id: allText
                    anchors.centerIn: parent
                    text: Tr.tr("All")
                    color: root.mode === "all" ? Colours.tPalette.m3onPrimary : Colours.tPalette.m3onSurface
                    font: Tokens.font.label.medium
                }
            }

            StyledRect {
                id: staticButton
                implicitWidth: staticText.implicitWidth + Tokens.padding.large
                implicitHeight: staticText.implicitHeight + Tokens.padding.small
                radius: Tokens.rounding.full
                color: root.mode === "static" ? Colours.tPalette.m3primary : "transparent"

                StateLayer {
                    radius: parent.radius
                    color: root.mode === "static" ? Colours.tPalette.m3onPrimary : Colours.tPalette.m3onSurface
                    onClicked: root.mode = "static"
                }

                StyledText {
                    id: staticText
                    anchors.centerIn: parent
                    text: Tr.tr("Static")
                    color: root.mode === "static" ? Colours.tPalette.m3onPrimary : Colours.tPalette.m3onSurface
                    font: Tokens.font.label.medium
                }
            }

            StyledRect {
                id: animatedButton
                implicitWidth: animatedText.implicitWidth + Tokens.padding.large
                implicitHeight: animatedText.implicitHeight + Tokens.padding.small
                radius: Tokens.rounding.full
                color: root.mode === "animated" ? Colours.tPalette.m3primary : "transparent"

                StateLayer {
                    radius: parent.radius
                    color: root.mode === "animated" ? Colours.tPalette.m3onPrimary : Colours.tPalette.m3onSurface
                    onClicked: root.mode = "animated"
                }

                StyledText {
                    id: animatedText
                    anchors.centerIn: parent
                    text: Tr.tr("Animated")
                    color: root.mode === "animated" ? Colours.tPalette.m3onPrimary : Colours.tPalette.m3onSurface
                    font: Tokens.font.label.medium
                }
            }

            StyledRect {
                id: refreshButton
                visible: root.mode === "animated"
                implicitWidth: refreshIcon.implicitWidth + Tokens.padding.large
                implicitHeight: refreshIcon.implicitHeight + Tokens.padding.small
                radius: Tokens.rounding.full
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    color: Colours.tPalette.m3onSurface
                    onClicked: Wallpapers.refreshAnimatedThumbs()
                }

                MaterialIcon {
                    id: refreshIcon
                    anchors.centerIn: parent
                    text: "refresh"
                    color: Colours.tPalette.m3onSurface
                    fontStyle: Tokens.font.icon.builders.medium.build()
                }
            }
        }
    }
}
