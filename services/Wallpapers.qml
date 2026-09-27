pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Selestis.Config
import Selestis.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    property bool enableAnimation: true
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear
    readonly property list<string> validVideoExtensions: ["mp4", "webm", "mkv"]
    property string wallpaperMode: "static"
    property string cacheBuster: ""
    property string lastStatic: ""
    property string lastAnimated: ""
    property var _hashCache: ({})

    function djb2Hash(value: string): string {
        if (!value)
            return "0";
        if (_hashCache[value] !== undefined)
            return _hashCache[value];
        let hash = 5381;
        for (let i = 0; i < value.length; ++i) {
            hash = ((hash << 5) + hash) + value.charCodeAt(i);
            hash |= 0;
        }
        const result = (hash >>> 0).toString(10);
        _hashCache[value] = result;
        return result;
    }

    function cleanPath(path: string): string {
        let clean = String(path || "").split(/[?#]/)[0];
        if (clean.startsWith("file://"))
            clean = clean.slice(7);
        return clean;
    }

    function isVideo(path: string): bool {
        const clean = cleanPath(path).toLowerCase();
        const dot = clean.lastIndexOf(".");
        return dot >= 0 && validVideoExtensions.includes(clean.slice(dot + 1));
    }

    function getWallpaperThumb(path: string, buster = cacheBuster): string {
        const clean = cleanPath(path);
        if (!clean)
            return "";
        const suffix = buster ? `?v=${buster}` : "";
        return `file://${Paths.cache}/videothumbs/${djb2Hash(clean)}.jpg${suffix}`;
    }

    function setWallpaperMode(mode: string): void {
        if (mode !== "static" && mode !== "animated")
            return;
        wallpaperMode = mode;
        const target = mode === "animated" ? lastAnimated : lastStatic;
        if (target) {
            actualCurrent = target;
            Quickshell.execDetached(["selestis", "wallpaper", "-f", target, ...smartArg]);
        }
    }

    function setRandom(): void {
        Quickshell.execDetached(["selestis", "wallpaper", "-r", ...smartArg]);
    }

    function setWallpaper(path: string): void {
        const clean = cleanPath(path);
        if (!clean)
            return;
        actualCurrent = clean;
        if (isVideo(clean)) {
            lastAnimated = clean;
            lastAnimatedFile.setText(clean);
            wallpaperMode = "animated";
        } else {
            lastStatic = clean;
            lastStaticFile.setText(clean);
            wallpaperMode = "static";
        }
        stopPreview();
        Quickshell.execDetached(["selestis", "wallpaper", "-f", clean, ...smartArg]);
    }

    function preview(path: string): void {
        const clean = cleanPath(path);
        if (!clean)
            return;
        previewPath = clean;
        showPreview = true;
        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.startFor(clean);
    }

    function stopPreview(): void {
        showPreview = false;
        if (getPreviewColoursProc.running)
            getPreviewColoursProc.running = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear) {
            Colours.showPreview = false;
            pendingPreviewClear = false;
        }
    }

    FileView {
        id: enableAnimationFile
        path: `${Paths.state}/wallpaper/enable_animation.txt`
        printErrors: false
        onLoaded: {
            const val = text().trim();
            if (val === "0") root.enableAnimation = false;
            else if (val === "1") root.enableAnimation = true;
        }
    }

    FileView {
        id: lastStaticFile
        path: `${Paths.state}/wallpaper/last_static.txt`
        printErrors: false
        onLoaded: {
            const value = text().trim();
            if (value) root.lastStatic = value;
        }
    }

    FileView {
        id: lastAnimatedFile
        path: `${Paths.state}/wallpaper/last_animated.txt`
        printErrors: false
        onLoaded: {
            const value = text().trim();
            if (value) root.lastAnimated = value;
        }
    }

    onEnableAnimationChanged: enableAnimationFile.setText(enableAnimation ? "1" : "0")

    list: wallpaperMode === "animated" ? animatedWallpapers.entries : staticWallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({ forward: false })

    IpcHandler {
        function get(): string { return root.actualCurrent; }
        function set(path: string): void { root.setWallpaper(path); }
        function list(): string { return root.list.map(w => w.path).join("\n"); }
        target: "wallpaper"
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Quickshell.execDetached(["selestis", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            }
            root.actualCurrent = root.cleanPath(wall);
            root.wallpaperMode = root.isVideo(root.actualCurrent) ? "animated" : "static";
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.wallpaperMode = "static";
            root.previewColourLock = false;
            Quickshell.execDetached(["selestis", "wallpaper", "-f", root.fallback, ...root.smartArg]);
        }
    }


    FileSystemModel {
        id: staticWallpapers
        watchChanges: true
        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Files
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.tif", "*.tiff", "*.svg", "*.gif"]
    }

    FileSystemModel {
        id: animatedWallpapers
        watchChanges: true
        recursive: true
        path: `${Paths.wallsdir}/Animated`
        filter: FileSystemModel.Files
        nameFilters: ["*.mp4", "*.webm", "*.mkv"]
    }

    Process {
        id: getPreviewColoursProc

        property string currentProcessingPath: ""
        command: ["selestis", "wallpaper", "-p", currentProcessingPath, ...root.smartArg]

        function startFor(path: string): void {
            currentProcessingPath = path;
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (root.showPreview && raw) {
                    try {
                        JSON.parse(raw);
                        Colours.load(raw, true);
                        Colours.showPreview = true;
                    } catch (e) {
                        // Ignore partial output when a preview process is replaced.
                    }
                }
                if (root.showPreview && root.previewPath !== currentProcessingPath)
                    getPreviewColoursProc.startFor(root.previewPath);
            }
        }
    }

    // SEL-AW: the CLI writes this sentinel after thumbnail extraction; watching it
    // gives the launcher an inexpensive cache invalidation path.
    FileView {
        path: "/tmp/selestis_thumb_ready.txt"
        watchChanges: true
        printErrors: false
        onLoaded: root.cacheBuster = Date.now().toString()
    }

    function refreshAnimatedThumbs(): void {
        if (thumbRefreshProc.running)
            return;
        thumbRefreshProc.running = true;
    }

    Process {
        id: thumbRefreshProc
        command: ["selestis", "wallpaper", "--extract-thumbs"]
        onExited: {
            root.cacheBuster = Date.now().toString();
        }
    }
}
