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

    function handleBack() { stackView.pop() }

    Globals { id: globals }

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
    property bool isBusy: false

    property var missingSubtitleFonts: []

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
            isBusy = true
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
            isBusy = false

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

            isBusy = false
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

            isBusy = false
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

            // Prefer fontconfig list (same source as MPV/libass); fall back to Qt on Windows
            var availableSet = results.available !== null && results.available !== undefined
                ? results.available
                : Qt.fontFamilies()

            function isAvailable(name) { return availableSet.includes(name) }

            var missing = fonts.filter(f => !isAvailable(f))
            missingSubtitleFonts = missing

            var formatted = "Fonts:<br><br>" + fonts.map(name =>
                isAvailable(name)
                    ? "\u2714 <b>" + name + "</b>"
                    : "\u274C " + name
            ).join("<br>")
            if (scripts.length > 0)
                formatted += "<br><br>Scripts: " + scripts.join(", ")

            subsUrlField.ToolTip.text = formatted
            subsUrlField.ToolTip.textFormat = Text.RichText
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.parent.width
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 210
                    spacing: 14

                    // Cover image — clipped, rounded, aspect-cropped
                    Rectangle {
                        Layout.preferredWidth: 140
                        Layout.fillHeight: true
                        radius: 6
                        clip: true
                        color: palette.alternateBase

                        Image {
                            id: coverImage
                            anchors.fill: parent
                            source: imageCacheBackend.cache_image(anime.image_url)
                            fillMode: Image.PreserveAspectCrop
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

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: coverOverlay.open()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        // Title
                        Label {
                            text: anime.title
                            font.pixelSize: 20
                            font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        // Metadata badges row
                        Row {
                            spacing: 5

                            // Score badge
                            Rectangle {
                                property real sv: parseFloat(anime.score) || 0
                                property color sc: sv > 0 ? globals.scoreColor(sv) : "transparent"
                                visible: sv > 0
                                radius: 4
                                width: scoreBadgeLabel.implicitWidth + 12
                                height: 20
                                color: Qt.rgba(sc.r, sc.g, sc.b, 0.15)
                                border.color: Qt.rgba(sc.r, sc.g, sc.b, 0.30)
                                border.width: 1

                                Label {
                                    id: scoreBadgeLabel
                                    anchors.centerIn: parent
                                    text: "\u2605 " + (parseFloat(parent.sv) || 0).toFixed(1)
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: parent.sc
                                }
                            }

                            // Type badge
                            Rectangle {
                                visible: (anime.h_type || anime.type || "") !== ""
                                radius: 4
                                width: typeBadgeLabel.implicitWidth + 12
                                height: 20
                                property string t: (anime.h_type || anime.type || "").toLowerCase()
                                color: {
                                    switch (t) {
                                        case "tv":    return Qt.rgba(0.129, 0.588, 0.953, 0.18)
                                        case "movie": return Qt.rgba(0.612, 0.153, 0.690, 0.18)
                                        case "ova":
                                        case "ona":   return Qt.rgba(0.000, 0.588, 0.533, 0.13)
                                        default:      return Qt.rgba(0.5,   0.5,   0.5,   0.10)
                                    }
                                }
                                border.color: {
                                    switch (t) {
                                        case "tv":    return Qt.rgba(0.129, 0.588, 0.953, 0.35)
                                        case "movie": return Qt.rgba(0.612, 0.153, 0.690, 0.35)
                                        default:      return Qt.rgba(0.5,   0.5,   0.5,   0.15)
                                    }
                                }
                                border.width: 1

                                Label {
                                    id: typeBadgeLabel
                                    anchors.centerIn: parent
                                    text: (anime.h_type || anime.type || "").toUpperCase()
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: {
                                        switch (parent.t) {
                                            case "tv":    return "#2196F3"
                                            case "movie": return "#9C27B0"
                                            case "ova":
                                            case "ona":   return "#009688"
                                            default:      return palette.windowText
                                        }
                                    }
                                    opacity: 0.85
                                }
                            }

                            // Year badge
                            Rectangle {
                                visible: (anime.year || 0) > 0
                                radius: 4
                                width: yearBadgeLabel.implicitWidth + 12
                                height: 20
                                color: Qt.rgba(0.5, 0.5, 0.5, 0.10)
                                border.color: Qt.rgba(0.5, 0.5, 0.5, 0.15)
                                border.width: 1

                                Label {
                                    id: yearBadgeLabel
                                    anchors.centerIn: parent
                                    text: anime.year || ""
                                    font.pixelSize: 11
                                    color: palette.windowText
                                    opacity: 0.65
                                }
                            }

                            // Episode count badge
                            Rectangle {
                                visible: (anime.total_episodes || 0) > 0
                                radius: 4
                                width: epsBadgeLabel.implicitWidth + 12
                                height: 20
                                color: Qt.rgba(0.5, 0.5, 0.5, 0.10)
                                border.color: Qt.rgba(0.5, 0.5, 0.5, 0.15)
                                border.width: 1

                                Label {
                                    id: epsBadgeLabel
                                    anchors.centerIn: parent
                                    text: anime.total_episodes + " ep"
                                    font.pixelSize: 11
                                    color: palette.windowText
                                    opacity: 0.65
                                }
                            }
                        }

                        // Watch progress bar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: {
                                var ep = anime.episode || ""
                                var m = ep.match(/(\d+)\s+серия/)
                                return m !== null && (anime.total_episodes || 0) > 0
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 2

                                property real frac: {
                                    var ep = anime.episode || ""
                                    var m = ep.match(/(\d+)\s+серия/)
                                    var total = anime.total_episodes || 0
                                    return (m && total > 0) ? Math.min(parseInt(m[1]) / total, 1.0) : 0
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: palette.mid
                                    opacity: 0.20
                                }
                                Rectangle {
                                    x: 0; y: 0
                                    height: parent.height
                                    width: parent.width * parent.frac
                                    color: palette.highlight
                                    opacity: 0.80
                                }
                            }

                            Label {
                                font.pixelSize: 11
                                opacity: 0.55
                                text: {
                                    var ep = anime.episode || ""
                                    var m = ep.match(/(\d+)\s+серия/)
                                    var total = anime.total_episodes || 0
                                    return m ? m[1] + " / " + total + " watched" : ""
                                }
                            }
                        }

                        // Description
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Label {
                                width: parent.parent.width
                                text: anime.description
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                opacity: 0.72
                            }
                        }

                        // External site links — chip style
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            component LinkChip: Rectangle {
                                property string label: ""
                                property string url: ""
                                property bool _hov: false

                                visible: url !== ""
                                radius: 4
                                width: _lbl.implicitWidth + 16
                                height: 22
                                color: _hov ? Qt.rgba(palette.highlight.r, palette.highlight.g, palette.highlight.b, 0.12)
                                            : "transparent"
                                border.color: _hov ? palette.highlight : palette.mid
                                border.width: 1
                                Behavior on color        { ColorAnimation { duration: 80 } }
                                Behavior on border.color { ColorAnimation { duration: 80 } }

                                Label {
                                    id: _lbl
                                    anchors.centerIn: parent
                                    text: parent.label
                                    font.pixelSize: 11
                                    color: _hov ? palette.highlight : palette.windowText
                                    opacity: _hov ? 1.0 : 0.65
                                    Behavior on color   { ColorAnimation { duration: 80 } }
                                    Behavior on opacity { NumberAnimation  { duration: 80 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent._hov = true
                                    onExited:  parent._hov = false
                                    onClicked: Qt.openUrlExternally(parent.url)
                                }
                            }

                            LinkChip { label: "anime365";  url: anime.anime365_url || "" }
                            LinkChip { label: "Shikimori"; url: (anime.mal_id || 0) > 0 ? "https://shikimori.io/animes/" + anime.mal_id : "" }
                            LinkChip { label: "MAL";       url: (anime.mal_id || 0) > 0 ? "https://myanimelist.net/anime/" + anime.mal_id : "" }
                            LinkChip { label: "AniDB";     url: (anime.anidb_id || 0) > 0 ? "https://anidb.net/anime/" + anime.anidb_id : "" }
                            LinkChip { label: "World Art"; url: (anime.world_art_id || 0) > 0 ? "http://www.world-art.ru/animation/animation.php?id=" + anime.world_art_id : "" }
                            LinkChip { label: "ANN";       url: (anime.ann_id || 0) > 0 ? "https://www.animenewsnetwork.com/encyclopedia/anime.php?id=" + anime.ann_id : "" }
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
                        color: globals.colorError
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

                                isBusy = true

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
                        color: batchDownloadButton.batchStoppedAt !== "" ? globals.colorWarning : globals.colorSuccess
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

                            isBusy = true

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

                            isBusy = true

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
                                missingSubtitleFonts = []
                                animeBackend.get_subtitle_fonts(subs)
                            } else {
                                subsRow.visible = false
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
                                    ToolTip.delay: 600

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
                                    id: searchFontsButton
                                    visible: missingSubtitleFonts.length > 0
                                    text: "Search Missing Fonts (" + missingSubtitleFonts.length + ")"

                                    ToolTip.visible: hovered
                                    ToolTip.delay: 500
                                    ToolTip.text: missingSubtitleFonts.join("\n")

                                    onClicked: {
                                        for (var i = 0; i < missingSubtitleFonts.length; i++) {
                                            Qt.openUrlExternally(
                                                "https://www.google.com/search?q=" +
                                                encodeURIComponent(missingSubtitleFonts[i] + " font download")
                                            )
                                        }
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
                                    Layout.preferredWidth: 180
                                    horizontalAlignment: Text.AlignRight
                                    text: {
                                        var parts = []
                                        if (episodeDownloadTotal > 0)
                                            parts.push(globals.formatSize(episodeDownloaded) + " / " + globals.formatSize(episodeDownloadTotal))
                                        if (episodeDownloadSpeed > 0)
                                            parts.push(globals.formatSpeed(episodeDownloadSpeed))
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
                                    color: globals.colorSuccess
                                    font.bold: true
                                }

                                Label {
                                    visible: episodeDownloadProgress < 0 && localVideoPath !== "" && localVideoMeta !== ""
                                    text: "\u2714 Downloaded (" + localVideoMeta + ")"
                                    color: globals.colorWarning
                                    font.bold: true
                                }

                                Label {
                                    visible: episodeDownloadProgress < 0 && localVideoMeta.startsWith("lower_quality")
                                    text: {
                                        if (!localVideoMeta.startsWith("lower_quality")) return ""
                                        var parts = localVideoMeta.split(":")
                                        return "\u26A0 Downloaded in " + (parts[1] || "?") + " \u2014 streaming " + qualitySelected + " online"
                                    }
                                    color: globals.colorWarning
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
