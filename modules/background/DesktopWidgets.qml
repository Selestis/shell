pragma ComponentBehavior: Bound

import QtQuick
import Selestis.Config

Item {
    id: root

    // SEL-WIDGETS: keep the widget host separate so more end-4-inspired desktop
    // widgets can be added without coupling them to Background.qml.
    anchors.fill: parent

    WeatherWidget {
        visible: Config.background.widgets.weather.enabled
    }
}
