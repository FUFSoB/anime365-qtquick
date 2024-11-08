import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color: "#1E1E1E"

    property var anime: {}

    Component.onCompleted: {
        episodeDropdown.model = anime.episode_list.split(";")
    }

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

                ScrollView {
                    width: parent.width - coverImage.width - parent.spacing
                    height: parent.height
                    clip: true

                    Column {
                        width: parent.width
                        height: parent.height
                        spacing: 8

                        Text {
                            text: anime.title
                            color: "white"
                            font.pixelSize: 24
                            font.bold: true
                            width: parent.width
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
            }

            // Controls section
            Column {
                width: parent.width
                spacing: 12

                CustomDropdown {
                    id: episodeDropdown
                    width: parent.width
                    placeholder: "Select Episode"
                    onSelectionChangedIndex: function(value) {
                        console.log("Selected episode index:", value)
                        var split = anime.episode_ids.split(";")
                        animeBackend.select_episode(split[value])
                        sourceTypeDropdown.visible = true
                    }
                }

                CustomDropdown {
                    id: sourceTypeDropdown
                    visible: false
                    width: parent.width
                    placeholder: "Select Source Language and Type"
                    onSelectionChanged: function(value) {
                    }
                }

                CustomDropdown {
                    id: sourceDropdown
                    visible: false
                    width: parent.width
                    placeholder: "Select Source"
                    onSelectionChanged: function(value) {
                    }
                }

                CustomDropdown {
                    id: videoSourceDropdown
                    visible: false
                    width: parent.width
                    placeholder: "Select Different Video Source"
                    onSelectionChanged: function(value) {
                    }
                }

                CustomDropdown {
                    id: qualityDropdown
                    visible: false
                    width: parent.width
                    placeholder: "Select Quality"
                    onSelectionChanged: function(value) {
                    }
                }

                // Video URLs section
                Rectangle {
                    id: urlsContainer
                    visible: false
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
                                width: parent.width - ugetButton.width - parent.spacing * 2
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
                                width: parent.width - ugetButton2.width - parent.spacing * 2
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
                                id: ugetButton2
                                width: 80
                                height: parent.height
                                text: "UGet"
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
}
