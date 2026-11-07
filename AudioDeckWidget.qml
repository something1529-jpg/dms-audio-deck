import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "."

PluginComponent {
    id: root
    layerNamespacePlugin: "audio-deck"

    readonly property string masterIcon: AudioDeckService.masterMuted ? "volume_off" : (AudioDeckService.masterPercent <= 0 ? "volume_mute" : (AudioDeckService.masterPercent <= 40 ? "volume_down" : "volume_up"))

    Component.onCompleted: AudioDeckService.syncSettings(pluginData)
    onPluginDataChanged: AudioDeckService.syncSettings(pluginData)

    // Control Center tile --------------------------------------------------
    ccWidgetIcon: AudioDeckService.master ? root.masterIcon : "speaker"
    ccWidgetPrimaryText: "Audio Deck"
    ccWidgetSecondaryText: {
        if (!AudioDeckService.ready)
            return "Waiting for PipeWire";
        if (!AudioDeckService.master)
            return "No output device";
        const apps = AudioDeckService.streams.length;
        return AudioDeckService.masterPercent + "%" + (apps > 0 ? " · " + apps + (apps === 1 ? " app" : " apps") : "");
    }
    ccWidgetIsActive: AudioDeckService.master !== null && !AudioDeckService.masterMuted
    ccWidgetIsToggle: false
    ccExpandedMinimumHeight: 78
    ccDetailHeight: 470

    onCcWidgetToggled: AudioDeckService.toggleMute(AudioDeckService.master)

    ccExpandedContent: Component {
        Column {
            width: parent ? parent.width : 300
            spacing: Theme.spacingXS

            Item {
                width: parent.width
                height: 18

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Volume"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: AudioDeckService.masterPercent + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: AudioDeckService.masterMuted ? Theme.surfaceVariantText : Theme.primary
                }
            }

            AudioDeckVolumeBar {
                width: parent.width
                value: AudioDeckService.masterPercent
                maxValue: AudioDeckService.maxVolume
                muted: AudioDeckService.masterMuted
                animate: AudioDeckService.animations
                wheelStep: AudioDeckService.wheelStep
                enabled: AudioDeckService.master !== null
                onMoved: newValue => AudioDeckService.setVolume(AudioDeckService.master, newValue)
            }
        }
    }

    ccDetailContent: Component {
        Rectangle {
            color: Theme.cardSurface
            radius: Theme.cornerRadius
            border.width: 1
            border.color: Theme.withAlpha(Theme.outline, 0.14)

            AudioDeckMixer {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                compact: true
                listHeight: 270
            }
        }
    }

    // Bar pills ------------------------------------------------------------
    horizontalBarPill: Component {
        Item {
            implicitWidth: pillRow.implicitWidth + Theme.spacingXS * 2
            implicitHeight: pillRow.implicitHeight + 4

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 3

                Item {
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    AudioDeckRing {
                        anchors.fill: parent
                        value: AudioDeckService.masterPercent
                        maxValue: AudioDeckService.maxVolume
                        strokeWidth: 2
                        animated: AudioDeckService.animations
                        ringColor: AudioDeckService.masterMuted ? Theme.surfaceVariantText : Theme.primary
                    }

                    DIcon {
                        anchors.centerIn: parent
                        name: root.masterIcon
                        size: 13
                        color: AudioDeckService.masterMuted ? Theme.surfaceVariantText : (AudioDeckService.master ? Theme.primary : Theme.surfaceVariantText)
                    }
                }

                Item {
                    width: 18
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: AudioDeckService.visualizer && !AudioDeckService.masterMuted && AudioDeckService.master !== null

                    AudioDeckSpectrum {
                        anchors.centerIn: parent
                        width: 18
                        height: 14
                        barCount: 5
                        barWidth: 2
                        gap: 2
                        maxBarHeight: 14
                        minBarHeight: 2
                        active: !AudioDeckService.masterMuted && AudioDeckService.master !== null
                        enabled: AudioDeckService.visualizer
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: AudioDeckService.showPercent
                    text: AudioDeckService.masterPercent + "%"
                    font.pixelSize: Theme.fontSizeSmall - 2
                    font.weight: Font.Medium
                    color: AudioDeckService.masterMuted ? Theme.surfaceVariantText : Theme.surfaceText
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AudioDeckService.toggleMute(AudioDeckService.master)
                onWheel: wheel => AudioDeckService.adjustVolume(AudioDeckService.master, wheel.angleDelta.y > 0 ? AudioDeckService.wheelStep : -AudioDeckService.wheelStep)
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: 24
            implicitHeight: verticalColumn.implicitHeight + 2

            Column {
                id: verticalColumn
                anchors.centerIn: parent
                spacing: 1

                Item {
                    width: 20
                    height: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    AudioDeckRing {
                        anchors.fill: parent
                        value: AudioDeckService.masterPercent
                        maxValue: AudioDeckService.maxVolume
                        strokeWidth: 2
                        animated: AudioDeckService.animations
                        ringColor: AudioDeckService.masterMuted ? Theme.surfaceVariantText : Theme.primary
                    }

                    DIcon {
                        anchors.centerIn: parent
                        name: root.masterIcon
                        size: 13
                        color: AudioDeckService.masterMuted ? Theme.surfaceVariantText : Theme.primary
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: AudioDeckService.showPercent
                    text: AudioDeckService.masterPercent
                    font.pixelSize: Theme.fontSizeSmall - 2
                    font.weight: Font.Medium
                    color: AudioDeckService.masterMuted ? Theme.surfaceVariantText : Theme.primary
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AudioDeckService.toggleMute(AudioDeckService.master)
                onWheel: wheel => AudioDeckService.adjustVolume(AudioDeckService.master, wheel.angleDelta.y > 0 ? AudioDeckService.wheelStep : -AudioDeckService.wheelStep)
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Audio Deck"
            detailsText: AudioDeckService.ready ? (AudioDeckService.master ? AudioDeckService.displayName(AudioDeckService.master) : "No output device") : "Waiting for PipeWire"
            showCloseButton: true

            AudioDeckMixer {
                width: parent.width
                compact: false
                listHeight: 300
            }
        }
    }

    popoutWidth: 400
    popoutHeight: 600
}
