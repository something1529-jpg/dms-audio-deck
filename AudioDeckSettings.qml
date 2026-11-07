import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "audioDeck"

    StyledRect {
        width: parent.width
        height: intro.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.chipSurface

        Column {
            id: intro
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingM

                DIcon {
                    name: "graphic_eq"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: Theme.spacingXXS
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: "PipeWire mixer"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: "Apps and devices are read live from PipeWire; nothing is polled or stored."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    SliderSetting {
        settingKey: "maxVolume"
        label: "Maximum volume"
        description: "Upper limit for the master and per-app sliders"
        defaultValue: 100
        minimum: 100
        maximum: 150
        unit: "%"
    }

    SliderSetting {
        settingKey: "wheelStep"
        label: "Scroll step"
        description: "How much one wheel notch changes a slider"
        defaultValue: 5
        minimum: 1
        maximum: 25
        unit: "%"
    }

    ToggleSetting {
        settingKey: "showVisualizer"
        label: "Live spectrum"
        description: "Cava-driven bars in the bar pill and on the master card (requires cava)"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showPercent"
        label: "Show percentage on the bar"
        description: "Draw the master volume number next to the bar icon"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "animations"
        label: "Smooth animations"
        description: "Animated rings, meters and transitions; still follows the shell's reduce-motion setting"
        defaultValue: true
    }
}
