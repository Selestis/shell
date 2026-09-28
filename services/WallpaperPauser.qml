pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.services

// Pause policy adapted from AdiAmbassador's Caelestia-AW design.

Singleton {
    id: root

    // Animated wallpapers can be paused without changing the selected wallpaper.
    // Keep these switches local so future policy changes do not require touching the renderer.
    property bool pauseOnBattery: true
    property bool pauseOnFullscreen: true

    readonly property bool fullscreenActive: {
        const workspace = Hypr.focusedWorkspace;
        if (!workspace || !workspace.toplevels)
            return false;

        return workspace.toplevels.values.some(toplevel => toplevel.lastIpcObject?.fullscreen > 0);
    }

    readonly property bool paused: (pauseOnBattery && UPower.onBattery) || (pauseOnFullscreen && fullscreenActive)
}
