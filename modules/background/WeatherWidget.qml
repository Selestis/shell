pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Selestis.Config
import Selestis.I18n
import qs.components
import qs.services

Item {
    id: root

    // SEL-WIDGETS: end-4-inspired weather card using Selestis' existing Weather service.
    property real widgetScale: Config.background.widgets.weather.scale
    property bool blurEnabled: Config.background.widgets.weather.blur && !GameMode.enabled
    property real dragStartX: 0
    property real dragStartY: 0

    x: Config.background.widgets.weather.x
    y: Config.background.widgets.weather.y
    scale: widgetScale
    width: 360
    height: 168
    visible: Config.background.widgets.weather.enabled

    Behavior on x { Anim {} }
    Behavior on y { Anim {} }
    Behavior on scale { Anim {} }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            root.x = dragStartX + mouse.x - pressX;
            root.y = dragStartY + mouse.y - pressY;
            Config.background.widgets.weather.x = root.x;
            Config.background.widgets.weather.y = root.y;
        }
        property real pressX: 0
        property real pressY: 0
        onPressed: mouse => {
            pressX = mouse.x;
            pressY = mouse.y;
            root.dragStartX = root.x;
            root.dragStartY = root.y;
        }
    }

    StyledRect {
        id: card
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.82)

        layer.enabled: root.blurEnabled
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.6
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    RowLayout {
        anchors.fill: card
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            StyledText {
                text: Weather.city || Tr.tr("Weather")
                font: Tokens.font.title.medium
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: Weather.icon
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(2.2).build()
                }

                StyledText {
                    text: Weather.temp
                    font: Tokens.font.headline.large.weight(Font.Bold).build()
                    color: Colours.palette.m3primary
                }
            }

            StyledText {
                text: Weather.description
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.large
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: Tokens.spacing.large

                StyledText {
                    text: `${Weather.humidity}% humidity`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }

                StyledText {
                    text: `${Math.round(Weather.windSpeed)} km/h wind`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }
        }
    }
}
