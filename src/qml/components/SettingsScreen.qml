import QtQuick
import QtQuick.Controls

Rectangle {
    color: "#1E1E1E"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        Column {
            anchors.fill: parent
            spacing: 12

            // Header with back button
            Rectangle {
                width: parent.width
                height: 36
                color: "transparent"

                Row {
                    spacing: 12

                    CustomButton {
                        id: searchButton
                        width: 100
                        height: 36
                        text: "← Back"
                        onClicked: stackView.pop()
                    }

                    Text {
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: "Settings"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                    }
                }
            }

            // MPV path setting
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "Path to MPV binary"
                    color: "white"
                    font.pixelSize: 14
                }

                Row {
                    width: parent.width
                    spacing: 12
                    height: 36

                    TextField {
                        id: mpvPathField
                        width: parent.width - parent.spacing
                        height: parent.height
                        text: "/usr/bin/mpv"
                        background: Rectangle {
                            color: "#333333"
                            radius: 4
                        }
                        color: "white"
                        font.pixelSize: 14
                    }
                }
            }

            // UGet path setting
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "Path to UGet binary"
                    color: "white"
                    font.pixelSize: 14
                }

                Row {
                    width: parent.width
                    spacing: 12
                    height: 36

                    TextField {
                        id: ugetPathField
                        width: parent.width - parent.spacing
                        height: parent.height
                        text: "/usr/bin/uget-gtk"
                        background: Rectangle {
                            color: "#333333"
                            radius: 4
                        }
                        color: "white"
                        font.pixelSize: 14
                    }
                }
            }

        }
    }
}
