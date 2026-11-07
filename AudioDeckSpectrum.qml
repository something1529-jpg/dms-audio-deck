import QtQuick
import QtQuick.Window
import qs.Common
import "."

// Live spectrum bars. AudioDeckCava owns a native-PipeWire Cava process that
// reads the explicit monitor of the current default sink. When there is no
// real signal, or Cava is unavailable, the bars are a static shape with no
// animation clock: nothing here invents movement.
Item {
    id: root

    property int barCount: 12
    property real maxBarHeight: Theme.iconSize - Theme.spacingXXS
    property real minBarHeight: Theme.spacingXXS
    property real barWidth: Theme.spacingXS - Theme.spacingXXS / 2
    property real gap: Theme.spacingXXS
    property bool stretch: false
    property bool active: true
    property bool enabled: true
    property color barColor: Theme.primary

    implicitWidth: barCount * barWidth + Math.max(0, barCount - 1) * gap
    implicitHeight: maxBarHeight

    readonly property bool hasSignal: {
        const values = AudioDeckCava.values;
        if (!values)
            return false;
        for (let i = 0; i < values.length; ++i) {
            if ((values[i] ?? 0) > 0)
                return true;
        }
        return false;
    }
    // Read the window state from this Item, not from inside Loader;
    // attached Window lookups are only valid on Item-derived objects.
    readonly property bool windowVisible: Window.window ? Window.window.visible : true
    readonly property bool live: active && enabled && AudioDeckCava.cavaAvailable && hasSignal && root.visible && root.windowVisible
    readonly property real cellWidth: stretch && width > 0 ? Math.max(Theme.outlineWidth, (width - (barCount - 1) * gap) / barCount) : barWidth

    // Hold the Cava reference only while these bars are mounted and visible.
    // The tiny lifecycle item is the ref token; destroying it releases Cava.
    Loader {
        active: root.active && root.enabled && root.visible && root.windowVisible
        sourceComponent: Component {
            Item {
                Component.onCompleted: AudioDeckCava.acquire()
                Component.onDestruction: AudioDeckCava.release()
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: root.barCount

            delegate: Item {
                id: cell
                required property int index

                width: root.cellWidth
                height: root.maxBarHeight

                readonly property real level: {
                    if (!root.active)
                        return 0;
                    if (root.live) {
                        const values = AudioDeckCava.values;
                        const pos = values && values.length > 1 && root.barCount > 1 ? cell.index * (values.length - 1) / (root.barCount - 1) : 0;
                        const low = Math.floor(pos);
                        const high = values && values.length > 0 ? Math.min(values.length - 1, low + 1) : 0;
                        const blend = pos - low;
                        const raw = values && values.length > 0 ? (values[low] ?? 0) * (1 - blend) + (values[high] ?? 0) * blend : 0;
                        return Math.sqrt(Math.max(0, Math.min(1, raw / 100)));
                    }
                    // Static, deterministic idle shape. No timer, no phase, no
                    // synthetic motion; the bars simply sit at these heights.
                    return 0.16 + ((cell.index * 7) % 5) * 0.035;
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(root.minBarHeight, root.maxBarHeight * cell.level)
                    anchors.bottom: parent.bottom
                    radius: Math.min(width / 2, Theme.spacingXXS)
                    color: root.barColor
                    opacity: root.active ? (root.live ? 0.9 : 0.45) : 0.3
                }
            }
        }
    }
}
