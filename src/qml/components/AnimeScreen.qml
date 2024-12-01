import QtQuick
import QtQuick.Controls
import Themes

Rectangle {
    id: root
    color: Themes.currentTheme.background

    property var anime: {}
    property var translations: {}

    property var streams: {}
    property var streamSelected: ""

    property var videoStreams: {}
    property var videoStreamSelected: ""

    property var qualitySelected: ""

    property string animeStatus: "Not in List"
    property int episodesWatched: 0
    property int animeScore: 0
    property int rewatchCount: 0

    Component.onCompleted: {
        if (anime.episode_list === undefined) {
            busyIndicator.running = true
            episodeDropdown.visible = false
            animeBackend.get_episodes(anime.id)
        } else {
            episodeDropdown.model = anime.episode_list.split(";")
        }
        translations = undefined
        streams = undefined
        streamSelected = anime.translation || ""
        videoStreams = undefined
        videoStreamSelected = anime.alt_video || ""
        qualitySelected = anime.quality || ""
        if (anime.episode) {
            for (var i = 0; i < episodeDropdown.model.length; i++) {
                if (episodeDropdown.model[i] === anime.episode) {
                    if (anime.next_episode && i < episodeDropdown.model.length - 1) {
                        episodeDropdown.changeSelection(i + 1)
                    } else {
                        episodeDropdown.changeSelection(i)
                    }
                    break
                }
            }
        }
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

        function onEpisodes_got(result) {
            anime.episode_list = result.episode_list
            anime.episode_ids = result.episode_ids
            episodeDropdown.model = result.episode_list.split(";")
            episodeDropdown.visible = true
            if (anime.episode) {
                for (var i = 0; i < episodeDropdown.model.length; i++) {
                    if (episodeDropdown.model[i] === anime.episode) {
                        if (anime.next_episode && i < episodeDropdown.model.length - 1) {
                            episodeDropdown.changeSelection(i + 1)
                        } else {
                            episodeDropdown.changeSelection(i)
                        }
                        return
                    }
                }
            }

            busyIndicator.running = false
        }

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
                        return
                    }
                }
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

        function onSubtitle_fonts_got(results) {
            var formatted = "Fonts availability (during application startup): <br><br>" + results.map(fontName => {
                var isAvailable = Qt.fontFamilies().includes(fontName)

                return isAvailable ?
                    `\u2714 <b>${fontName}</b>` :
                    `\u274C ${fontName}`
            }).join("<br>")

            subsUrlField.ToolTip.text = formatted
            subsUrlField.ToolTip.textFormat = Text.RichText
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        Column {
            anchors.fill: parent
            spacing: 12

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

                    cache: true
                    asynchronous: true
                }

                Column {
                    width: parent.width - coverImage.width
                    height: parent.height
                    spacing: 12

                    ScrollView {
                        width: parent.width - parent.spacing
                        height: parent.height - trackingControls.height - parent.spacing
                        clip: true

                        Column {
                            width: parent.width
                            height: parent.height
                            spacing: 8

                            Text {
                                text: anime.title
                                color: Themes.currentTheme.text
                                font.pixelSize: 24
                                font.bold: true
                                width: parent.width
                            }

                            Text {
                                text: anime.description
                                color: Themes.currentTheme.secondaryText
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    Rectangle {
                        id: trackingControls
                        width: parent.width
                        height: 36
                        color: "transparent"

                        Row {
                            spacing: 12
                            height: parent.height

                            CustomDropdown {
                                id: statusDropdown
                                width: 160
                                height: parent.height
                                model: ["Not in List", "Completed", "Watching", "On-Hold", "Dropped", "Plan to Watch"]
                                placeholder: "Status"
                                onSelectionChangedIndex: function(value) {
                                    animeStatus = statusDropdown.selectedValue
                                }
                            }

                            Row {
                                spacing: 6
                                height: parent.height

                                Text {
                                    text: "Episodes"
                                    color: Themes.currentTheme.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                CustomSpinBox {
                                    id: episodesSpinBox
                                    value: 0
                                    from: 0
                                    to: anime.total_episodes
                                    height: parent.height
                                    width: 80
                                }
                            }

                            Row {
                                spacing: 6
                                height: parent.height

                                Text {
                                    text: "Score"
                                    color: Themes.currentTheme.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                CustomSpinBox {
                                    id: scoreSpinBox
                                    value: 0
                                    from: 0
                                    to: 10
                                    height: parent.height
                                    width: 60
                                }
                            }

                            Row {
                                spacing: 6
                                height: parent.height

                                Text {
                                    text: "Rewatches"
                                    color: Themes.currentTheme.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                CustomSpinBox {
                                    id: rewatchesSpinBox
                                    value: 0
                                    from: 0
                                    to: 999
                                    height: parent.height
                                    width: 60
                                }
                            }

                            CustomButton {
                                text: "Apply"
                                width: 80
                                height: parent.height
                                enabled: false
                                textColor: Themes.currentTheme.colorfulText
                                baseColor: Themes.currentTheme.applyBase
                                hoverColor: Themes.currentTheme.applyHover
                                pressColor: Themes.currentTheme.applyPress
                            }

                            CustomButton {
                                text: "Cancel"
                                width: 80
                                height: parent.height
                                enabled: false
                                textColor: Themes.currentTheme.colorfulText
                                baseColor: Themes.currentTheme.cancelBase
                                hoverColor: Themes.currentTheme.cancelHover
                                pressColor: Themes.currentTheme.cancelPress
                            }
                        }
                    }
                }
            }

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
                        ugetButtonSubs.enabled = true
                        ugetAllButton.enabled = true
                        mpvButton.enabled = true
                        vlcButton.enabled = true

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
                            subsUrlField.text = subs
                            animeBackend.get_subtitle_fonts(subs)
                        } else {
                            subsRow.visible = false
                        }

                        qualitySelected = qualityDropdown.selectedValue

                        databaseBackend.update(anime.id, {
                            episode: episodeDropdown.selectedValue,
                            translation: streamSelected,
                            alt_video: videoStreamSelected,
                            quality: qualitySelected
                        })
                    }
                }

                Rectangle {
                    id: urlsContainer
                    visible: false
                    width: parent.width
                    height: urlsColumn.height + 16
                    color: Themes.currentTheme.secondaryBackground
                    radius: 4

                    Column {
                        id: urlsColumn
                        anchors.margins: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Row {
                            width: parent.width
                            height: 36
                            spacing: 8

                            TextField {
                                id: videoUrlField
                                width: parent.width - copyButton.width - ugetButton.width - parent.spacing * 2
                                height: parent.height
                                readOnly: true
                                color: Themes.currentTheme.text
                                Component.onCompleted: cursorPosition = 0
                                onTextChanged: cursorPosition = 0
                                background: Rectangle {
                                    color: Themes.currentTheme.inputBackground
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
                                text: "uGet"
                                onClicked: {
                                    var url = videoUrlField.text
                                    var title = anime.title + " — " + episodeDropdown.selectedValue
                                    var episodesTotal = episodeDropdown.model.length
                                    animeBackend.launch_uget(url, title, episodesTotal, false)
                                    ugetButton.enabled = false
                                }
                            }
                        }

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
                                color: Themes.currentTheme.text
                                background: Rectangle {
                                    color: Themes.currentTheme.inputBackground
                                    radius: 4
                                }

                                ToolTip.visible: subsUrlMouseArea.containsMouse
                                ToolTip.delay: 1000

                                MouseArea {
                                    id: subsUrlMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: Qt.IBeamCursor
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
                                text: "uGet"
                                onClicked: {
                                    var url = subsUrlField.text
                                    var title = anime.title + " — " + episodeDropdown.selectedValue
                                    var episodesTotal = episodeDropdown.model.length
                                    animeBackend.launch_uget(url, title, episodesTotal, true)
                                    ugetButtonSubs.enabled = false
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
                                Timer {
                                    id: mpvTimer
                                    interval: 5000
                                    repeat: false
                                    onTriggered: mpvButton.enabled = true
                                }
                                onClicked: {
                                    var url = videoUrlField.text
                                    var subs = subsUrlField.text
                                    var title = anime.title + " — " + episodeDropdown.selectedValue
                                    animeBackend.launch_mpv(url, subs, title)
                                    mpvButton.enabled = false
                                    mpvTimer.start()
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
                                width: 120
                                height: parent.height
                                text: "uGet Episode"
                                onClicked: {
                                    ugetButton.clicked()
                                    ugetButtonSubs.clicked()
                                    ugetAllButton.enabled = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
