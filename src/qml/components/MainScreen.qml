import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "#1E1E1E"

    Rectangle {
        id: mainContent
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        // Top controls column
        Column {
            id: topControls
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 12

            Row {
                width: parent.width
                height: 36
                spacing: 12

                TextField {
                    id: searchField
                    width: parent.width - searchButton.width - parent.spacing
                    height: parent.height
                    placeholderText: "Search anime"
                    background: Rectangle {
                        color: "#333333"
                        radius: 4
                    }
                    color: "white"
                    font.pixelSize: 14
                    onAccepted: {
                        if (text.trim() !== "") {
                            backend.perform_search(searchField.text.trim())
                            stackView.push(searchScreen, { searchQuery: text })
                        }
                    }
                }

                CustomButton {
                    id: searchButton
                    width: 100
                    height: parent.height
                    text: "Search"
                    onClicked: {
                        if (searchField.text.trim() !== "") {
                            backend.perform_search(searchField.text.trim())
                            stackView.push(searchScreen, { searchQuery: searchField.text })
                        }
                    }
                }
            }

            CustomButton {
                width: parent.width
                height: 36
                text: "Tracker List"
                onClicked: console.log("Tracker List clicked")
            }


            Row {
                width: parent.width
                height: 36
                spacing: 12

                CustomButton {
                    width: (parent.width - parent.spacing) / 2
                    height: 36
                    text: "Open UGet"
                    onClicked: backend.open_uget()
                }

                CustomButton {
                    width: (parent.width - parent.spacing) / 2
                    height: 36
                    text: "Settings"
                    onClicked: stackView.push(settingsScreen)
                }
            }
        }

        Row {
            anchors.top: topControls.bottom
            anchors.bottom: bottomControls.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 12

            Rectangle {
                width: parent.width * 0.6
                height: parent.height
                color: "#2A2A2A"
                radius: 4

                ListView {
                    id: animeList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    model: ListModel {
                        ListElement { title: "History entry 1" }
                        ListElement { title: "History entry 2" }
                        ListElement { title: "History entry 3" }
                        ListElement { title: "History entry 4" }
                        ListElement { title: "History entry 5" }
                    }
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 36
                        color: mouseArea.containsMouse ? "#383838" : (index % 2 == 0 ? "#2A2A2A" : "#333333")

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            text: title
                            color: "white"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: console.log("Selected anime:", title)
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width * 0.4
                height: parent.height
                color: "#2A2A2A"
                radius: 4

                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    fillMode: Image.PreserveAspectFit
                }
            }
        }

        Rectangle {
            id: bottomControls
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            color: "transparent"

            Row {
                anchors.fill: parent
                spacing: 12

                Row {
                    id: buttonRow
                    height: parent.height
                    spacing: 12

                    CustomButton {
                        width: 100
                        height: parent.height
                        text: "Remove"
                        baseColor: "#FF3333"
                        hoverColor: "#FF4444"
                        pressColor: "#FF5555"
                        onClicked: console.log("Remove clicked")
                    }

                    CustomButton {
                        width: 100
                        height: parent.height
                        text: "Select"
                        onClicked: console.log("Select clicked")
                    }

                    CustomButton {
                        width: 120
                        height: parent.height
                        text: "Next Episode"
                        onClicked: console.log("Next Episode clicked")
                    }
                }

                // Separator
                Item {
                    width: parent.width - episodeText.width - buttonRow.width - parent.spacing * 2
                    height: parent.height
                }

                Text {
                    id: episodeText
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: "Viewed 1 / 24 episodes — [en, sub, bd, 1080p] Doki"
                    color: "white"
                    font.pixelSize: 14
                }
            }
        }
    }
}
