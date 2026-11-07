pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "."

// A private Cava instance for Audio Deck. The shell's CavaService feeds Cava
// through its default Pulse input, which on this host watches the muted Rift
// microphone. Here Cava uses native PipeWire and an explicit monitor source for
// the current default sink, the same signal the speakers are playing.
Singleton {
    id: root

    // Every visible spectrum holds one reference. Cava runs only while at
    // least one is on screen, so hidden popouts and detail pages cost nothing.
    property int refCount: 0
    property list<int> values: [0, 0, 0, 0, 0, 0]
    property bool cavaAvailable: false

    readonly property string sinkName: AudioService.sink?.name ?? ""
    readonly property bool somethingPlaying: AudioDeckService.streams.length > 0
    readonly property bool wanted: refCount > 0 && sinkName !== "" && somethingPlaying

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

    Process {
        id: cava
        running: root.cavaAvailable && root.wanted

        // The config is passed through file descriptor 3, so there is no
        // temporary configuration file to leave behind. native PipeWire reads
        // the explicit sink monitor rather than the default source.
        command: ["bash", "-c", `exec 3<<'CAVA'
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
source=${root.sinkName}.monitor
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
exec cava -p /dev/fd/3`]

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
