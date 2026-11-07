import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import "."

// One mixable row: app playback, app recording, output device or input device.
// Every control talks to PipeWire through AudioDeckService.
Item {
    id: root

    property var node: null
    property string iconValue: ""
    property string title: ""
    property string subtitle: ""
    property bool isDevice: false
    property bool inputDevice: false
    property bool isDefault: false
    property int maxValue: 100

    signal volumeMoved(real newValue)
    signal muteToggled()
    signal defaultRequested()

    readonly property var audio: node?.audio ?? null
    readonly property int percent: Math.round((audio?.volume ?? 0) * 100)
    readonly property bool muted: audio?.muted ?? false
    readonly property bool loud: percent > 100

    implicitHeight: body.implicitHeight + Theme.spacingS * 2

    HoverHandler { id: rowHover }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: rowHover.hovered ? Theme.withAlpha(Theme.primary, 0.06) : "transparent"

        Behavior on color {
            enabled: AudioDeckService.motion
            ColorAnimation { duration: 140 }
        }
    }

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        spacing: Theme.spacingXS

        Row {
            id: header
            width: parent.width
            spacing: Theme.spacingS

            Rectangle {
                id: iconBox
                width: Theme.iconSize + Theme.spacingXS
                height: width
                radius: Theme.cornerRadiusS
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.withAlpha(Theme.primary, root.audio && !root.muted ? 0.14 : 0.05)

                Behavior on color {
                    enabled: AudioDeckService.motion
                    ColorAnimation { duration: 160 }
                }

                DIcon {
                    anchors.centerIn: parent
                    visible: root.iconValue.startsWith("material:")
                    name: root.iconValue.startsWith("material:") ? root.iconValue.substring(9) : "graphic_eq"
                    size: Theme.iconSizeSmall
                    color: root.muted ? Theme.surfaceVariantText : Theme.primary
                }

                AppIconRenderer {
                    anchors.centerIn: parent
                    visible: !root.iconValue.startsWith("material:")
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    iconSize: Theme.iconSizeMedium
                    iconValue: root.iconValue
                    fallbackText: root.title.length > 0 ? root.title.charAt(0).toUpperCase() : "A"
                }
            }

            Column {
                id: labelColumn
                width: Math.max(0, header.width - iconBox.width - (root.isDevice ? defaultButton.width : 0) - percentBox.width - muteButton.width - header.spacing * 4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXXS / 2

                StyledText {
                    width: parent.width
                    text: root.title
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    width: parent.width
                    text: root.subtitle
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.muted ? Theme.withAlpha(Theme.surfaceVariantText, 0.8) : Theme.surfaceVariantText
                }
            }

            DIconButton {
                id: defaultButton
                visible: root.isDevice
                width: Theme.iconSize
                height: Theme.iconSize
                buttonSize: Theme.iconSize
                iconSize: Theme.iconSizeSmall
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.audio !== null
                iconName: root.isDefault ? "radio_button_checked" : "radio_button_unchecked"
                iconColor: root.isDefault ? Theme.primary : Theme.surfaceVariantText
                tooltipText: root.isDefault ? "Default device" : "Set as default device"
                onClicked: root.defaultRequested()
            }

            Item {
                id: percentBox
                width: Theme.iconSize + Theme.spacingL
                height: Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.percent + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.muted ? Theme.surfaceVariantText : (root.loud ? Theme.warning : Theme.primary)
                }
            }

            DIconButton {
                id: muteButton
                width: Theme.iconSize + Theme.spacingXXS
                height: width
                buttonSize: width
                iconSize: Theme.iconSizeSmall
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.audio !== null
                iconName: root.muted ? "volume_off" : (root.inputDevice ? "mic" : "volume_up")
                iconColor: root.muted ? Theme.error : Theme.surfaceVariantText
                tooltipText: root.muted ? "Unmute" : "Mute"
                onClicked: root.muteToggled()
            }
        }

        AudioDeckVolumeBar {
            width: parent.width
            value: root.percent
            maxValue: root.maxValue
            muted: root.muted
            wheelStep: AudioDeckService.wheelStep
            enabled: root.audio !== null
            onMoved: newValue => root.volumeMoved(newValue)
        }
    }
}
