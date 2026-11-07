pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

// Shared state for every surface (bar pill, popout, Control Center detail).
// Streams and devices come straight from PipeWire through Quickshell, so the
// mixer follows nodes appearing, disappearing and changing volume elsewhere.
Singleton {
    id: root

    // Mirrored from plugin settings by the widget so all instances agree.
    property int maxVolume: 100
    property int wheelStep: 5
    property bool visualizer: true
    property bool showPercent: true
    property bool animations: true

    property var pendingDefaultSource: null

    // Model caches. They live in plain JS objects so a binding can memoise
    // without assigning a QML property (which would create a binding loop).
    // Reusing the previous array keeps Repeater delegates alive when only node
    // properties changed, so a volume tick no longer recreates every row.
    property var streamCache: ({ list: [] })
    property var captureCache: ({ list: [] })
    property var sinkCache: ({ list: [], defaultName: "" })
    property var sourceCache: ({ list: [] })

    readonly property bool ready: AudioService.pipewireReady
    readonly property var master: AudioService.sink
    readonly property var mic: AudioService.source
    readonly property var nodes: AudioService.pipewireNodes

    readonly property real masterVolume: master?.audio?.volume ?? 0
    readonly property int masterPercent: Math.round(masterVolume * 100)
    readonly property bool masterMuted: master?.audio?.muted ?? false
    readonly property bool motion: animations && !(typeof SettingsData !== "undefined" && SettingsData.reduceMotion)

    // One pass over the nodes feeds both the bar/CC label and the Cava
    // lifecycle. The label must not sort the whole stream list, and Cava must
    // not either; this keeps idle updates allocation-free.
    readonly property var playbackStats: {
        let count = 0;
        let audible = false;
        const list = nodes;
        for (let i = 0; list && i < list.length; ++i) {
            const node = list[i];
            if (!isPlaybackStream(node))
                continue;
            ++count;
            if (!audible && !paused(node) && !node.audio?.muted && (node.audio?.volume ?? 0) > 0)
                audible = true;
        }
        return {
            "count": count,
            "audible": audible
        };
    }
    readonly property int playbackCount: playbackStats.count
    readonly property bool audiblePlayback: playbackStats.audible

    // Playback streams: one row per app that is currently sending audio.
    readonly property var streams: {
        const cache = streamCache;
        const list = [];
        const nodeList = nodes || [];
        for (let i = 0; i < nodeList.length; ++i) {
            const node = nodeList[i];
            if (isPlaybackStream(node))
                list.push(node);
        }
        // Only rebuild the model when membership changed; volume and mute
        // updates ride the existing delegates instead of recreating them.
        if (sameNodes(cache.list, list))
            return cache.list;
        list.sort((a, b) => {
            const ap = paused(a) ? 1 : 0;
            const bp = paused(b) ? 1 : 0;
            if (ap !== bp)
                return ap - bp;
            const am = a.audio?.muted ? 1 : 0;
            const bm = b.audio?.muted ? 1 : 0;
            if (am !== bm)
                return am - bm;
            return appName(a).localeCompare(appName(b));
        });
        cache.list = list;
        return list;
    }

    // Capture streams (apps recording, e.g. browser tabs or voice chat).
    readonly property var recordings: {
        const cache = captureCache;
        const list = [];
        const nodeList = nodes || [];
        for (let i = 0; i < nodeList.length; ++i) {
            const node = nodeList[i];
            if (isCaptureStream(node))
                list.push(node);
        }
        if (sameNodes(cache.list, list))
            return cache.list;
        cache.list = list;
        return list;
    }

    readonly property var sinks: {
        const cache = sinkCache;
        const list = [];
        const nodeList = nodes || [];
        for (let i = 0; i < nodeList.length; ++i) {
            const node = nodeList[i];
            if (!node || !node.audio || node.isStream || !node.isSink)
                continue;
            if (isHidden(node.name))
                continue;
            list.push(node);
        }
        const defaultName = AudioService.sink?.name ?? "";
        if (cache.defaultName === defaultName && sameNodes(cache.list, list))
            return cache.list;
        list.sort((a, b) => {
            if (a.name === defaultName)
                return -1;
            if (b.name === defaultName)
                return 1;
            return displayName(a).localeCompare(displayName(b));
        });
        cache.list = list;
        cache.defaultName = defaultName;
        return list;
    }

    readonly property var sources: {
        const cache = sourceCache;
        const list = [];
        const nodeList = nodes || [];
        for (let i = 0; i < nodeList.length; ++i) {
            const node = nodeList[i];
            if (!node || !node.audio || node.isStream || node.isSink)
                continue;
            if (isMonitor(node) || isHidden(node.name))
                continue;
            list.push(node);
        }
        if (sameNodes(cache.list, list))
            return cache.list;
        cache.list = list;
        return list;
    }

    // True when both arrays hold the same nodes in the same order. Comparing
    // membership (not the arrays themselves) is what lets the cached model
    // survive PipeWire updates that only touch properties.
    function sameNodes(a, b) {
        if (a === b)
            return true;
        if (!a || !b || a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; ++i) {
            if (a[i] !== b[i])
                return false;
        }
        return true;
    }

    function isPlaybackStream(node) {
        if (!node || !node.audio || !node.isStream || !node.isSink)
            return false;
        const props = node.properties || {};
        // Loopbacks and other virtual plumbing are not apps; they only add noise.
        if (props["node.virtual"] === "true")
            return false;
        // DMS's own notification/media sounds should not be mixable.
        return !AudioService.isOwnStream(node);
    }

    function isCaptureStream(node) {
        if (!node || !node.audio || !node.isStream || node.isSink)
            return false;
        const props = node.properties || {};
        if (props["node.virtual"] === "true")
            return false;
        return !AudioService.isOwnStream(node);
    }

    function isMonitor(node) {
        const props = node?.properties || {};
        return props["device.class"] === "monitor" || (node?.name || "").endsWith(".monitor");
    }

    function isHidden(name) {
        if (!name)
            return false;
        const outputs = SessionData.hiddenOutputDeviceNames ?? [];
        const inputs = SessionData.hiddenInputDeviceNames ?? [];
        return outputs.indexOf(name) !== -1 || inputs.indexOf(name) !== -1;
    }

    function paused(node) {
        const props = node?.properties || {};
        return props["pulse.corked"] === "true" || props["node.paused"] === "true";
    }

    function appName(node) {
        const props = node?.properties || {};
        return props["application.name"]
            || props["application.process.binary"]
            || node?.nickname
            || node?.description
            || node?.name
            || "Unknown app";
    }

    function appIcon(node) {
        const props = node?.properties || {};
        const icon = props["application.icon-name"] || props["application.icon_name"] || "";
        if (icon)
            return icon;
        const binary = props["application.process.binary"] || "";
        if (binary)
            return binary;
        return "material:graphic_eq";
    }

    function displayName(node) {
        if (!node)
            return "";
        return node.isStream ? appName(node) : AudioService.displayName(node);
    }

    function deviceIcon(node, input) {
        if (input)
            return "material:mic";
        return "material:" + AudioService.sinkIcon(node);
    }

    function streamSubtitle(node, capture) {
        if (paused(node))
            return "Paused";
        if (node?.audio?.muted)
            return "Muted";
        if ((node?.audio?.volume ?? 0) <= 0)
            return "Silent";
        const props = node?.properties || {};
        const media = props["media.name"] || "";
        if (media && media !== "Playback" && media !== appName(node))
            return media;
        return capture ? "Recording" : "Playing";
    }

    function nodePercent(node) {
        return Math.round((node?.audio?.volume ?? 0) * 100);
    }

    function isDefaultDevice(node) {
        if (!node || node.isStream)
            return false;
        if (node.isSink)
            return AudioService.sink?.name === node.name;
        return AudioService.source?.name === node.name;
    }

    function setVolume(node, percent) {
        const audio = node?.audio;
        if (!audio)
            return;
        // Stream changes are silent on purpose; device changes would otherwise
        // fire the shell's volume OSD for every drag pixel.
        if (typeof SessionData !== "undefined" && !node.isStream)
            SessionData.suppressOSDTemporarily();
        const clamped = Math.max(0, Math.min(maxVolume, Math.round(percent)));
        audio.volume = clamped / 100;
        if (clamped > 0 && audio.muted)
            audio.muted = false;
    }

    function adjustVolume(node, delta) {
        setVolume(node, nodePercent(node) + delta);
    }

    function toggleMute(node) {
        const audio = node?.audio;
        if (!audio)
            return;
        if (typeof SessionData !== "undefined" && !node.isStream)
            SessionData.suppressOSDTemporarily();
        audio.muted = !audio.muted;
    }

    function setDefault(node) {
        if (!node || node.isStream)
            return;
        if (node.isSink) {
            AudioService.setSink(node);
            toast("Output switched", displayName(node));
            return;
        }
        AudioService.setSource(node);
        // WirePlumber only applies preferredDefaultAudioSource to the configured
        // node. Also write the active default so the system default really moves.
        pendingDefaultSource = node;
        activeSourceTimer.restart();
    }

    // Let WirePlumber apply the configured default first; writing the active
    // default immediately can be overwritten by that update.
    Timer {
        id: activeSourceTimer
        interval: 250
        repeat: false

        onTriggered: {
            const node = root.pendingDefaultSource;
            if (!node)
                return;
            if (activeSourceProc.running)
                activeSourceProc.running = false;
            activeSourceProc.command = ["pw-metadata", "-n", "default", "0", "default.audio.source", JSON.stringify({ name: node.name })];
            activeSourceProc.running = true;
        }
    }

    Process {
        id: activeSourceProc
        running: false

        onExited: function (exitCode) {
            const errorText = (activeSourceError.text || "").trim();
            const node = root.pendingDefaultSource;
            root.pendingDefaultSource = null;
            if (exitCode === 0) {
                root.toast("Microphone switched", root.displayName(node));
                return;
            }
            if (typeof ToastService !== "undefined")
                ToastService.showError("Input switch failed", errorText || ("pw-metadata exited with " + exitCode));
        }

        stderr: StdioCollector {
            id: activeSourceError
        }
    }

    function toast(title, body) {
        if (typeof ToastService !== "undefined")
            ToastService.showInfo(title, body);
    }

    function syncSettings(data) {
        if (!data)
            return;
        maxVolume = clampInt(data.maxVolume, 100, 150, 100);
        wheelStep = clampInt(data.wheelStep, 1, 25, 5);
        visualizer = data.showVisualizer !== false;
        showPercent = data.showPercent !== false;
        animations = data.animations !== false;
    }

    function clampInt(value, minimum, maximum, fallback) {
        const n = Math.round(Number(value));
        if (!isFinite(n))
            return fallback;
        return Math.max(minimum, Math.min(maximum, n));
    }
}
