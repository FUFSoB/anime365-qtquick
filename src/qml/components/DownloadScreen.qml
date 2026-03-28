import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    objectName: "downloadScreen"
    padding: 12

    property bool showHistory: false

    readonly property bool mpvAvailable: settingsBackend && settingsBackend.is_valid_binary(settingsBackend.get("mpv_path"))
    readonly property bool vlcAvailable: settingsBackend && settingsBackend.is_valid_binary(settingsBackend.get("vlc_path"))

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec <= 0) return ""
        if (bytesPerSec < 1024) return bytesPerSec + " B/s"
        if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
    }

    function formatSize(bytes) {
        if (bytes <= 0) return ""
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(0) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    function formatDate(timestamp) {
        if (!timestamp) return ""
        var d = new Date(timestamp * 1000)
        var now = new Date()
        var pad = (n) => n < 10 ? "0" + n : "" + n
        var time = pad(d.getHours()) + ":" + pad(d.getMinutes())
        if (d.toDateString() === now.toDateString())
            return "Today " + time
        var yesterday = new Date(now)
        yesterday.setDate(yesterday.getDate() - 1)
        if (d.toDateString() === yesterday.toDateString())
            return "Yesterday " + time
        return pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + d.getFullYear() + " " + time
    }

    function loadHistory() {
        var items = downloaderBackend.get_history()
        historyModel.clear()
        for (var i = 0; i < items.length; i++)
            historyModel.append(items[i])
    }

    Component.onCompleted: {
        var items = downloaderBackend.get_downloads()
        downloadModel.clear()
        for (var i = 0; i < items.length; i++) {
            downloadModel.append(items[i])
        }
        loadHistory()
    }

    Connections {
        target: downloaderBackend
        function onDownloads_updated(items) {
            downloadModel.clear()
            for (var i = 0; i < items.length; i++) {
                downloadModel.append(items[i])
            }
        }
        function onHistory_updated(items) {
            historyModel.clear()
            for (var i = 0; i < items.length; i++)
                historyModel.append(items[i])
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

            StyledButton {
                text: "Active"
                flat: !showHistory
                highlighted: !showHistory
                onClicked: showHistory = false
            }

            StyledButton {
                text: "History"
                flat: !showHistory
                highlighted: showHistory
                onClicked: showHistory = true
            }

            Item { Layout.fillWidth: true }

            StyledButton {
                text: showHistory ? "Clear History" : "Clear Completed"
                onClicked: {
                    if (showHistory)
                        downloaderBackend.clear_history()
                    else
                        downloaderBackend.clear_completed()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: palette.base
            radius: 4
            visible: !showHistory

            ListView {
                id: downloadList
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                spacing: 2

                model: ListModel {
                    id: downloadModel
                }

                delegate: Rectangle {
                    width: downloadList.width
                    height: 72
                    radius: 4
                    color: index % 2 === 0 ? "transparent" : palette.alternateBase

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                Layout.fillWidth: true
                                text: model.filename
                                font.bold: true
                                elide: Text.ElideMiddle
                            }

                            Label {
                                text: {
                                    switch (model.status) {
                                        case "active": return "Downloading"
                                        case "complete": return "Complete"
                                        case "error": return "Error"
                                        case "paused": return "Paused"
                                        case "waiting": return "Waiting"
                                        default: return model.status
                                    }
                                }
                                color: {
                                    switch (model.status) {
                                        case "complete": return "#4CAF50"
                                        case "error": return "#EF5350"
                                        case "paused": return "#FF9800"
                                        default: return palette.text
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ProgressBar {
                                Layout.fillWidth: true
                                from: 0
                                to: 1
                                value: model.progress
                            }

                            Label {
                                Layout.preferredWidth: 180
                                horizontalAlignment: Text.AlignRight
                                text: {
                                    var parts = []
                                    if (model.total_size > 0)
                                        parts.push(formatSize(model.downloaded) + " / " + formatSize(model.total_size))
                                    if (model.status === "active" && model.speed > 0)
                                        parts.push(formatSpeed(model.speed))
                                    return parts.join("  ")
                                }
                                font.pixelSize: 12
                                opacity: 0.7
                            }

                            StyledButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                leftPadding: 0
                                rightPadding: 0
                                text: model.status === "paused" ? "\u25B6" : "\u23F8"
                                visible: model.pausable && (model.status === "active" || model.status === "paused")
                                onClicked: {
                                    if (model.status === "paused")
                                        downloaderBackend.resume_download(model.gid)
                                    else
                                        downloaderBackend.pause_download(model.gid)
                                }
                            }

                            StyledButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                leftPadding: 0
                                rightPadding: 0
                                text: "\u2715"
                                visible: model.status !== "complete"
                                onClicked: downloaderBackend.cancel_download(model.gid)
                            }

                            StyledButton {
                                text: "mpv"
                                visible: model.status === "complete" && mpvAvailable
                                    && (model.filename.endsWith(".mp4") || model.filename.endsWith(".mkv") || model.filename.endsWith(".webm"))
                                onClicked: {
                                    var path = downloaderBackend.get_local_file(model.filename)
                                    if (path)
                                        animeBackend.launch_mpv(path, "", model.filename, "")
                                }
                            }

                            StyledButton {
                                text: "VLC"
                                visible: model.status === "complete" && vlcAvailable
                                    && (model.filename.endsWith(".mp4") || model.filename.endsWith(".mkv") || model.filename.endsWith(".webm"))
                                onClicked: {
                                    var path = downloaderBackend.get_local_file(model.filename)
                                    if (path)
                                        animeBackend.launch_vlc(path, "", model.filename, "")
                                }
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "No downloads"
                    visible: downloadModel.count === 0
                    opacity: 0.5
                    font.pixelSize: 16
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: palette.base
            radius: 4
            visible: showHistory

            ListView {
                id: historyList
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                spacing: 2

                model: ListModel {
                    id: historyModel
                }

                delegate: Rectangle {
                    width: historyList.width
                    height: historyCol.implicitHeight + 16
                    radius: 4
                    color: index % 2 === 0 ? "transparent" : palette.alternateBase

                    ColumnLayout {
                        id: historyCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                Layout.fillWidth: true
                                text: model.filename
                                font.bold: true
                                elide: Text.ElideMiddle
                            }

                            Label {
                                text: formatDate(model.timestamp)
                                font.pixelSize: 12
                                opacity: 0.6
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: {
                                    var parts = []
                                    if (model.size > 0)
                                        parts.push(formatSize(model.size))
                                    if (model.translation || false)
                                        parts.push(model.translation)
                                    if (model.quality || false)
                                        parts.push(model.quality)
                                    return parts.join("  \u2022  ")
                                }
                                font.pixelSize: 12
                                opacity: 0.6
                            }

                            Item { Layout.fillWidth: true }

                            StyledButton {
                                text: "mpv"
                                visible: mpvAvailable
                                    && (model.filename.endsWith(".mp4") || model.filename.endsWith(".mkv") || model.filename.endsWith(".webm"))
                                onClicked: {
                                    var path = downloaderBackend.get_local_file(model.filename)
                                    if (path)
                                        animeBackend.launch_mpv(path, "", model.filename, "")
                                }
                            }

                            StyledButton {
                                text: "VLC"
                                visible: vlcAvailable
                                    && (model.filename.endsWith(".mp4") || model.filename.endsWith(".mkv") || model.filename.endsWith(".webm"))
                                onClicked: {
                                    var path = downloaderBackend.get_local_file(model.filename)
                                    if (path)
                                        animeBackend.launch_vlc(path, "", model.filename, "")
                                }
                            }

                            StyledButton {
                                text: "Delete"
                                onClicked: downloaderBackend.delete_history_item(model.index)
                            }

                            StyledButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                leftPadding: 0
                                rightPadding: 0
                                text: "\u2715"
                                onClicked: downloaderBackend.remove_history_item(model.index)
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "No download history"
                    visible: historyModel.count === 0
                    opacity: 0.5
                    font.pixelSize: 16
                }
            }
        }
    }
}
