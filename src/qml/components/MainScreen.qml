import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    objectName: "mainScreen"
    padding: 12

    function focusSearch() { searchField.forceActiveFocus() }

    property string updateTag: ""
    property string updateUrl: ""
    property string currentVersion: ""
    property string updateState: ""   // "available" | "downloading" | "ready" | "failed"
    property int updateProgress: 0
    property string updateStatusText: ""

    Connections {
        target: updaterBackend
        function onUpdate_found(tag, url, current) {
            updateTag = tag
            updateUrl = url
            currentVersion = current
            updateState = "available"
        }
        function onUpdate_progress(pct) { updateProgress = pct }
        function onUpdate_status(msg)   { updateStatusText = msg }
        function onUpdate_ready()       { updateState = "ready" }
        function onUpdate_failed(msg)   { updateState = "failed"; updateStatusText = msg }
    }

    Component.onCompleted: {
        updaterBackend.check()
        updateHistory()
    }

    function updateHistory() {
        var history = databaseBackend.get_list()
        historyModel.clear()
        for (var i = 0; i < history.length; i++) {
            historyModel.append(history[i])
        }

        var cw = databaseBackend.get_continue_watching()
        continueWatchingModel.clear()
        for (var i = 0; i < cw.length; i++) {
            continueWatchingModel.append(cw[i])
        }
    }

    Connections {
        target: databaseBackend

        function onList_updated() {
            updateHistory()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledTextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search anime"
                onAccepted: {
                    if (text.trim() !== "") {
                        searchBackend.perform_search(searchField.text.trim())
                        stackView.push(searchScreen, { searchQuery: text })
                    }
                }
            }

            StyledButton {
                text: "Search"
                onClicked: {
                    if (searchField.text.trim() !== "") {
                        searchBackend.perform_search(searchField.text.trim())
                        stackView.push(searchScreen, { searchQuery: searchField.text })
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledButton {
                Layout.fillWidth: true
                text: "Downloads"
                onClicked: stackView.push(downloadScreen)
            }

            StyledButton {
                Layout.fillWidth: true
                text: "Settings"
                onClicked: stackView.push(settingsScreen)
            }
        }

        Pane {
            Layout.fillWidth: true
            visible: updateState !== ""
            padding: 8

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label {
                        Layout.fillWidth: true
                        textFormat: Text.RichText
                        text: {
                            if (updateState === "available")
                                return `Update available: ${currentVersion} \u2192 <a href='${updateUrl}'>${updateTag}</a>`
                            if (updateState === "downloading")
                                return updateStatusText || "Downloading..."
                            if (updateState === "ready")
                                return "Update installed — restart to apply"
                            if (updateState === "failed")
                                return `Update failed: ${updateStatusText}`
                            return ""
                        }
                        onLinkActivated: (url) => Qt.openUrlExternally(url)
                        HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    }

                    StyledButton {
                        visible: updateState === "available"
                        text: "Update Now"
                        palette.button: "#4CAF50"
                        palette.buttonText: "#FFFFFF"
                        onClicked: {
                            updateState = "downloading"
                            updateProgress = 0
                            updaterBackend.download_update()
                        }
                    }

                    StyledButton {
                        visible: updateState === "ready"
                        text: "Restart"
                        palette.button: "#4CAF50"
                        palette.buttonText: "#FFFFFF"
                        onClicked: Qt.quit()
                    }

                    StyledButton {
                        visible: updateState !== "downloading"
                        text: "\u2715"
                        implicitWidth: 28
                        implicitHeight: 28
                        leftPadding: 0
                        rightPadding: 0
                        onClicked: updateState = ""
                    }
                }

                ProgressBar {
                    Layout.fillWidth: true
                    visible: updateState === "downloading"
                    value: updateProgress / 100.0
                }
            }
        }

        // Continue Watching section
        ColumnLayout {
            Layout.fillWidth: true
            visible: continueWatchingModel.count > 0
            spacing: 4

            Label {
                text: "Continue Watching"
                font.pixelSize: 16
                font.bold: true
            }

            ListView {
                id: continueWatchingList
                Layout.fillWidth: true
                Layout.preferredHeight: 260
                orientation: ListView.Horizontal
                spacing: 10
                clip: true

                model: ListModel {
                    id: continueWatchingModel
                }

                delegate: Rectangle {
                    width: 180
                    height: 250
                    radius: 6
                    color: cwMouseArea.containsMouse ? palette.highlight : palette.base

                    MouseArea {
                        id: cwMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var item = Object.assign({}, model)
                            item.next_episode = true
                            stackView.push(animeScreen, { anime: item })
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Image {
                            id: cwImage
                            Layout.fillWidth: true
                            Layout.preferredHeight: 160
                            source: imageCacheBackend.cache_image(model.image_url)
                            fillMode: Image.PreserveAspectFit
                            cache: true
                            asynchronous: true
                            Connections {
                                target: imageCacheBackend
                                function onImage_downloaded(origUrl, localUrl) {
                                    if (origUrl === model.image_url)
                                        cwImage.source = localUrl
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: model.title
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            text: {
                                var ep = model.episode || ""
                                var total = model.total_episodes || 0
                                var match = ep.match(/\d+/)
                                if (match) {
                                    var epNum = parseInt(match[0])
                                    if (epNum > 0 && (total === 0 || epNum < total)) {
                                        var nextEp = ep.replace(/\d+/, String(epNum + 1))
                                        return ep + " \u2192 " + nextEp
                                    }
                                }
                                return ep
                            }
                            font.pixelSize: 11
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: palette.base
            radius: 4

            CustomListView {
                id: historyList
                anchors.fill: parent
                model: ListModel {
                    id: historyModel
                }
                onItemClicked: (item) => {
                    stackView.push(animeScreen, { anime: Object.assign({}, item) })
                }
                Component.onCompleted: {
                    historyList.addContextMenuItem({
                        title: "Open Details",
                        action: "goto_details",
                        group: "main"
                    })
                    historyList.addContextMenuItem({
                        title: "Next Episode",
                        action: "next_episode",
                        group: "main"
                    })
                    historyList.addContextMenuItem({
                        title: "Remove Item",
                        action: "delete",
                        group: "dangerous",
                        color: "#EF5350"
                    })
                }
                onContextMenuAction: function(action, item) {
                    switch(action) {
                        case "goto_details":
                            historyList.onItemClicked(item)
                            break
                        case "next_episode":
                            item.next_episode = true
                            historyList.onItemClicked(item)
                            break
                        case "delete":
                            databaseBackend.delete(item.id)
                            break
                    }
                }
            }
        }
    }
}
