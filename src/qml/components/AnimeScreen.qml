import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color: "#1E1E1E"

    property var anime: {}

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        Column {
            anchors.fill: parent
            spacing: 12

            // Header
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
                }
            }

            // Image and title section
            Row {
                width: parent.width
                height: 200
                spacing: 12

                Image {
                    id: coverImage
                    width: 140
                    height: parent.height
                    source: anime.image_url
                    fillMode: Image.PreserveAspectFit
                }

                Column {
                    width: parent.width - coverImage.width - parent.spacing
                    height: parent.height
                    spacing: 8

                    Text {
                        text: anime.title
                        color: "white"
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Text {
                        text: anime.description
                        color: "#CCCCCC"
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            // Controls section
            Column {
                width: parent.width
                spacing: 12

                CustomDropdown {
                    id: episodeDropdown
                    width: parent.width
                    placeholder: "Select Episode"
                    model: ["Episode 1", "Episode 2", "Episode 3", "Episode 4", "Episode 5", "Episode 6", "Episode 7", "Episode 8", "Episode 9", "Episode 10", "Episode 11", "Episode 12", "Episode 13", "Episode 14", "Episode 15", "Episode 16", "Episode 17", "Episode 18", "Episode 19", "Episode 20", "Episode 21", "Episode 22", "Episode 23", "Episode 24", "Episode 25", "Episode 26", "Episode 27", "Episode 28", "Episode 29", "Episode 30", "Episode 31", "Episode 32", "Episode 33", "Episode 34", "Episode 35", "Episode 36", "Episode 37", "Episode 38", "Episode 39", "Episode 40", "Episode 41", "Episode 42", "Episode 43", "Episode 44", "Episode 45", "Episode 46", "Episode 47", "Episode 48", "Episode 49", "Episode 50"]
                    onSelectionChanged: function(value) {
                        // Handle episode selection
                    }
                }

                CustomDropdown {
                    id: qualityDropdown
                    width: parent.width
                    placeholder: "Select Quality"
                    model: ["1080p", "720p", "480p"]
                    onSelectionChanged: function(value) {
                        // Handle quality selection
                    }
                }

                CustomDropdown {
                    id: sourceDropdown
                    width: parent.width
                    placeholder: "Select Video Source"
                    model: ["Source 1", "Source 2", "Source 3"]
                    onSelectionChanged: function(value) {
                        // Handle source selection
                    }
                }

                // Video URLs section
                Rectangle {
                    width: parent.width
                    height: urlsColumn.height + 16
                    color: "#2A2A2A"
                    radius: 4

                    Column {
                        id: urlsColumn
                        anchors.margins: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Video URL row
                        Row {
                            width: parent.width
                            height: 36
                            spacing: 8

                            TextField {
                                width: parent.width - dlButton.width - ugetButton.width - parent.spacing * 2
                                height: parent.height
                                text: "https://example.com/video"
                                readOnly: true
                                color: "white"
                                background: Rectangle {
                                    color: "#333333"
                                    radius: 4
                                }
                            }

                            CustomButton {
                                id: dlButton
                                width: 80
                                height: parent.height
                                text: "DL"
                            }

                            CustomButton {
                                id: ugetButton
                                width: 80
                                height: parent.height
                                text: "UGet"
                            }
                        }

                        // Subtitles URL row
                        Row {
                            width: parent.width
                            height: 36
                            spacing: 8

                            TextField {
                                width: parent.width - dlButton2.width - ugetButton2.width - parent.spacing * 2
                                height: parent.height
                                text: "https://example.com/subtitles"
                                readOnly: true
                                color: "white"
                                background: Rectangle {
                                    color: "#333333"
                                    radius: 4
                                }
                            }

                            CustomButton {
                                id: dlButton2
                                width: 80
                                height: parent.height
                                text: "DL"
                            }

                            CustomButton {
                                id: ugetButton2
                                width: 80
                                height: parent.height
                                text: "UGet"
                            }
                        }
                    }
                }

                // Stream buttons
                Row {
                    spacing: 8
                    height: 36

                    CustomButton {
                        width: 80
                        height: parent.height
                        text: "mpv"
                    }

                    CustomButton {
                        width: 80
                        height: parent.height
                        text: "vlc"
                    }
                }
            }
        }
    }
}
