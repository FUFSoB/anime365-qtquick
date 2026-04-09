import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    objectName: "downloadScreen"
    padding: 12

    property bool showHistory: false

    function handleBack() { stackView.pop() }

    readonly property bool mpvAvailable: settingsBackend && settingsBackend.is_valid_binary(settingsBackend.get("mpv_path"))
    readonly property bool vlcAvailable: settingsBackend && settingsBackend.is_valid_binary(settingsBackend.get("vlc_path"))
    readonly property bool mpcAvailable: isWindows && settingsBackend && settingsBackend.is_valid_binary(settingsBackend.get("mpc_path"))

    Globals { id: globals }

    function statusLabel(s) {
        switch (s) {
            case "active":   return "\u25B6 Downloading"
            case "complete": return "\u2714 Complete"
            case "error":    return "\u2716 Error"
            case "paused":   return "\u23F8 Paused"
            case "waiting":  return "\u23F3 Waiting"
            default:         return s
        }
    }

    function statusStripeColor(s) {
        switch (s) {
            case "complete": return globals.colorSuccess
            case "error":    return globals.colorError
            case "paused":   return globals.colorWarning
            case "active":   return palette.highlight
            default:         return palette.mid
        }
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
        for (var i = 0; i < items.length; i++)
            downloadModel.append(items[i])
        loadHistory()
    }

    Connections {
        target: downloaderBackend
        function onDownloads_updated(items) {
            downloadModel.clear()
            for (var i = 0; i < items.length; i++)
                downloadModel.append(items[i])
        }
        function onHistory_updated(items) {
            historyModel.clear()
            for (var i = 0; i < items.length; i++)
                historyModel.append(items[i])
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── aria2c notice ──────────────────────────────────────────────────
        Rectangle {
            visible: !downloaderBackend.has_aria2
            Layout.fillWidth: true
            implicitHeight: ariaRow.implicitHeight + 16
            color: "#1490CAF5"
            radius: 6
            border.color: "#3590CAF5"

            RowLayout {
                id: ariaRow
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.margins: 12
                spacing: 10

                Label {
                    Layout.fillWidth: true
                    text: "\u2139\uFE0E  <b>aria2c</b> is recommended — supports resuming, parallel connections and faster speeds."
                    textFormat: Text.RichText
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                }

                StyledButton {
                    text: "Configure"
                    onClicked: stackView.push(settingsScreen)
                }
            }
        }

        // ── Header: segmented tabs + clear ────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Segmented control
            Rectangle {
                implicitWidth: 230
                implicitHeight: 36
                radius: 8
                color: palette.alternateBase

                RowLayout {
                    anchors { fill: parent; margins: 3 }
                    spacing: 2

                    // Active tab
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: !showHistory ? palette.highlight : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Label {
                                text: "Active"
                                font.pixelSize: 13
                                font.bold: !showHistory
                                color: !showHistory ? palette.highlightedText : palette.windowText
                            }

                            Rectangle {
                                visible: downloadModel.count > 0
                                radius: 8
                                implicitWidth: Math.max(18, activeCountLabel.implicitWidth + 8)
                                implicitHeight: 16
                                color: !showHistory ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0.5, 0.5, 0.5, 0.22)

                                Label {
                                    id: activeCountLabel
                                    anchors.centerIn: parent
                                    text: downloadModel.count
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: !showHistory ? palette.highlightedText : palette.windowText
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showHistory = false
                        }
                    }

                    // History tab
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: showHistory ? palette.highlight : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Label {
                                text: "History"
                                font.pixelSize: 13
                                font.bold: showHistory
                                color: showHistory ? palette.highlightedText : palette.windowText
                            }

                            Rectangle {
                                visible: historyModel.count > 0
                                radius: 8
                                implicitWidth: Math.max(18, histCountLabel.implicitWidth + 8)
                                implicitHeight: 16
                                color: showHistory ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0.5, 0.5, 0.5, 0.22)

                                Label {
                                    id: histCountLabel
                                    anchors.centerIn: parent
                                    text: historyModel.count
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: showHistory ? palette.highlightedText : palette.windowText
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showHistory = true
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            StyledButton {
                text: showHistory ? "Clear History" : "Clear Completed"
                onClicked: clearConfirmDialog.open()
            }
        }

        Dialog {
            id: clearConfirmDialog
            anchors.centerIn: parent
            width: 360
            title: showHistory ? "Clear History" : "Clear Completed"
            standardButtons: Dialog.Ok | Dialog.Cancel
            Label {
                width: parent.width
                text: showHistory
                    ? "Remove all download history entries?"
                    : "Remove all completed downloads from the queue?"
                wrapMode: Text.WordWrap
            }
            onAccepted: {
                if (showHistory) downloaderBackend.clear_history()
                else             downloaderBackend.clear_completed()
            }
        }

        // ── Content area ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: palette.base
            radius: 6

            // ── Active downloads ──────────────────────────────────────────
            ListView {
                id: downloadList
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                spacing: 6
                visible: !showHistory

                model: ListModel { id: downloadModel }

                delegate: Rectangle {
                    id: dlCard
                    width: downloadList.width
                    height: dlCol.implicitHeight + 20
                    radius: 6
                    color: palette.alternateBase

                    // Left status stripe
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        anchors.topMargin: 6; anchors.bottomMargin: 6
                        width: 3
                        radius: 2
                        color: statusStripeColor(model.status)
                    }

                    ColumnLayout {
                        id: dlCol
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        anchors.leftMargin: 14; anchors.rightMargin: 10
                        spacing: 6

                        // Row 1: filename + status badge
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                Layout.fillWidth: true
                                text: model.filename
                                font.bold: true
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                            }

                            Rectangle {
                                radius: 4
                                implicitWidth: dlStatusLabel.implicitWidth + 10
                                implicitHeight: 20
                                color: {
                                    switch (model.status) {
                                        case "complete": return Qt.rgba(0.298, 0.686, 0.314, 0.18)
                                        case "error":    return Qt.rgba(0.937, 0.325, 0.314, 0.18)
                                        case "paused":   return Qt.rgba(1.0,   0.596, 0.0,   0.18)
                                        default:         return Qt.rgba(0.5,   0.5,   0.5,   0.14)
                                    }
                                }

                                Label {
                                    id: dlStatusLabel
                                    anchors.centerIn: parent
                                    text: statusLabel(model.status)
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: {
                                        switch (model.status) {
                                            case "complete": return globals.colorSuccess
                                            case "error":    return globals.colorError
                                            case "paused":   return globals.colorWarning
                                            default:         return palette.windowText
                                        }
                                    }
                                }
                            }
                        }

                        // Error message
                        Label {
                            Layout.fillWidth: true
                            visible: model.status === "error" && (model.error_message || "") !== ""
                            text: model.error_message || ""
                            color: globals.colorError
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        // Row 2: progress + size/speed
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ProgressBar {
                                Layout.fillWidth: true
                                from: 0; to: 1
                                value: model.progress
                            }

                            Label {
                                Layout.preferredWidth: 190
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 11
                                opacity: 0.65
                                text: {
                                    var parts = []
                                    if (model.total_size > 0)
                                        parts.push(globals.formatSize(model.downloaded) + " / " + globals.formatSize(model.total_size))
                                    if (model.status === "active" && model.speed > 0)
                                        parts.push(globals.formatSpeed(model.speed))
                                    return parts.join("   ")
                                }
                            }
                        }

                        // Row 3: action buttons
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Item { Layout.fillWidth: true }

                            StyledButton {
                                implicitWidth: 32; implicitHeight: 28
                                leftPadding: 0; rightPadding: 0
                                text: model.status === "paused" ? "\u25B6" : "\u23F8"
                                visible: model.pausable && (model.status === "active" || model.status === "paused")
                                onClicked: {
                                    if (model.status === "paused") downloaderBackend.resume_download(model.gid)
                                    else                           downloaderBackend.pause_download(model.gid)
                                }
                            }

                            StyledButton {
                                text: "Retry"
                                visible: model.status === "error"
                                onClicked: downloaderBackend.retry_download(model.gid)
                            }

                            StyledButton {
                                implicitWidth: 28; implicitHeight: 28
                                leftPadding: 0; rightPadding: 0
                                text: "\u2715"
                                visible: model.status !== "complete"
                                onClicked: downloaderBackend.cancel_download(model.gid)
                            }

                            StyledButton {
                                text: "mpv"
                                visible: model.status === "complete" && mpvAvailable && globals.isVideoFile(model.filename)
                                onClicked: { var p = downloaderBackend.get_local_file(model.filename); if (p) animeBackend.launch_mpv(p, "", model.filename, "") }
                            }

                            StyledButton {
                                text: "VLC"
                                visible: model.status === "complete" && vlcAvailable && globals.isVideoFile(model.filename)
                                onClicked: { var p = downloaderBackend.get_local_file(model.filename); if (p) animeBackend.launch_vlc(p, "", model.filename, "") }
                            }

                            StyledButton {
                                text: "MPC-HC"
                                visible: model.status === "complete" && mpcAvailable && globals.isVideoFile(model.filename)
                                onClicked: { var p = downloaderBackend.get_local_file(model.filename); if (p) animeBackend.launch_mpc(p, "", model.filename, "") }
                            }
                        }
                    }
                }

                // Empty state
                Column {
                    anchors.centerIn: parent
                    visible: downloadModel.count === 0
                    spacing: 6

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\u23F3"
                        font.pixelSize: 36
                        opacity: 0.20
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Queue is empty"
                        font.pixelSize: 15
                        opacity: 0.40
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Downloads started from the anime screen will appear here"
                        font.pixelSize: 11
                        opacity: 0.28
                    }
                }
            }

            // ── History ───────────────────────────────────────────────────
            ListView {
                id: historyList
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                spacing: 6
                visible: showHistory

                model: ListModel { id: historyModel }

                delegate: Rectangle {
                    id: histCard
                    width: historyList.width
                    height: histCol.implicitHeight + 20
                    radius: 6
                    color: palette.alternateBase

                    // Left accent stripe (complete = green)
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        anchors.topMargin: 6; anchors.bottomMargin: 6
                        width: 3
                        radius: 2
                        color: globals.colorSuccess
                        opacity: 0.7
                    }

                    ColumnLayout {
                        id: histCol
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        anchors.leftMargin: 14; anchors.rightMargin: 10
                        spacing: 6

                        // Row 1: filename + date
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                Layout.fillWidth: true
                                text: model.filename
                                font.bold: true
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                            }

                            Label {
                                text: globals.formatDate(model.timestamp)
                                font.pixelSize: 11
                                opacity: 0.50
                            }
                        }

                        // Row 2: metadata badges + action buttons
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // Metadata badges
                            Row {
                                spacing: 4

                                Rectangle {
                                    visible: (model.size || 0) > 0
                                    radius: 3
                                    width: histSizeLabel.implicitWidth + 10; height: 18
                                    color: Qt.rgba(0.5, 0.5, 0.5, 0.14)
                                    Label { id: histSizeLabel; anchors.centerIn: parent; text: globals.formatSize(model.size); font.pixelSize: 10; opacity: 0.70 }
                                }

                                Rectangle {
                                    visible: (model.translation || "") !== ""
                                    radius: 3
                                    width: histTlLabel.implicitWidth + 10; height: 18
                                    color: Qt.rgba(0.5, 0.5, 0.5, 0.14)
                                    Label { id: histTlLabel; anchors.centerIn: parent; text: model.translation || ""; font.pixelSize: 10; opacity: 0.70 }
                                }

                                Rectangle {
                                    visible: (model.quality || "") !== ""
                                    radius: 3
                                    width: histQualLabel.implicitWidth + 10; height: 18
                                    color: Qt.rgba(0.5, 0.5, 0.5, 0.14)
                                    Label { id: histQualLabel; anchors.centerIn: parent; text: model.quality || ""; font.pixelSize: 10; opacity: 0.70 }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Play buttons
                            StyledButton {
                                text: "mpv"
                                visible: mpvAvailable && globals.isVideoFile(model.filename)
                                onClicked: { var p = downloaderBackend.get_local_file(model.filename); if (p) animeBackend.launch_mpv(p, "", model.filename, "") }
                            }

                            StyledButton {
                                text: "VLC"
                                visible: vlcAvailable && globals.isVideoFile(model.filename)
                                onClicked: { var p = downloaderBackend.get_local_file(model.filename); if (p) animeBackend.launch_vlc(p, "", model.filename, "") }
                            }

                            StyledButton {
                                text: "MPC-HC"
                                visible: mpcAvailable && globals.isVideoFile(model.filename)
                                onClicked: { var p = downloaderBackend.get_local_file(model.filename); if (p) animeBackend.launch_mpc(p, "", model.filename, "") }
                            }

                            StyledButton {
                                text: "Delete"
                                onClicked: downloaderBackend.delete_history_item(model.index)
                            }

                            StyledButton {
                                implicitWidth: 28; implicitHeight: 28
                                leftPadding: 0; rightPadding: 0
                                text: "\u2715"
                                onClicked: downloaderBackend.remove_history_item(model.index)
                            }
                        }
                    }
                }

                // Empty state
                Column {
                    anchors.centerIn: parent
                    visible: historyModel.count === 0
                    spacing: 6

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\u2205"
                        font.pixelSize: 36
                        opacity: 0.20
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No download history"
                        font.pixelSize: 15
                        opacity: 0.40
                    }
                }
            }
        }
    }
}
