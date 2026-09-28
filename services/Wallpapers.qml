pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")
    readonly property list<string> validVideoExtensions: ["mp4", "webm", "mkv"]
    readonly property list<string> validAnimatedExtensions: ["mp4", "webm", "mkv", "gif"]
    property string cacheBuster: ""

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear

    function isVideo(path: string): bool {
        const clean = String(path || "").split(/[?#]/)[0].toLowerCase();
        const index = clean.lastIndexOf(".");
        const ext = index >= 0 ? clean.slice(index + 1) : "";
        return validVideoExtensions.includes(ext);
    }

    function isAnimated(path: string): bool {
        const clean = String(path || "").split(/[?#]/)[0].toLowerCase();
        const index = clean.lastIndexOf(".");
        const ext = index >= 0 ? clean.slice(index + 1) : "";
        return validAnimatedExtensions.includes(ext);
    }

    function toFileUrl(path: string): url {
        const clean = String(path || "").trim();
        if (!clean)
            return "";
        if (clean.startsWith("file://"))
            return clean;
        if (clean.startsWith("/"))
            return `file://${clean}`;
        return Qt.resolvedUrl(clean);
    }

    function djb2Hash(value: string): string {
        let hash = 5381;
        for (let i = 0; i < value.length; i++)
            hash = ((hash * 33) + value.charCodeAt(i)) >>> 0;
        return hash.toString(10);
    }

    function getWallpaperThumb(path: string, buster = cacheBuster): string {
        let clean = String(path || "").split(/[?#]/)[0];
        if (clean.startsWith("file://"))
            clean = clean.slice(7);
        return `file://${Paths.cache}/videothumbs/${djb2Hash(clean)}.jpg${buster ? `?v=${buster}` : ""}`;
    }

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function queryStatic(search: string): list<var> {
        return staticSearcher.query(search).filter(w => !root.isAnimated(w.path));
    }

    function queryAnimated(search: string): list<var> {
        return animatedSearcher.query(search);
    }

    function refreshAnimatedThumbs(): void {
        extractThumbs.running = true;
    }

    function setRandom(): void {
        Quickshell.execDetached(["caelestia", "wallpaper", "-r", ...smartArg]);
    }

    function setWallpaper(path: string): void {
        actualCurrent = String(path).replace(/^file:\/\//, "");
        Quickshell.execDetached(["caelestia", "wallpaper", "-f", actualCurrent, ...smartArg]);
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;
        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    // Keep the original upstream image list intact for existing consumers.
    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    Searcher {
        id: staticSearcher
        list: wallpapers.entries
        key: "relativePath"
        useFuzzy: root.useFuzzy
        extraOpts: root.extraOpts
    }

    Searcher {
        id: animatedSearcher
        list: animatedWallpapers.entries
        key: "relativePath"
        useFuzzy: root.useFuzzy
        extraOpts: root.extraOpts
    }

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

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
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            }
            root.actualCurrent = wall;
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
        }
    }

    FileSystemModel {
        id: wallpapers
        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images
    }

    FileSystemModel {
        id: animatedWallpapers
        watchChanges: true
        recursive: true
        path: `${Paths.wallsdir}/Animated`
        filter: FileSystemModel.Files
        nameFilters: root.validAnimatedExtensions.map(ext => `*.${ext}`)
    }

    Process {
        id: getPreviewColoursProc
        command: ["caelestia", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }

    Process {
        id: extractThumbs
        command: ["caelestia", "wallpaper", "--extract-thumbs"]
        onExited: {
            root.cacheBuster = Date.now().toString();
        }
    }
}
