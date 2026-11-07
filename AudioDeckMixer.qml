import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import "."

// The mixer itself, shared by the bar popout and the Control Center detail page.
Column {
    id: root

    property bool compact: false
    property real listHeight: 300
    property string tab: "apps"

    readonly property bool animate: AudioDeckService.animations && !(typeof SettingsData !== "undefined" && SettingsData.reduceMotion)

    readonly property var tabs: [
        {
            key: "apps",
            label: "Apps",
            count: AudioDeckService.streams.length
        },
        {
            key: "output",
            label: "Outputs",
            count: AudioDeckService.sinks.length
        },
        {
            key: "input",
            label: "Inputs",
            count: AudioDeckService.sources.length + AudioDeckService.recordings.length
        }
    ]

    readonly property var currentNodes: {
        if (tab === "output")
            return AudioDeckService.sinks;
        if (tab === "input")
            return AudioDeckService.sources.concat(AudioDeckService.recordings);
        return AudioDeckService.streams;
    }

    readonly property string emptyTitle: tab === "apps" ? "Nothing playing" : (tab === "output" ? "No output devices" : "No inputs")

    readonly property string emptyHint: {
        if (tab === "apps")
            return "Start playback in any app and it will appear here, ready to mix.";
        if (tab === "output")
            return "PipeWire reported no output devices. Check that wireplumber is running.";
        return "No microphones or apps recording right now.";
    }

    spacing: Theme.spacingM

    function rowTitle(node) {
        return node.isStream ? AudioDeckService.appName(node) : AudioDeckService.displayName(node);
    }

    function rowIcon(node) {
        if (node.isStream)
            return AudioDeckService.appIcon(node);
        return AudioDeckService.deviceIcon(node, !node.isSink);
    }

    function rowSubtitle(node) {
        if (node.isStream)
            return AudioDeckService.streamSubtitle(node, !node.isSink);
        if (AudioDeckService.isDefaultDevice(node))
            return node.isSink ? "Default output" : "Default input";
        return node.isSink ? "Output device" : "Input device";
    }

    onTabChanged: {
        if (listFlick)
            listFade.restart();
    }

    NumberAnimation {
        id: listFade
        target: listFlick
        property: "opacity"
        from: 0.35
        to: 1
        duration: root.animate ? 180 : 0
    }

    // Master card ----------------------------------------------------------
    Rectangle {
        id: hero
        width: parent.width
        implicitHeight: heroRow.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadiusXL
        color: Theme.foregroundColor(Theme.cardSurface)
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.14)
        clip: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.withAlpha(Theme.primary, 0.20) }
                GradientStop { position: 0.55; color: Theme.withAlpha(Theme.secondary, 0.08) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Soft accent bloom in the corner, kept inside the clip.
        Rectangle {
            width: 170
            height: 170
            radius: width / 2
            x: hero.width - 110
            y: -80
            color: Theme.withAlpha(Theme.secondary, 0.10)
        }

        Row {
            id: heroRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingM

            Item {
                id: ringBox
                width: root.compact ? 74 : 88
                height: width
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.primary, 0.30)
                }

                AudioDeckRing {
                    anchors.fill: parent
                    value: AudioDeckService.masterPercent
                    maxValue: AudioDeckService.maxVolume
                    strokeWidth: root.compact ? 4 : 5
                    animated: root.animate
                    ringColor: AudioDeckService.masterMuted ? Theme.surfaceVariantText : Theme.primary
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: AudioDeckService.masterPercent + "%"
                        font.pixelSize: root.compact ? Theme.fontSizeLarge : Theme.fontSizeXLarge
                        font.weight: Font.DemiBold
                        color: AudioDeckService.masterMuted ? Theme.surfaceVariantText : Theme.surfaceText
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "VOLUME"
                        font.pixelSize: Theme.fontSizeXSmall
                        font.letterSpacing: 1.3
                        color: Theme.surfaceVariantText
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioDeckService.toggleMute(AudioDeckService.master)
                    onWheel: wheel => AudioDeckService.adjustVolume(AudioDeckService.master, wheel.angleDelta.y > 0 ? AudioDeckService.wheelStep : -AudioDeckService.wheelStep)
                }
            }

            Column {
                width: Math.max(0, parent.width - ringBox.width - Theme.spacingM)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                Item {
                    width: parent.width
                    height: Math.max(outputLabel.implicitHeight, muteChip.height)

                    StyledText {
                        id: outputLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "OUTPUT"
                        font.pixelSize: Theme.fontSizeXSmall
                        font.letterSpacing: 1.2
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }

                    Rectangle {
                        id: muteChip
                        visible: AudioDeckService.master !== null
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 22
                        width: muteChipRow.implicitWidth + Theme.spacingM
                        radius: height / 2
                        color: AudioDeckService.masterMuted ? Theme.withAlpha(Theme.error, 0.16) : Theme.withAlpha(Theme.primary, 0.12)

                        Behavior on color {
                            ColorAnimation { duration: 160 }
                        }

                        Row {
                            id: muteChipRow
                            anchors.centerIn: parent
                            spacing: 4

                            DIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: AudioDeckService.masterMuted ? "volume_off" : "volume_up"
                                size: 12
                                color: AudioDeckService.masterMuted ? Theme.error : Theme.primary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: AudioDeckService.masterMuted ? "Muted" : "Live"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: AudioDeckService.masterMuted ? Theme.error : Theme.primary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioDeckService.toggleMute(AudioDeckService.master)
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: AudioDeckService.master ? AudioDeckService.displayName(AudioDeckService.master) : "No output device"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: root.compact ? Theme.fontSizeMedium : Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                }

                AudioDeckVolumeBar {
                    width: parent.width
                    value: AudioDeckService.masterPercent
                    maxValue: AudioDeckService.maxVolume
                    muted: AudioDeckService.masterMuted
                    animate: root.animate
                    wheelStep: AudioDeckService.wheelStep
                    enabled: AudioDeckService.master !== null
                    onMoved: newValue => AudioDeckService.setVolume(AudioDeckService.master, newValue)
                }

                AudioDeckSpectrum {
                    width: parent.width
                    height: root.compact ? 16 : 20
                    maxBarHeight: height
                    minBarHeight: 2
                    barCount: 24
                    gap: 2
                    stretch: true
                    active: AudioDeckService.master !== null && !AudioDeckService.masterMuted
                    enabled: AudioDeckService.visualizer
                    visible: AudioDeckService.visualizer && AudioDeckService.master !== null
                    barColor: Theme.withAlpha(Theme.primary, 0.85)
                }
            }
        }
    }

    // Section tabs ---------------------------------------------------------
    Row {
        width: parent.width
        spacing: Theme.spacingXS

        Repeater {
            model: root.tabs

            delegate: Rectangle {
                id: chip
                required property var modelData

                width: tabLabel.implicitWidth + Theme.spacingM * 2
                height: 30
                radius: height / 2
                color: root.tab === chip.modelData.key ? Theme.primary : (chipHover.containsMouse ? Theme.withAlpha(Theme.primary, 0.10) : "transparent")

                Behavior on color {
                    ColorAnimation { duration: root.animate ? 140 : 0 }
                }

                StyledText {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: chip.modelData.label + "  " + chip.modelData.count
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: root.tab === chip.modelData.key ? Font.DemiBold : Font.Medium
                    color: root.tab === chip.modelData.key ? Theme.onPrimary : Theme.surfaceVariantText
                }

                MouseArea {
                    id: chipHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tab = chip.modelData.key
                }
            }
        }
    }

    // Mixable rows ---------------------------------------------------------
    Item {
        width: parent.width
        height: root.listHeight

        Flickable {
            id: listFlick
            anchors.fill: parent
            contentHeight: listColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: listColumn
                width: Math.max(0, listFlick.width - 4)
                spacing: 2

                Repeater {
                    model: root.currentNodes

                    delegate: AudioDeckControlRow {
                        required property var modelData

                        width: listColumn.width
                        node: modelData
                        iconValue: root.rowIcon(modelData)
                        title: root.rowTitle(modelData)
                        subtitle: root.rowSubtitle(modelData)
                        isDevice: !modelData.isStream
                        inputDevice: !modelData.isSink
                        isDefault: AudioDeckService.isDefaultDevice(modelData)
                        maxValue: AudioDeckService.maxVolume
                        onVolumeMoved: newValue => AudioDeckService.setVolume(modelData, newValue)
                        onMuteToggled: AudioDeckService.toggleMute(modelData)
                        onDefaultRequested: AudioDeckService.setDefault(modelData)
                    }
                }

                Item {
                    width: parent.width
                    height: 4
                }
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - Theme.spacingXL
            spacing: Theme.spacingS
            visible: root.currentNodes.length === 0

            DIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.tab === "apps" ? "graphic_eq" : (root.tab === "output" ? "speaker" : "mic")
                size: 28
                color: Theme.withAlpha(Theme.primary, 0.6)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.emptyTitle
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.emptyHint
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
