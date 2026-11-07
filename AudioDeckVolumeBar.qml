import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Volume control shared by app rows, the master card, and the bar popout.
Item {
    id: root

    property real value: 0
    property real maxValue: 100
    property bool muted: false
    property int wheelStep: 5
    property color accent: Theme.primary
    property color trackColor: Theme.onSurface

    signal moved(real newValue)
    signal committed(real newValue)

    implicitHeight: slider.implicitHeight

    DSlider {
        id: slider

        width: root.width
        anchors.verticalCenter: parent.verticalCenter
        minimum: 0
        maximum: Math.max(1, Math.round(root.maxValue))
        step: 1
        wheelStep: root.wheelStep
        showValue: false
        fillColor: root.muted ? Theme.surfaceVariantText : root.accent
        trackColor: root.trackColor
        opacity: root.muted ? 0.65 : 1
        enabled: root.enabled
        Accessible.name: "Volume"

        // Keep the slider in sync with PipeWire without fighting a drag.
        Binding on value {
            when: !slider.isDragging
            value: Math.round(root.value)
            restoreMode: Binding.RestoreNone
        }

        onSliderValueChanged: newValue => root.moved(newValue)
        onSliderDragFinished: newValue => root.committed(newValue)
    }
}
