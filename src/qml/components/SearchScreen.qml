import QtQuick
import QtQuick.Controls

Rectangle {
    property string searchQuery: ""
    color: "#1E1E1E"

    Connections {
        target: backend

        function onSearch_completed(results) {
            searchResultsModel.clear()
            for (var i = 0; i < results.length; i++) {
                searchResultsModel.append(results[i])
            }
        }

        function onSearch_error(errorMessage) {
            // Show error message
            console.error("Search error:", errorMessage)
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        Column {
            anchors.fill: parent
            spacing: 12

            // Header with back button and search query
            Rectangle {
                width: parent.width
                height: 36
                color: "transparent"

                Row {
                    width: parent.width
                    spacing: 12

                    CustomButton {
                        id: backButton
                        width: 100
                        height: 36
                        text: "← Back"
                        onClicked: stackView.pop()
                    }

                    TextField {
                        id: searchField
                        width: parent.width - backButton.width - searchButton.width - parent.spacing * 2
                        height: parent.height
                        text: searchQuery
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
                                searchQuery = text
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
                                searchQuery = searchScreenField.text
                            }
                        }
                    }
                }
            }

            // Search results list
            Row {
                width: parent.width
                height: parent.height - 96  // Account for header and bottom controls
                spacing: 12

                // Search results list
                Rectangle {
                    width: parent.width
                    height: parent.height
                    color: "#2A2A2A"
                    radius: 4

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 4
                        clip: true
                        model: ListModel {
                            id: searchResultsModel
                        }
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 140
                            color: mouseArea.containsMouse ? "#383838" : (index % 2 == 0 ? "#2A2A2A" : "#333333")

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: {
                                    onClicked: console.log("Selected anime:", title)
                                }

                                onEntered: {
                                    cursorShape = Qt.PointingHandCursor
                                }

                                onExited: {
                                    cursorShape = Qt.ArrowCursor
                                }
                            }

                            Row {
                                spacing: 10
                                padding: 10

                                Image {
                                    width: 120
                                    height: 120
                                    source: model.image_url
                                    fillMode: Image.PreserveAspectFit
                                }

                                Column {
                                    spacing: 5

                                    Text {
                                        text: model.title
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        text: `Episodes: ${model.episodes}`
                                        color: "white"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        text: `Type: ${model.h_type} | Year: ${model.year}`
                                        color: "white"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        text: `Score: ${model.score}`
                                        color: "white"
                                        font.pixelSize: 14
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom controls
            Rectangle {
                width: parent.width
                height: 36
                color: "transparent"

                Row {
                    anchors.left: parent.left
                    height: parent.height
                    spacing: 12

                    CustomButton {
                        width: 100
                        height: parent.height
                        text: "Filter"
                        onClicked: console.log("Filter clicked")
                    }

                    CustomButton {
                        width: 100
                        height: parent.height
                        text: "Sort"
                        onClicked: console.log("Sort clicked")
                    }
                }
            }
        }
    }
}
