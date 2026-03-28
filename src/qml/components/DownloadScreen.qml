import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    objectName: "downloadScreen"
    padding: 12

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

    Component.onCompleted: {
        var items = downloaderBackend.get_downloads()
        downloadModel.clear()
        for (var i = 0; i < items.length; i++) {
            downloadModel.append(items[i])
        }
    }

    Connections {
        target: downloaderBackend
        function onDownloads_updated(items) {
            downloadModel.clear()
            for (var i = 0; i < items.length; i++) {
                downloadModel.append(items[i])
            }
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

            Label {
                text: "Downloads"
                font.pixelSize: 18
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            StyledButton {
                text: "Clear Completed"
                onClicked: downloaderBackend.clear_completed()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: palette.base
            radius: 4

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
                                        case "active": return formatSpeed(model.speed)
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
                                text: model.total_size > 0
                                    ? formatSize(model.downloaded) + " / " + formatSize(model.total_size)
                                    : ""
                                font.pixelSize: 12
                                opacity: 0.7
                            }

                            StyledButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                leftPadding: 0
                                rightPadding: 0
                                text: model.status === "paused" ? "\u25B6" : "\u23F8"
                                visible: model.status === "active" || model.status === "paused"
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
    }
}
