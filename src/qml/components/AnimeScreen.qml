import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color: "#1E1E1E"

    property var anime: {}
    property var translations: {}

    property var streams: {}
    property var streamSelected: ""

    property var videoStreams: {}
    property var videoStreamSelected: ""

    property var qualitySelected: ""

    Component.onCompleted: {
        episodeDropdown.model = anime.episode_list.split(";")
        translations = undefined
        streams = undefined
        streamSelected = ""
        videoStreams = undefined
        videoStreamSelected = ""
        qualitySelected = ""
    }

    function populateQualityDropdown() {
        var current = videoStreams !== undefined ? videoStreams : streams
        var data = []
        for (var i = 0; i < current.length; i++) {
            var item = current[i]
            var title = item.height + "p"
            data.push(title)
        }
        qualityDropdown.model = data
        qualityDropdown.visible = true
    }

    Connections {
        target: animeBackend

        function onTranslations_got(results) {
            translations = results
            var data = []
            for (var i = 0; i < results.length; i++) {
                data.push(results[i].full_title)
            }
            sourceDropdown.model = data
            sourceDropdown.visible = true

            if (streamSelected !== "") {
                for (var i = 0; i < translations.length; i++) {
                    var item = translations[i]
                    if (item.full_title === streamSelected) {
                        sourceDropdown.changeSelection(i)
                        break
                    }
                }
                return
            }

            busyIndicator.running = false
        }

        function onStreams_got(results, isForOtherVideo) {
            if (!isForOtherVideo) {
                streams = results
            } else {
                videoStreams = results
            }

            populateQualityDropdown()

            if (!isForOtherVideo) {
                var data = ["Default"]
                for (var i = 0; i < translations.length; i++) {
                    data.push(translations[i].full_title)
                }
                videoSourceDropdown.model = data
                videoSourceDropdown.visible = true

                if (videoStreamSelected !== "") {
                    for (var i = 0; i < translations.length; i++) {
                        var item = translations[i]
                        if (item.full_title === videoStreamSelected) {
                            videoSourceDropdown.changeSelection(i + 1)
                            break
                        }
                    }
                    return
                }

                if (videoStreamSelected === "" && qualitySelected !== "") {
                    for (var i = 0; i < streams.length; i++) {
                        var item = streams[i]
                        if (item.height + "p" === qualitySelected) {
                            qualityDropdown.changeSelection(i)
                            break
                        }
                    }
                }
            } else {
                if (qualitySelected !== "") {
                    for (var i = 0; i < videoStreams.length; i++) {
                        var item = videoStreams[i]
                        if (item.height + "p" === qualitySelected) {
                            qualityDropdown.changeSelection(i)
                            break
                        }
                    }
                }
            }

            busyIndicator.running = false
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

                BusyIndicator {
                    id: busyIndicator
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    running: false
                    width: 30
                    height: 30
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
                        sourceDropdown.visible = false
                        videoSourceDropdown.visible = false
                        qualityDropdown.visible = false
                        urlsContainer.visible = false

                        busyIndicator.running = true

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
                        videoSourceDropdown.visible = false
                        qualityDropdown.visible = false
                        urlsContainer.visible = false

                        busyIndicator.running = true

                        var item = translations[value]
                        animeBackend.get_streams(item.id, false)
                        streamSelected = sourceDropdown.selectedValue
                    }
                }

                CustomDropdown {
                    id: videoSourceDropdown
                    visible: false
                    width: parent.width
                    placeholder: "Select Different Video Source"
                    onSelectionChangedIndex: function(value) {
                        qualityDropdown.visible = false
                        urlsContainer.visible = false

                        if (value === 0) {
                            videoStreams = streams
                            videoStreamSelected = ""
                            populateQualityDropdown()
                            return
                        } else {
                            videoStreamSelected = videoSourceDropdown.selectedValue
                        }

                        busyIndicator.running = true

                        var item = translations[value - 1]
                        animeBackend.get_streams(item.id, true)
                    }
                }

                CustomDropdown {
                    id: qualityDropdown
                    visible: false
                    width: parent.width
                    placeholder: "Select Quality"
                    onSelectionChangedIndex: function(value) {
                        urlsContainer.visible = true
                        ugetButton.enabled = true
                        ugetButton.opacity = 1
                        ugetButtonSubs.enabled = true
                        ugetButtonSubs.opacity = 1
                        mpvButton.enabled = true
                        mpvButton.opacity = 1
                        vlcButton.enabled = true
                        vlcButton.opacity = 1

                        videoUrlField.text = ""
                        subsUrlField.text = ""

                        if (videoStreams !== undefined) {
                            videoUrlField.text = videoStreams[value].url
                        } else {
                            videoUrlField.text = streams[value].url
                        }
                        var subs = streams[0].subs_url
                        if (subs !== undefined) {
                            subsRow.visible = true
                            subsUrlField.text = streams[0].subs_url
                        } else {
                            subsRow.visible = false
                        }

                        qualitySelected = qualityDropdown.selectedValue
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
                                width: parent.width - copyButton.width - ugetButton.width - parent.spacing * 2
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
                                onClicked: {
                                    var url = videoUrlField.text
                                    var title = anime.title + " — " + episodeDropdown.selectedValue
                                    var episodesTotal = episodeDropdown.model.length
                                    animeBackend.launch_uget(url, title, episodesTotal, false)
                                    ugetButton.enabled = false
                                    ugetButton.opacity = 0.5
                                }
                            }
                        }

                        // Subtitles URL row
                        Row {
                            id: subsRow
                            width: parent.width
                            height: 36
                            spacing: 8

                            TextField {
                                id: subsUrlField
                                width: parent.width - copyButtonSubs.width - ugetButtonSubs.width - parent.spacing * 2
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
                                onClicked: {
                                    var url = subsUrlField.text
                                    var title = anime.title + " — " + episodeDropdown.selectedValue
                                    var episodesTotal = episodeDropdown.model.length
                                    animeBackend.launch_uget(url, title, episodesTotal, true)
                                    ugetButtonSubs.enabled = false
                                    ugetButtonSubs.opacity = 0.5
                                }
                            }
                        }

                        Row {
                            spacing: 8
                            height: 36

                            CustomButton {
                                id: mpvButton
                                width: 80
                                height: parent.height
                                text: "mpv"
                                onClicked: {
                                    var url = videoUrlField.text
                                    var subs = subsUrlField.text
                                    var title = anime.title + " — " + episodeDropdown.selectedValue
                                    animeBackend.launch_mpv(url, subs, title)
                                    mpvButton.enabled = false
                                    mpvButton.opacity = 0.5
                                }
                            }

                            CustomButton {
                                id: vlcButton
                                width: 80
                                height: parent.height
                                text: "vlc"
                                visible: false
                            }

                            CustomButton {
                                id: ugetAllButton
                                width: 80
                                height: parent.height
                                text: "UGet All"
                                onClicked: {
                                    ugetButton.clicked()
                                    ugetButtonSubs.clicked()
                                    ugetAllButton.enabled = false
                                    ugetAllButton.opacity = 0.5
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
