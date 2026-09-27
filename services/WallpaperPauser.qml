pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

Singleton {
    id: root

    // SEL-AW: pause policy is persisted in Quickshell settings so animated
    // wallpapers can be kept responsive without wasting decode/GPU time.
    property bool pauseOnBattery: false
    property bool pauseOnWindowOverlap: true
    property bool paused: false
    property string pauseReason: "None"

    function recalculate(): void {
        let nextPaused = false;
        let reason = "None";

        if (pauseOnBattery && UPower.onBattery) {
            nextPaused = true;
            reason = "Battery";
        } else if (pauseOnWindowOverlap) {
            const monitor = Hyprland.focusedMonitor;
            const ws = monitor?.activeWorkspace ?? Hyprland.focusedWorkspace;
            const toplevels = ws?.toplevels?.values ?? [];

            if (toplevels.length >= 2) {
                nextPaused = true;
                reason = "2+ windows";
            } else if (monitor) {
                const screen = Quickshell.screens.find(s => s.name === monitor.name);
                const screenArea = screen ? screen.width * screen.height : 0;
                const threshold = screenArea * 0.7;
                for (const t of toplevels) {
                    const size = t.lastIpcObject?.size;
                    if (size && size.length >= 2 && size[0] * size[1] >= threshold) {
                        nextPaused = true;
                        reason = "70% overlap";
                        break;
                    }
                }
            }
        }

        paused = nextPaused;
        pauseReason = reason;
    }

    Settings {
        category: "WallpaperPauser"
        property alias pauseOnBattery: root.pauseOnBattery
        property alias pauseOnWindowOverlap: root.pauseOnWindowOverlap
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { recalcTimer.restart(); }
        function onFocusedMonitorChanged() { recalcTimer.restart(); }
        function onRawEvent(event) {
            const n = event.name;
            if (n.startsWith("workspace") || n.startsWith("activewindow") || ["fullscreen", "changefloatingmode", "minimize", "movewindow", "openwindow", "closewindow", "moveworkspace", "focusedmon"].includes(n))
                recalcTimer.restart();
        }
    }

    Connections {
        target: UPower
        function onOnBatteryChanged() { recalcTimer.restart(); }
    }

    Timer {
        id: recalcTimer
        interval: 50
        onTriggered: root.recalculate()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        property int attempts: 0
        onTriggered: {
            root.recalculate();
            attempts++;
            if (attempts >= 5)
                running = false;
        }
    }

    onPauseOnBatteryChanged: recalculate()
    onPauseOnWindowOverlapChanged: recalculate()
}
