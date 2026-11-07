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

            Item {
                id: defaultButton
                visible: root.isDevice
                width: Theme.iconSize
                height: Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter

                DIcon {
                    anchors.centerIn: parent
                    name: root.isDefault ? "radio_button_checked" : "radio_button_unchecked"
                    size: Theme.iconSizeSmall
                    color: root.isDefault ? Theme.primary : Theme.surfaceVariantText
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.defaultRequested()
                }
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

            Item {
                id: muteButton
                width: Theme.iconSize + Theme.spacingXXS
                height: width
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: muteHover.hovered ? Theme.withAlpha(root.muted ? Theme.error : Theme.primary, 0.14) : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }
                }

                DIcon {
                    anchors.centerIn: parent
                    name: root.muted ? "volume_off" : (root.inputDevice ? "mic" : "volume_up")
                    size: Theme.iconSizeSmall
                    color: root.muted ? Theme.error : Theme.surfaceVariantText
                }

                MouseArea {
                    id: muteHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.muteToggled()
                }
            }
        }

        AudioDeckVolumeBar {
            width: parent.width
            value: root.percent
            maxValue: root.maxValue
            muted: root.muted
            animate: AudioDeckService.animations
            wheelStep: AudioDeckService.wheelStep
            enabled: root.audio !== null
            onMoved: newValue => root.volumeMoved(newValue)
        }
    }
}
