import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: root
    objectName: "animeScreen"
    padding: 12
    focus: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_N) {
            // Next episode
            var idx = episodeDropdown.selectedIndex
            if (idx >= 0 && idx < episodeDropdown.model.length - 1) {
                episodeDropdown.changeSelection(idx + 1)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_P) {
            // Previous episode
            var idx = episodeDropdown.selectedIndex
            if (idx > 0) {
                episodeDropdown.changeSelection(idx - 1)
            }
            event.accepted = true
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Space) && urlsContainer.visible && mpvButton.enabled) {
            mpvButton.clicked()
            event.accepted = true
        }
    }

    property var anime: ({})
    property var translations: ({})

    property var streams: ({})
    property var streamSelected: ""

    property var videoStreams: ({})
    property var videoStreamSelected: ""

    property var qualitySelected: ""

    readonly property bool mpvAvailable: isAndroid || (settingsBackend && settingsBackend.is_valid_binary(settingsBackend.get("mpv_path")))
    readonly property bool vlcAvailable: isAndroid || (settingsBackend && settingsBackend.is_valid_binary(settingsBackend.get("vlc_path")))
    readonly property bool downloadAvailable: !isAndroid
    readonly property bool hasToken: settingsBackend && settingsBackend.get("anime365_token") !== ""

    property string localVideoPath: ""
    property string localSubsPath: ""
    property string localVideoMeta: ""  // info about local file quality/translation
    property string otherDownloadsInfo: ""  // "TeamName +N" for other-TL downloads
    property real episodeDownloadProgress: -1  // -1 = no active download
    property int episodeDownloadSpeed: 0
    property int episodeDownloaded: 0
    property int episodeDownloadTotal: 0

    function checkLocalFiles() {
        localVideoPath = ""
        localSubsPath = ""
        localVideoMeta = ""
        otherDownloadsInfo = ""
        if (!anime.title || !episodeDropdown.selectedValue) return

        var ep = episodeDropdown.selectedValue
        var result = downloaderBackend.find_downloaded_video(
            anime.title, ep, streamSelected, qualitySelected)

        if (!result || !result.path && !result.other_count) return

        // Build other-TL notification: "TeamName" or "TeamName +2"
        if (result.other_count > 0) {
            var info = result.other_first_tl || "other"
            if (result.other_count > 1)
                info += " +" + (result.other_count - 1)
            otherDownloadsInfo = info
        }

        if (result.path) {
            // Exact TL match found on disk
            if (result.lower_quality) {
                // Selected quality is higher than downloaded — prefer online stream
                localVideoMeta = "lower_quality:" + (result.quality || "?")
            } else {
                localVideoPath = result.path
                var notes = []
                if (result.higher_quality)
                    notes.push(result.quality + " > " + qualitySelected)
                else if (result.quality && result.quality !== qualitySelected)
                    notes.push(result.quality)
                localVideoMeta = notes.join(", ")
            }
        }
        // If path is empty (non-exact TL only), we just show the notification — no local playback

        localSubsPath = downloaderBackend.find_downloaded_subs(anime.title, ep, streamSelected)
    }

    Component.onCompleted: {
        if (!anime.episode_list) {
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

    function formatSize(bytes) {
        if (bytes <= 0) return ""
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(0) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec <= 0) return ""
        if (bytesPerSec < 1024) return bytesPerSec + " B/s"
        if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
    }

    Connections {
        target: downloaderBackend
        function onDownloads_updated(items) {
            if (!anime.title || !episodeDropdown.selectedValue) return
            var ep = episodeDropdown.selectedValue
            var title = anime.title + " \u2014 " + ep
            var episodesTotal = episodeDropdown.model ? episodeDropdown.model.length : 1
            var baseFile = animeBackend.title_to_filename(title, episodesTotal, "mp4")
            var baseStem = baseFile.substring(0, baseFile.lastIndexOf("."))
            episodeDownloadProgress = -1
            episodeDownloadSpeed = 0
            episodeDownloaded = 0
            episodeDownloadTotal = 0
            for (var i = 0; i < items.length; i++) {
                var fn = items[i].filename
                if (fn.startsWith(baseStem) && (fn.endsWith(".mp4") || fn.endsWith(".mkv") || fn.endsWith(".webm"))) {
                    if (items[i].status === "complete") {
                        checkLocalFiles()
                    } else if (items[i].status === "active" || items[i].status === "waiting") {
                        episodeDownloadProgress = items[i].progress
                        episodeDownloadSpeed = items[i].speed
                        episodeDownloaded = items[i].downloaded
                        episodeDownloadTotal = items[i].total_size
                    }
                    break
                }
            }
        }
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

        function onPlayback_finished(completed) {
            if (completed) {
                // Auto-advance to next episode
                var idx = episodeDropdown.selectedIndex
                if (idx >= 0 && idx < episodeDropdown.model.length - 1) {
                    episodeDropdown.changeSelection(idx + 1)
                }
            }
        }

        function onBatch_progress(current, total) {
            batchDownloadButton.batchCurrent = current
            batchDownloadButton.batchTotal = total
        }

        function onBatch_item_ready(item) {
            var title = anime.title + " \u2014 " + item.episode_name
            var ep = item.episode_name
            var episodesTotal = episodeDropdown.model ? episodeDropdown.model.length : 1
            var baseFilename = animeBackend.title_to_filename(title, episodesTotal, "mp4")
            var filename = downloaderBackend.resolve_filename(
                baseFilename, anime.title, ep,
                streamSelected, videoStreamSelected, "video")
            downloaderBackend.add_download(item.url, filename)
            downloaderBackend.record_meta(
                filename, anime.title, ep,
                streamSelected, videoStreamSelected, qualitySelected)
            if (item.subs_url) {
                var baseSubsFilename = animeBackend.title_to_filename(title, episodesTotal, "ass")
                var subsFilename = downloaderBackend.resolve_filename(
                    baseSubsFilename, anime.title, ep,
                    streamSelected, videoStreamSelected, "subs")
                downloaderBackend.add_download(item.subs_url, subsFilename)
                downloaderBackend.record_meta(
                    subsFilename, anime.title, ep,
                    streamSelected, videoStreamSelected, qualitySelected)
            }
        }

        function onBatch_complete() {
            batchDownloadButton.batchBusy = false
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledButton {
                text: "\u2190 Back"
                onClicked: stackView.pop()
            }

            Item { Layout.fillWidth: true }

            BusyIndicator {
                id: busyIndicator
                running: false
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.parent.width
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    spacing: 12

                    Image {
                        id: coverImage
                        Layout.preferredWidth: 140
                        Layout.fillHeight: true
                        source: imageCacheBackend.cache_image(anime.image_url)
                        fillMode: Image.PreserveAspectFit
                        cache: true
                        asynchronous: true
                        Connections {
                            target: imageCacheBackend
                            function onImage_downloaded(origUrl, localUrl) {
                                if (origUrl === anime.image_url)
                                    coverImage.source = localUrl
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ColumnLayout {
                                width: parent.width
                                spacing: 8

                                Label {
                                    text: anime.title
                                    font.pixelSize: 24
                                    font.bold: true
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Label {
                                    text: anime.description
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                    opacity: 0.7
                                }
                            }
                        }

                        // External site links
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: `<a href='${anime.anime365_url || ""}'>anime365</a>`
                                visible: (anime.anime365_url || "") !== ""
                                textFormat: Text.RichText
                                onLinkActivated: (url) => Qt.openUrlExternally(url)
                                HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                            }

                            Label {
                                text: `<a href='https://shikimori.io/animes/${anime.mal_id}'>Shikimori</a>`
                                visible: (anime.mal_id || 0) > 0
                                textFormat: Text.RichText
                                onLinkActivated: (url) => Qt.openUrlExternally(url)
                                HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                            }

                            Label {
                                text: `<a href='https://myanimelist.net/anime/${anime.mal_id}'>MAL</a>`
                                visible: (anime.mal_id || 0) > 0
                                textFormat: Text.RichText
                                onLinkActivated: (url) => Qt.openUrlExternally(url)
                                HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                            }

                            Label {
                                text: `<a href='https://anidb.net/anime/${anime.anidb_id}'>AniDB</a>`
                                visible: (anime.anidb_id || 0) > 0
                                textFormat: Text.RichText
                                onLinkActivated: (url) => Qt.openUrlExternally(url)
                                HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                            }

                            Label {
                                text: `<a href='http://www.world-art.ru/animation/animation.php?id=${anime.world_art_id}'>World Art</a>`
                                visible: (anime.world_art_id || 0) > 0
                                textFormat: Text.RichText
                                onLinkActivated: (url) => Qt.openUrlExternally(url)
                                HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                            }

                            Label {
                                text: `<a href='https://www.animenewsnetwork.com/encyclopedia/anime.php?id=${anime.ann_id}'>ANN</a>`
                                visible: (anime.ann_id || 0) > 0
                                textFormat: Text.RichText
                                onLinkActivated: (url) => Qt.openUrlExternally(url)
                                HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                            }
                        }
                    }
                }

                // Episode & source selection
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        visible: !hasToken
                        text: "\u26A0 No API token set \u2014 configure in Settings"
                        color: "#EF5350"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CustomDropdown {
                            id: episodeDropdown
                            Layout.fillWidth: true
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

                        StyledButton {
                            id: batchDownloadButton
                            text: batchBusy ? ("Fetching " + batchCurrent + "/" + batchTotal + "...") : "Download All"
                            visible: !isAndroid && anime.episode_ids !== undefined
                            enabled: !batchBusy && downloadAvailable
                            property bool batchBusy: false
                            property int batchCurrent: 0
                            property int batchTotal: 0
                            onClicked: {
                                batchBusy = true
                                animeBackend.batch_download(
                                    anime.episode_ids,
                                    anime.episode_list,
                                    streamSelected
                                )
                            }
                        }
                    }

                    CustomDropdown {
                        id: sourceDropdown
                        visible: false
                        Layout.fillWidth: true
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
                        Layout.fillWidth: true
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
                        Layout.fillWidth: true
                        placeholder: "Select Quality"
                        onSelectionChangedIndex: function(value) {
                            urlsContainer.visible = true
                            dlButton.enabled = downloadAvailable
                            dlButtonSubs.enabled = downloadAvailable
                            dlEpisodeButton.enabled = downloadAvailable
                            mpvButton.enabled = mpvAvailable
                            vlcButton.enabled = vlcAvailable

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

                            checkLocalFiles()
                        }
                    }

                    // URLs and player controls
                    Pane {
                        id: urlsContainer
                        visible: false
                        Layout.fillWidth: true
                        padding: 8

                        background: Rectangle {
                            color: palette.base
                            radius: 4
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                StyledTextField {
                                    id: videoUrlField
                                    Layout.fillWidth: true
                                    readOnly: true
                                    Component.onCompleted: cursorPosition = 0
                                    onTextChanged: cursorPosition = 0
                                }

                                StyledButton {
                                    id: copyButton
                                    text: "Copy"
                                    visible: !isAndroid
                                    onClicked: {
                                        videoUrlField.selectAll()
                                        videoUrlField.copy()
                                    }
                                }

                                StyledButton {
                                    id: dlButton
                                    text: "Download"
                                    visible: !isAndroid
                                    onClicked: {
                                        var url = videoUrlField.text
                                        var title = anime.title + " \u2014 " + episodeDropdown.selectedValue
                                        var ep = episodeDropdown.selectedValue
                                        var episodesTotal = episodeDropdown.model.length
                                        var baseFilename = animeBackend.title_to_filename(title, episodesTotal, "mp4")
                                        var filename = downloaderBackend.resolve_filename(
                                            baseFilename, anime.title, ep,
                                            streamSelected, videoStreamSelected, "video")
                                        downloaderBackend.add_download(url, filename)
                                        downloaderBackend.record_meta(
                                            filename, anime.title, ep,
                                            streamSelected, videoStreamSelected, qualitySelected)
                                        dlButton.enabled = false
                                    }
                                }
                            }

                            RowLayout {
                                id: subsRow
                                Layout.fillWidth: true
                                spacing: 8

                                StyledTextField {
                                    id: subsUrlField
                                    Layout.fillWidth: true
                                    readOnly: true

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

                                StyledButton {
                                    id: copyButtonSubs
                                    text: "Copy"
                                    visible: !isAndroid
                                    onClicked: {
                                        subsUrlField.selectAll()
                                        subsUrlField.copy()
                                    }
                                }

                                StyledButton {
                                    id: dlButtonSubs
                                    text: "Download"
                                    visible: !isAndroid
                                    onClicked: {
                                        var url = subsUrlField.text
                                        var title = anime.title + " \u2014 " + episodeDropdown.selectedValue
                                        var ep = episodeDropdown.selectedValue
                                        var episodesTotal = episodeDropdown.model.length
                                        var baseFilename = animeBackend.title_to_filename(title, episodesTotal, "ass")
                                        var filename = downloaderBackend.resolve_filename(
                                            baseFilename, anime.title, ep,
                                            streamSelected, videoStreamSelected, "subs")
                                        downloaderBackend.add_download(url, filename)
                                        downloaderBackend.record_meta(
                                            filename, anime.title, ep,
                                            streamSelected, videoStreamSelected, qualitySelected)
                                        dlButtonSubs.enabled = false
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: episodeDownloadProgress >= 0

                                ProgressBar {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 1
                                    value: episodeDownloadProgress
                                }

                                Label {
                                    text: {
                                        var parts = []
                                        if (episodeDownloadTotal > 0)
                                            parts.push(formatSize(episodeDownloaded) + " / " + formatSize(episodeDownloadTotal))
                                        if (episodeDownloadSpeed > 0)
                                            parts.push(formatSpeed(episodeDownloadSpeed))
                                        return parts.join("  ") || "Waiting..."
                                    }
                                    font.pixelSize: 12
                                    opacity: 0.7
                                }
                            }

                            RowLayout {
                                spacing: 8

                                StyledButton {
                                    id: mpvButton
                                    text: localVideoPath ? "mpv (local)" : "mpv"
                                    Timer {
                                        id: mpvTimer
                                        interval: 5000
                                        repeat: false
                                        onTriggered: mpvButton.enabled = mpvAvailable
                                    }
                                    onClicked: {
                                        var url = localVideoPath || videoUrlField.text
                                        var subs = localSubsPath || subsUrlField.text
                                        var title = anime.title + " \u2014 " + episodeDropdown.selectedValue
                                        animeBackend.launch_mpv(url, subs, title, anime.image_url || "")
                                        mpvButton.enabled = false
                                        mpvTimer.start()
                                    }
                                }

                                StyledButton {
                                    id: vlcButton
                                    text: localVideoPath ? "VLC (local)" : "VLC"
                                    Timer {
                                        id: vlcTimer
                                        interval: 5000
                                        repeat: false
                                        onTriggered: vlcButton.enabled = vlcAvailable
                                    }
                                    onClicked: {
                                        var url = localVideoPath || videoUrlField.text
                                        var subs = localSubsPath || subsUrlField.text
                                        var title = anime.title + " \u2014 " + episodeDropdown.selectedValue
                                        animeBackend.launch_vlc(url, subs, title, anime.image_url || "")
                                        vlcButton.enabled = false
                                        vlcTimer.start()
                                    }
                                }

                                StyledButton {
                                    id: dlEpisodeButton
                                    text: "Download Episode"
                                    visible: !isAndroid
                                    onClicked: {
                                        dlButton.clicked()
                                        if (subsRow.visible)
                                            dlButtonSubs.clicked()
                                        dlEpisodeButton.enabled = false
                                    }
                                }

                                Label {
                                    visible: localVideoPath !== "" && localVideoMeta === ""
                                    text: "\u2714 Downloaded"
                                    color: "#4CAF50"
                                    font.bold: true
                                }

                                Label {
                                    visible: localVideoPath !== "" && localVideoMeta !== ""
                                    text: "\u2714 Downloaded (" + localVideoMeta + ")"
                                    color: "#FF9800"
                                    font.bold: true
                                }

                                Label {
                                    visible: localVideoMeta.startsWith("lower_quality")
                                    text: {
                                        if (!localVideoMeta.startsWith("lower_quality")) return ""
                                        var parts = localVideoMeta.split(":")
                                        return "\u26A0 Downloaded in " + (parts[1] || "?") + " \u2014 streaming " + qualitySelected + " online"
                                    }
                                    color: "#FF9800"
                                    font.pixelSize: 12
                                }

                                Label {
                                    visible: otherDownloadsInfo !== "" && localVideoPath === ""
                                        && !localVideoMeta.startsWith("lower_quality")
                                    text: "\u2193 Also downloaded: " + otherDownloadsInfo
                                    color: "#64B5F6"
                                    font.pixelSize: 12
                                }

                                Label {
                                    visible: otherDownloadsInfo !== "" && localVideoPath !== ""
                                    text: "Also downloaded by: " + otherDownloadsInfo
                                    color: palette.text
                                    opacity: 0.6
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
