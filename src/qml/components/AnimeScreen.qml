import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color: "#1E1E1E"

    property var anime: {}
    property var translations: {}
    property var streams: {}
    property var videoStreams: {}

    Component.onCompleted: {
        episodeDropdown.model = anime.episode_list.split(";")
    }

    Connections {
        target: animeBackend

        function onTranslations_got(results) {
            translations = results
            var data = []
            for (var i = 0; i < results.length; i++) {
                var item = results[i]
                var info = item.language + ", " + item.kind + ", " + item.quality_type + ", " + item.height + "p"
                var title = "[" + info + "] " + item.authors_string
                data.push(title)
            }
            sourceDropdown.model = data
            sourceDropdown.visible = true
        }

        function onStreams_got(results) {
            streams = results
            var data = []
            for (var i = 0; i < results.length; i++) {
                var item = results[i]
                var title = item.height + "p"
                data.push(title)
            }
            qualityDropdown.model = data
            qualityDropdown.visible = true
        }
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
                        var split = anime.episode_ids.split(";")
                        animeBackend.select_episode(split[value])
                    }
                }

                CustomDropdown {
                    id: sourceDropdown
                    visible: false
                    width: parent.width
                    placeholder: "Select Source"
                    onSelectionChangedIndex: function(value) {
                        var item = translations[value]
                        animeBackend.get_streams(item.id)
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
                    onSelectionChangedIndex: function(value) {
                        urlsContainer.visible = true
                        if (videoStreams !== undefined) {
                            videoUrlField.text = videoStreams[value].url
                        } else {
                            videoUrlField.text = streams[value].url
                        }
                        subsUrlField.text = streams[0].subs_url
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
                                id: videoUrlField
                                width: parent.width - copyButton.width - ugetButton.width - parent.spacing
                                height: parent.height
                                readOnly: true
                                color: "white"
                                Component.onCompleted: cursorPosition = 0
                                onTextChanged: cursorPosition = 0
                                background: Rectangle {
                                    color: "#333333"
                                    radius: 4
                                }
                            }

                            CustomButton {
                                id: copyButton
                                width: 80
                                height: parent.height
                                text: "Copy"
                                onClicked: {
                                    videoUrlField.selectAll()
                                    videoUrlField.copy()
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
                                id: subsUrlField
                                width: parent.width - copyButtonSubs.width - ugetButtonSubs.width - parent.spacing
                                height: parent.height
                                readOnly: true
                                color: "white"
                                background: Rectangle {
                                    color: "#333333"
                                    radius: 4
                                }
                            }

                            CustomButton {
                                id: copyButtonSubs
                                width: 80
                                height: parent.height
                                text: "Copy"
                                onClicked: {
                                    subsUrlField.selectAll()
                                    subsUrlField.copy()
                                }
                            }

                            CustomButton {
                                id: ugetButtonSubs
                                width: 80
                                height: parent.height
                                text: "UGet"
                            }
                        }

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
}
