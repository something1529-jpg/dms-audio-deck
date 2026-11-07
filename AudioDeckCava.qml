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
    // least one is on screen, plus a short linger so a popout morph does not
    // recreate the capture stream and change the PipeWire quantum.
    property int refCount: 0
    property list<int> values: [0, 0, 0, 0, 0, 0]
    property bool cavaAvailable: false

    readonly property string sinkName: AudioService.sink?.name ?? ""
    readonly property bool somethingPlaying: {
        const streams = AudioDeckService.streams;
        for (let i = 0; i < streams.length; ++i) {
            if (!AudioDeckService.paused(streams[i]))
                return true;
        }
        return false;
    }
    readonly property bool wanted: refCount > 0 && sinkName !== "" && somethingPlaying

    onRefCountChanged: {
        if (refCount > 0) {
            lingerTimer.stop();
            return;
        }
        values = [0, 0, 0, 0, 0, 0];
        if (cava.running)
            lingerTimer.restart();
    }

    function acquire() {
        refCount += 1;
    }

    function release() {
        refCount = Math.max(0, refCount - 1);
    }

    // Cava is optional. No binary means no process, and the spectrum stays
    // static rather than inventing levels.
    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v cava"]

        onExited: function (exitCode) {
            root.cavaAvailable = exitCode === 0;
        }
    }

    Timer {
        id: lingerTimer
        interval: 30000
        repeat: false
    }

    Process {
        id: cava
        running: root.cavaAvailable && (root.wanted || lingerTimer.running)

        // Cava asks for a small buffer when it starts. Keep the graph quantum
        // stable, as the shell's CavaService does, so opening the mixer does
        // not produce an audible latency change on affected hardware.
        environment: ({
            "PIPEWIRE_LATENCY": "2400/48000",
            "PULSE_LATENCY_MSEC": "50"
        })

        // The config is passed through file descriptor 3, so there is no
        // temporary configuration file to leave behind. The sink name is a
        // positional argument, never interpolated into shell source.
        command: ["bash", "-c", `exec 3<<CAVA
[general]
framerate=8
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
            if (!running)
                root.values = [0, 0, 0, 0, 0, 0];
        }
    }
}
