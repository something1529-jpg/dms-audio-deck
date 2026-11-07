pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "."

// A private Cava instance for Audio Deck. The shell's CavaService watches its
// default Pulse input, which can be a microphone; this instance reads the
// monitor of the explicit default output sink so the bars match what is audible.
Singleton {
    id: root

    // Every visible spectrum holds one reference. Cava runs only while at
    // least one is on screen, plus a very short linger so a popout morph does
    // not recreate the capture stream and change the PipeWire quantum.
    property int refCount: 0
    property list<int> values: [0, 0, 0, 0, 0, 0]
    property bool cavaAvailable: false
    property bool probed: false
    property bool probeRequested: false

    readonly property string sinkName: AudioService.sink?.name ?? ""
    // Only spend a capture stream on audio that can actually be heard.
    readonly property bool audible: AudioDeckService.audiblePlayback && !AudioDeckService.masterMuted && AudioDeckService.masterVolume > 0
    // refCount is checked first so the whole audio scan is skipped while no
    // spectrum is mounted: JS short-circuits, and QML therefore never tracks
    // the playback properties when nothing is watching.
    readonly property bool wanted: refCount > 0 && sinkName !== "" && audible
    // 6 fps is plenty for the small bars; drop further on battery.
    readonly property int framerate: BatteryService.isPluggedIn ? 6 : 4
    property bool restarting: false
    property string activeSink: ""

    onSinkNameChanged: {
        // Some PipeWire events briefly empty the default sink; do not tear
        // down a working capture stream for that or for a same-name update.
        if (sinkName === "" || sinkName === activeSink)
            return;
        activeSink = sinkName;
        restartForChange();
    }
    onFramerateChanged: restartForChange()
    onAudibleChanged: {
        if (!audible)
            lingerTimer.stop();
    }

    function restartForChange() {
        if (!cava.running)
            return;
        restarting = true;
    }

    onRefCountChanged: {
        if (refCount > 0) {
            lingerTimer.stop();
            return;
        }
        values = [0, 0, 0, 0, 0, 0];
        if (cava.running && audible)
            lingerTimer.restart();
        else
            lingerTimer.stop();
    }

    function acquire() {
        refCount += 1;
        probeRequested = true;
    }

    function release() {
        refCount = Math.max(0, refCount - 1);
    }

    // Cava is optional. The probe is lazy: a shell that never shows the
    // spectrum never spawns even this one-shot shell.
    Process {
        id: probe
        // Latched, so a quick open/close cannot kill the probe halfway and
        // leave Cava permanently marked as missing.
        running: root.probeRequested && !root.probed
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1"]

        onExited: function (exitCode) {
            root.probed = true;
            root.cavaAvailable = exitCode === 0;
        }
    }

    // Just long enough to bridge a popout open/close; anything longer is a
    // capture stream burning power for nothing.
    Timer {
        id: lingerTimer
        interval: 3000
        repeat: false
    }

    // Start the replacement only after the old capture stream has exited.
    Timer {
        id: restartTimer
        interval: 120
        repeat: false

        onTriggered: root.restarting = false
    }

    Process {
        id: cava
        running: root.cavaAvailable && !root.restarting && (root.wanted || (lingerTimer.running && root.audible))

        // Cava asks for a small buffer when it starts. Keep the graph quantum
        // stable, as the shell's CavaService does, so opening the mixer does
        // not produce an audible latency change on affected hardware.
        environment: ({
            "PIPEWIRE_LATENCY": "2400/48000",
            "PULSE_LATENCY_MSEC": "50"
        })

        // The config is passed through file descriptor 3, so there is no
        // temporary configuration file to leave behind. The sink name is a
        // positional argument, never interpolated into shell source. `sh` is
        // enough for the heredoc, so no bash process is kept alive.
        command: ["sh", "-c", `exec 3<<CAVA
[general]
framerate=${root.framerate}
bars=6
autosens=1
sensitivity=100
sleep_timer=0
lower_cutoff_freq=50
higher_cutoff_freq=12000

[input]
method=pipewire
source="$1.monitor"
active=1

[output]
method=raw
raw_target=/dev/stdout
data_format=ascii
channels=mono
mono_option=average

[smoothing]
noise_reduction=0
integral=70
gravity=80
ignore=1
monstercat=1.5
CAVA
exec cava -p /dev/fd/3`, "audio-deck-cava", root.sinkName]

        stdout: SplitParser {
            onRead: function (line) {
                if (root.refCount <= 0)
                    return;
                const points = line.trim().split(";");
                const clean = [];
                for (let i = 0; i < 6; ++i) {
                    const value = parseInt(points[i] ?? "0", 10);
                    clean.push(isFinite(value) ? Math.max(0, value) : 0);
                }
                // Do not wake QML bindings for repeated silent frames. This is
                // what keeps a visible idle spectrum at zero animation cost.
                const current = root.values;
                let changed = false;
                for (let i = 0; i < clean.length; ++i) {
                    if ((current?.[i] ?? 0) !== clean[i]) {
                        changed = true;
                        break;
                    }
                }
                if (changed)
                    root.values = clean;
            }
        }

        onRunningChanged: {
            if (running)
                return;
            root.values = [0, 0, 0, 0, 0, 0];
            if (root.restarting)
                restartTimer.restart();
        }
    }
}
