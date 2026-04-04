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

    readonly property bool mpvAvailable: settingsBackend && settingsBackend.is_valid_binary(settingsBackend.get("mpv_path"))
    readonly property bool vlcAvailable: settingsBackend && settingsBackend.is_valid_binary(settingsBackend.get("vlc_path"))
    readonly property bool mpcAvailable: isWindows && settingsBackend && settingsBackend.is_valid_binary(settingsBackend.get("mpc_path"))
    readonly property bool hasToken: settingsBackend && settingsBackend.get("anime365_token") !== ""

    property bool episodeIdsReady: false

    property var missingSubtitleFonts: []
    property var subtitleFontScripts: []
    property var fontStatuses: ({})  // font_name -> "downloading"|"done"|"failed"

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
        episodeIdsReady = anime.episode_ids !== undefined
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
            var prevProgress = episodeDownloadProgress
            episodeDownloadProgress = -1
            episodeDownloadSpeed = 0
            episodeDownloaded = 0
            episodeDownloadTotal = 0
            for (var i = 0; i < items.length; i++) {
                var fn = items[i].filename
                if (fn.startsWith(baseStem) && (fn.endsWith(".mp4") || fn.endsWith(".mkv") || fn.endsWith(".webm"))) {
                    if (items[i].status === "active" || items[i].status === "waiting") {
                        episodeDownloadProgress = items[i].progress
                        episodeDownloadSpeed = items[i].speed
                        episodeDownloaded = items[i].downloaded
                        episodeDownloadTotal = items[i].total_size
                    }
                    break
                }
            }
            // Refresh local file status when download finishes or is canceled
            if (prevProgress >= 0 && episodeDownloadProgress < 0)
                checkLocalFiles()
        }
    }

    Connections {
        target: animeBackend

        function onEpisodes_got(result) {
            anime.episode_list = result.episode_list
            anime.episode_ids = result.episode_ids
            episodeIdsReady = true
            busyIndicator.running = false

            // Handle anime with no episodes (unreleased)
            if (!result.episode_list) {
                episodeDropdown.model = []
                episodeDropdown.visible = false
                return
            }

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
            if (completed && settingsBackend.get_settings()["auto_advance"] === true) {
                var idx = episodeDropdown.selectedIndex
                if (idx >= 0 && idx < episodeDropdown.model.length - 1) {
                    episodeDropdown.changeSelection(idx + 1)
                    autoAdvanceNotice.show()
                }
            }
        }

        function onBatch_progress(current, total) {
            batchDownloadButton.batchCurrent = current
            batchDownloadButton.batchTotal = total
        }

        function onBatch_item_ready(item) {
            var ep = item.episode_name
            var title = anime.title + " \u2014 " + ep
            var episodesTotal = episodeDropdown.model ? episodeDropdown.model.length : 1

            // Skip if already downloaded at exact or better quality
            var checkResult = downloaderBackend.find_downloaded_video(
                anime.title, ep, streamSelected, qualitySelected)
            if (checkResult && checkResult.path && !checkResult.lower_quality) {
                batchDownloadButton.batchSkipped++
                return
            }

            // Build video filename to check against active downloads
            var baseFilename = animeBackend.title_to_filename(title, episodesTotal, "mp4")
            var filename = downloaderBackend.resolve_filename(
                baseFilename, anime.title, ep,
                streamSelected, videoStreamSelected, "video")

            // Skip if this exact file is already an active or waiting download
            var downloads = downloaderBackend.get_downloads()
            for (var j = 0; j < downloads.length; j++) {
                var dl = downloads[j]
                if (dl.filename === filename &&
                        (dl.status === "active" || dl.status === "waiting")) {
                    batchDownloadButton.batchSkipped++
                    return
                }
            }

            var subsUrl = item.subs_url || ""
            var subsFilename = ""
            if (subsUrl) {
                var baseSubsFilename = animeBackend.title_to_filename(title, episodesTotal, "ass")
                subsFilename = downloaderBackend.resolve_filename(
                    baseSubsFilename, anime.title, ep,
                    streamSelected, videoStreamSelected, "subs")
                downloaderBackend.record_meta(
                    subsFilename, anime.title, ep,
                    streamSelected, videoStreamSelected, qualitySelected)
            }
            downloaderBackend.add_download(item.url, filename, subsUrl, subsFilename)
            downloaderBackend.record_meta(
                filename, anime.title, ep,
                streamSelected, videoStreamSelected, qualitySelected)
        }

        function onBatch_complete() {
            batchDownloadButton.batchBusy = false
        }

        function onBatch_unavailable(episodeName) {
            batchDownloadButton.batchStoppedAt = episodeName
        }

        function onSubtitle_fonts_got(results) {
            var fonts = results.fonts || []
            var scripts = results.scripts || []
            subtitleFontScripts = scripts

            var missing = fonts.filter(f => !Qt.fontFamilies().includes(f))
            missingSubtitleFonts = missing
            downloadFontsButton.visible = missing.length > 0
            downloadFontsButton.enabled = true
            downloadFontsButton.text = "Download Missing Fonts (" + missing.length + ")"

            var formatted = "Fonts (during application startup):<br><br>" + fonts.map(fontName => {
                var isAvailable = Qt.fontFamilies().includes(fontName)
                return isAvailable ?
                    "\u2714 <b>" + fontName + "</b>" :
                    "\u274C " + fontName
            }).join("<br>")
            if (scripts.length > 0)
                formatted += "<br><br>Scripts: " + scripts.join(", ")

            subsUrlField.ToolTip.text = formatted
            subsUrlField.ToolTip.textFormat = Text.RichText
        }

        function onFont_status(fontName, status) {
            var s = Object.assign({}, fontStatuses)
            s[fontName] = status
            fontStatuses = s
            _refreshFontStatusLabel()
        }

        function onFonts_downloaded(result) {
            missingSubtitleFonts = result.not_found || []
            downloadFontsButton.visible = false
            downloadFontsButton.enabled = true
            _refreshFontStatusLabel()
        }

        function _refreshFontStatusLabel() {
            var names = Object.keys(fontStatuses)
            if (names.length === 0) { fontsStatusLabel.text = ""; return }
            var lines = names.map(name => {
                var s = fontStatuses[name]
                if (s === "done")        return '<font color="#4caf50">\u2714 ' + name + '</font>'
                if (s === "failed")      return '<font color="#f44336">\u2716 ' + name + '</font>'
                return '<font color="gray">\u22ef ' + name + '</font>'
            })
            fontsStatusLabel.text = lines.join("<br>")
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

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: coverOverlay.open()
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

                                // Persist episode selection immediately so it survives navigation
                                // even if the user never reaches quality selection.
                                if (anime.id) {
                                    databaseBackend.update(String(anime.id), {
                                        episode: episodeDropdown.model[value],
                                        translation: streamSelected,
                                        alt_video: videoStreamSelected,
                                        quality: qualitySelected
                                    })
                                }

                                var split = anime.episode_ids.split(";")
                                animeBackend.select_episode(split[value])
                            }
                        }

                        StyledButton {
                            id: batchDownloadButton
                            text: batchBusy ? ("Fetching " + batchCurrent + "/" + batchTotal + "...") : "Download All"
                            visible: episodeIdsReady
                            enabled: !batchBusy && urlsContainer.visible
                            property bool batchBusy: false
                            property int batchCurrent: 0
                            property int batchTotal: 0
                            property int batchSkipped: 0
                            property string batchStoppedAt: ""
                            ToolTip.visible: hovered && !urlsContainer.visible
                            ToolTip.text: "Select an episode, team and quality first"
                            ToolTip.delay: 600
                            onClicked: {
                                batchBusy = true
                                batchSkipped = 0
                                batchStoppedAt = ""
                                var startIdx = Math.max(0, episodeDropdown.selectedIndex)
                                var allIds = anime.episode_ids.split(";")
                                var allNames = anime.episode_list.split(";")
                                var ids = allIds.slice(startIdx).join(";")
                                var names = allNames.slice(startIdx).join(";")
                                animeBackend.batch_download(
                                    ids,
                                    names,
                                    streamSelected,
                                    qualitySelected
                                )
                            }
                        }
                    }

                    Label {
                        id: batchStatusLabel
                        visible: !batchDownloadButton.batchBusy
                                 && (batchDownloadButton.batchStoppedAt !== ""
                                     || batchDownloadButton.batchSkipped > 0)
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                        color: batchDownloadButton.batchStoppedAt !== "" ? "#FF9800" : "#4CAF50"
                        text: {
                            var parts = []
                            if (batchDownloadButton.batchStoppedAt !== "")
                                parts.push("\u26A0 Stopped at \u201C" + batchDownloadButton.batchStoppedAt
                                           + "\u201D \u2014 not available in selected team / quality")
                            if (batchDownloadButton.batchSkipped > 0)
                                parts.push((batchDownloadButton.batchStoppedAt !== "" ? "s" : "S")
                                           + "kipped " + batchDownloadButton.batchSkipped
                                           + " already downloaded")
                            return parts.join("  \u2022  ")
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
                            mpvButton.enabled = mpvAvailable
                            vlcButton.enabled = vlcAvailable
                            mpcButton.enabled = mpcAvailable

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
                                downloadFontsButton.visible = false
                                fontsStatusLabel.text = ""
                                fontStatuses = {}
                                missingSubtitleFonts = []
                                subtitleFontScripts = []
                                animeBackend.get_subtitle_fonts(subs)
                            } else {
                                subsRow.visible = false
                                downloadFontsButton.visible = false
                            }

                            qualitySelected = qualityDropdown.selectedValue

                            databaseBackend.update(String(anime.id), {
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
                                    onClicked: {
                                        videoUrlField.selectAll()
                                        videoUrlField.copy()
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
                                    onClicked: {
                                        subsUrlField.selectAll()
                                        subsUrlField.copy()
                                    }
                                }

                                StyledButton {
                                    id: downloadFontsButton
                                    visible: false
                                    text: "Download Missing Fonts"
                                    onClicked: {
                                        enabled = false
                                        text = "Downloading..."
                                        fontStatuses = {}
                                        fontsStatusLabel.text = ""
                                        animeBackend.download_missing_fonts(
                                            missingSubtitleFonts,
                                            subtitleFontScripts
                                        )
                                    }
                                }

                                Label {
                                    id: fontsStatusLabel
                                    visible: text !== ""
                                    text: ""
                                    font.pixelSize: 11
                                    opacity: 0.85
                                    wrapMode: Text.WordWrap
                                    textFormat: Text.RichText
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
                                    Layout.preferredWidth: 180
                                    horizontalAlignment: Text.AlignRight
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
                                    id: mpcButton
                                    visible: mpcAvailable
                                    text: localVideoPath ? "MPC-HC (local)" : "MPC-HC"
                                    Timer {
                                        id: mpcTimer
                                        interval: 5000
                                        repeat: false
                                        onTriggered: mpcButton.enabled = mpcAvailable
                                    }
                                    onClicked: {
                                        var url = localVideoPath || videoUrlField.text
                                        var subs = localSubsPath || subsUrlField.text
                                        var title = anime.title + " \u2014 " + episodeDropdown.selectedValue
                                        animeBackend.launch_mpc(url, subs, title, anime.image_url || "")
                                        mpcButton.enabled = false
                                        mpcTimer.start()
                                    }
                                }

                                StyledButton {
                                    id: dlEpisodeButton
                                    text: "Download"
                                    enabled: episodeDownloadProgress < 0
                                    onClicked: {
                                        var url = videoUrlField.text
                                        var title = anime.title + " \u2014 " + episodeDropdown.selectedValue
                                        var ep = episodeDropdown.selectedValue
                                        var episodesTotal = episodeDropdown.model.length
                                        var baseFilename = animeBackend.title_to_filename(title, episodesTotal, "mp4")
                                        var filename = downloaderBackend.resolve_filename(
                                            baseFilename, anime.title, ep,
                                            streamSelected, videoStreamSelected, "video")
                                        var subsUrl = subsUrlField.text || ""
                                        var subsFilename = ""
                                        if (subsUrl) {
                                            var baseSubsFilename = animeBackend.title_to_filename(title, episodesTotal, "ass")
                                            subsFilename = downloaderBackend.resolve_filename(
                                                baseSubsFilename, anime.title, ep,
                                                streamSelected, videoStreamSelected, "subs")
                                            downloaderBackend.record_meta(
                                                subsFilename, anime.title, ep,
                                                streamSelected, videoStreamSelected, qualitySelected)
                                        }
                                        downloaderBackend.add_download(url, filename, subsUrl, subsFilename)
                                        downloaderBackend.record_meta(
                                            filename, anime.title, ep,
                                            streamSelected, videoStreamSelected, qualitySelected)
                                    }
                                }

                                Label {
                                    visible: episodeDownloadProgress < 0 && localVideoPath !== "" && localVideoMeta === ""
                                    text: "\u2714 Downloaded"
                                    color: "#4CAF50"
                                    font.bold: true
                                }

                                Label {
                                    visible: episodeDownloadProgress < 0 && localVideoPath !== "" && localVideoMeta !== ""
                                    text: "\u2714 Downloaded (" + localVideoMeta + ")"
                                    color: "#FF9800"
                                    font.bold: true
                                }

                                Label {
                                    visible: episodeDownloadProgress < 0 && localVideoMeta.startsWith("lower_quality")
                                    text: {
                                        if (!localVideoMeta.startsWith("lower_quality")) return ""
                                        var parts = localVideoMeta.split(":")
                                        return "\u26A0 Downloaded in " + (parts[1] || "?") + " \u2014 streaming " + qualitySelected + " online"
                                    }
                                    color: "#FF9800"
                                    font.pixelSize: 12
                                }

                                Label {
                                    visible: episodeDownloadProgress < 0 && otherDownloadsInfo !== "" && localVideoPath === ""
                                        && !localVideoMeta.startsWith("lower_quality")
                                    text: "\u2193 Also downloaded: " + otherDownloadsInfo
                                    color: "#64B5F6"
                                    font.pixelSize: 12
                                }

                                Label {
                                    visible: episodeDownloadProgress < 0 && otherDownloadsInfo !== "" && localVideoPath !== ""
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

    Rectangle {
        id: autoAdvanceNotice
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        z: 10
        visible: opacity > 0
        opacity: 0
        color: palette.highlight
        radius: 6
        implicitWidth: noticeLabel.implicitWidth + 24
        implicitHeight: noticeLabel.implicitHeight + 16

        Label {
            id: noticeLabel
            anchors.centerIn: parent
            text: "Auto-advancing to next episode"
            color: palette.highlightedText
        }

        property bool pendingTimer: false

        Connections {
            target: Qt.application
            function onStateChanged() {
                if (Qt.application.state === Qt.ApplicationActive && autoAdvanceNotice.pendingTimer) {
                    autoAdvanceNotice.pendingTimer = false
                    noticeTimer.restart()
                }
            }
        }

        NumberAnimation {
            id: noticeFadeOut
            target: autoAdvanceNotice
            property: "opacity"
            to: 0
            duration: 500
        }

        Timer {
            id: noticeTimer
            interval: 6000
            onTriggered: noticeFadeOut.start()
        }

        function show() {
            noticeFadeOut.stop()
            opacity = 1
            pendingTimer = false
            if (Qt.application.state === Qt.ApplicationActive) {
                noticeTimer.restart()
            } else {
                noticeTimer.stop()
                pendingTimer = true
            }
        }
    }

    Popup {
        id: coverOverlay
        anchors.centerIn: parent
        modal: true
        dim: true
        padding: 0
        background: Rectangle { color: "transparent" }

        Overlay.modal: Rectangle {
            color: "#C0000000"
        }

        contentItem: Image {
            source: coverImage.source
            fillMode: Image.PreserveAspectFit
            sourceSize.width: coverImage.sourceSize.width
            sourceSize.height: coverImage.sourceSize.height
            width: Math.min(sourceSize.width, root.width - 48)
            height: Math.min(sourceSize.height, root.height - 48)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: coverOverlay.close()
        }
    }
}
