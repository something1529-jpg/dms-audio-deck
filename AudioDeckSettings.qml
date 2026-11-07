import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "audioDeck"

    function applyFps(settingKey, slider, value) {
        slider.value = value;
        root.saveValue(settingKey, value);
    }

    function migrateVisualizerSettings() {
        if (!root.pluginService)
            return;
        // Preserve the old single-spectrum preference for existing installs.
        if (root.loadValue("showWidgetVisualizer", undefined) === undefined)
            root.saveValue("showWidgetVisualizer", root.loadValue("showVisualizer", true) !== false);
        if (root.loadValue("showMixerVisualizer", undefined) === undefined)
            root.saveValue("showMixerVisualizer", root.loadValue("showVisualizer", true) !== false);
    }

    Connections {
        target: root
        function onPluginServiceChanged() {
            root.migrateVisualizerSettings();
        }
    }

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

    StyledText {
        width: parent.width
        text: "Spectrum"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    ToggleSetting {
        id: widgetSpectrumToggle
        settingKey: "showWidgetVisualizer"
        label: "Spectrum in the bar pill"
        description: "Cava-driven bars on the compact bar widget (requires cava)"
        defaultValue: true
    }

    SliderSetting {
        id: widgetFpsSlider
        settingKey: "widgetFps"
        visible: widgetSpectrumToggle.value
        label: "Bar pill frame rate"
        description: "Redraws per second for this spectrum. The shared Cava capture uses the highest enabled rate."
        defaultValue: 4
        minimum: 1
        maximum: 30
        unit: " fps"
    }

    Row {
        width: parent.width
        spacing: Theme.spacingXS
        visible: widgetSpectrumToggle.value

        DButton {
            width: (parent.width - Theme.spacingXS * 2) / 3
            text: "Battery 4"
            backgroundColor: widgetFpsSlider.value === 4 ? Theme.primary : Theme.surfaceContainerHigh
            textColor: widgetFpsSlider.value === 4 ? Theme.onPrimary : Theme.surfaceText
            onClicked: root.applyFps("widgetFps", widgetFpsSlider, 4)
        }

        DButton {
            width: (parent.width - Theme.spacingXS * 2) / 3
            text: "Smooth 12"
            backgroundColor: widgetFpsSlider.value === 12 ? Theme.primary : Theme.surfaceContainerHigh
            textColor: widgetFpsSlider.value === 12 ? Theme.onPrimary : Theme.surfaceText
            onClicked: root.applyFps("widgetFps", widgetFpsSlider, 12)
        }

        DButton {
            width: (parent.width - Theme.spacingXS * 2) / 3
            text: "Fluent 30"
            backgroundColor: widgetFpsSlider.value === 30 ? Theme.primary : Theme.surfaceContainerHigh
            textColor: widgetFpsSlider.value === 30 ? Theme.onPrimary : Theme.surfaceText
            onClicked: root.applyFps("widgetFps", widgetFpsSlider, 30)
        }
    }

    ToggleSetting {
        id: mixerSpectrumToggle
        settingKey: "showMixerVisualizer"
        label: "Spectrum in the opened mixer"
        description: "Cava-driven bars on the mixer's master card (requires cava)"
        defaultValue: true
    }

    SliderSetting {
        id: mixerFpsSlider
        settingKey: "mixerFps"
        visible: mixerSpectrumToggle.value
        label: "Mixer frame rate"
        description: "Redraws per second for this spectrum. The shared Cava capture uses the highest enabled rate."
        defaultValue: 12
        minimum: 1
        maximum: 30
        unit: " fps"
    }

    Row {
        width: parent.width
        spacing: Theme.spacingXS
        visible: mixerSpectrumToggle.value

        DButton {
            width: (parent.width - Theme.spacingXS * 2) / 3
            text: "Battery 4"
            backgroundColor: mixerFpsSlider.value === 4 ? Theme.primary : Theme.surfaceContainerHigh
            textColor: mixerFpsSlider.value === 4 ? Theme.onPrimary : Theme.surfaceText
            onClicked: root.applyFps("mixerFps", mixerFpsSlider, 4)
        }

        DButton {
            width: (parent.width - Theme.spacingXS * 2) / 3
            text: "Smooth 12"
            backgroundColor: mixerFpsSlider.value === 12 ? Theme.primary : Theme.surfaceContainerHigh
            textColor: mixerFpsSlider.value === 12 ? Theme.onPrimary : Theme.surfaceText
            onClicked: root.applyFps("mixerFps", mixerFpsSlider, 12)
        }

        DButton {
            width: (parent.width - Theme.spacingXS * 2) / 3
            text: "Fluent 30"
            backgroundColor: mixerFpsSlider.value === 30 ? Theme.primary : Theme.surfaceContainerHigh
            textColor: mixerFpsSlider.value === 30 ? Theme.onPrimary : Theme.surfaceText
            onClicked: root.applyFps("mixerFps", mixerFpsSlider, 30)
        }
    }

    StyledText {
        width: parent.width
        text: "Both spectra share one Cava process. It captures at the highest enabled frame rate; each slider controls that surface's redraw rate."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
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
