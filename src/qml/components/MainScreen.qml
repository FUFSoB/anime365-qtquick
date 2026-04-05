import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    objectName: "mainScreen"
    padding: 12

    function focusSearch() { searchField.forceActiveFocus() }
    function handleBack() {} // root screen — no action

    property string updateTag: ""
    property string updateUrl: ""
    property string currentVersion: ""
    property bool updateAvailable: false

    Connections {
        target: updaterBackend
        function onUpdate_found(tag, url, current) {
            updateTag = tag
            updateUrl = url
            currentVersion = current
            updateAvailable = true
        }
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

        Pane {
            Layout.fillWidth: true
            visible: updateAvailable
            padding: 8

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    textFormat: Text.RichText
                    text: `Update available: ${currentVersion} \u2192 <a href='${updateUrl}'>${updateTag}</a>`
                    onLinkActivated: (url) => Qt.openUrlExternally(url)
                    HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }

                StyledButton {
                    text: "\u2715"
                    implicitWidth: 28
                    implicitHeight: 28
                    leftPadding: 0
                    rightPadding: 0
                    onClicked: updateAvailable = false
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
                Layout.preferredHeight: 248
                orientation: ListView.Horizontal
                spacing: 10
                clip: true

                model: ListModel {
                    id: continueWatchingModel
                }

                delegate: Rectangle {
                    id: cwDelegateRoot
                    width: 160
                    height: 240
                    radius: 6
                    clip: true
                    color: palette.alternateBase

                    property bool isDestroyed: false
                    Component.onDestruction: isDestroyed = true

                    // Full-bleed cover image
                    Image {
                        id: cwImage
                        anchors.fill: parent
                        source: model.image_url ? imageCacheBackend.cache_image(model.image_url) : ""
                        fillMode: Image.PreserveAspectCrop
                        cache: true
                        asynchronous: true
                        Connections {
                            target: imageCacheBackend
                            enabled: !cwDelegateRoot.isDestroyed
                            function onImage_downloaded(origUrl, localUrl) {
                                if (!cwDelegateRoot.isDestroyed && model.image_url && origUrl === model.image_url)
                                    cwImage.source = localUrl
                            }
                        }
                    }

                    // Bottom gradient overlay
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 88
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.78) }
                        }
                    }

                    // Text over gradient
                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        spacing: 2

                        Text {
                            width: parent.width
                            text: model.title || ""
                            font.pixelSize: 12
                            font.bold: true
                            color: "white"
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
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
                            color: "white"
                            opacity: 0.78
                            elide: Text.ElideRight
                        }
                    }

                    // Hover highlight overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: cwMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

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
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: historyModel.count > 0

            Label {
                text: "Watch History"
                font.pixelSize: 13
                font.bold: true
                opacity: 0.75
            }

            Label {
                text: historyModel.count + " titles"
                font.pixelSize: 11
                opacity: 0.40
            }

            Item { Layout.fillWidth: true }
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
