import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ListView {
    id: root

    SystemPalette { id: pal }

    property var onItemClicked: function(item) {}
    property var onContextMenuAction: function(action, item) {}
    property var contextMenuModel: []

    function setContextMenu(menuModel) { contextMenuModel = menuModel }
    function addContextMenuItem(menuItem) { contextMenuModel.push(menuItem) }

    clip: true

    delegate: Item {
        id: delegateRoot
        width: ListView.view.width
        height: 108

        property bool isDestroyed: false
        Component.onDestruction: isDestroyed = true

        // Alternating row background
        Rectangle {
            anchors.fill: parent
            color: index % 2 === 0 ? "transparent" : pal.alternateBase
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    root.onItemClicked(model)
                } else if (mouse.button === Qt.RightButton) {
                    var windowPos = delegateRoot.mapToItem(null, mouse.x, mouse.y)
                    contextMenu.x = windowPos.x
                    contextMenu.y = windowPos.y
                    contextMenu.menuForItem = model
                    contextMenu.open()
                }
            }
        }

        Popup {
            id: contextMenu
            width: 220
            height: contextMenuListView.contentHeight
            padding: 0
            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
            focus: true
            property var menuForItem: null
            x: 0; y: 0
            parent: Overlay.overlay

            onAboutToShow: {
                var availableWidth = parent ? parent.width : 0
                var availableHeight = parent ? parent.height : 0
                if (x + width > availableWidth) x = availableWidth - width
                if (y + height > availableHeight) y = availableHeight - height
                if (x < 0) x = 0
                if (y < 0) y = 0
            }

            background: Rectangle {
                color: pal.base
                radius: 6
                border.color: pal.mid
                border.width: 1
            }

            ListView {
                id: contextMenuListView
                anchors.fill: parent
                model: root.contextMenuModel
                interactive: false
                clip: true

                delegate: Rectangle {
                    width: contextMenu.width
                    height: 36
                    color: delegateMouseArea.containsMouse ? pal.highlight : "transparent"

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        text: modelData.title
                        color: delegateMouseArea.containsMouse
                               ? pal.highlightedText
                               : (modelData.color || pal.text)
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: delegateMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.onContextMenuAction(modelData.action, contextMenu.menuForItem)
                            contextMenu.close()
                        }
                    }
                }

                section.property: "group"
                section.delegate: Rectangle {
                    width: contextMenu.width
                    height: 1
                    color: pal.mid
                    opacity: 0.4
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10

            // Cover image — clipped rect for aspect-crop
            Rectangle {
                Layout.preferredWidth: 62
                Layout.fillHeight: true
                radius: 4
                clip: true
                color: pal.alternateBase

                Image {
                    id: listItemImage
                    anchors.fill: parent
                    source: model.image_url ? imageCacheBackend.cache_image(model.image_url) : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                    asynchronous: true

                    Connections {
                        target: imageCacheBackend
                        enabled: !delegateRoot.isDestroyed
                        function onImage_downloaded(origUrl, localUrl) {
                            if (!delegateRoot.isDestroyed && model.image_url && origUrl === model.image_url)
                                listItemImage.source = localUrl
                        }
                    }
                }
            }

            // Info column
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 3

                // Title
                Text {
                    Layout.fillWidth: true
                    text: model.title || ""
                    color: pal.windowText
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }

                // Tags row: type · year · score
                Row {
                    spacing: 4

                    // Type badge
                    Rectangle {
                        visible: (model.h_type || "") !== ""
                        radius: 3
                        width: typeLabel.implicitWidth + 10
                        height: 18
                        color: Qt.rgba(0.5, 0.5, 0.5, 0.14)

                        Text {
                            id: typeLabel
                            anchors.centerIn: parent
                            text: (model.h_type || "").toUpperCase()
                            font.pixelSize: 10
                            font.bold: true
                            color: pal.windowText
                            opacity: 0.60
                        }
                    }

                    // Year badge
                    Rectangle {
                        visible: (model.year || 0) > 0
                        radius: 3
                        width: yearLabel.implicitWidth + 10
                        height: 18
                        color: Qt.rgba(0.5, 0.5, 0.5, 0.14)

                        Text {
                            id: yearLabel
                            anchors.centerIn: parent
                            text: model.year || ""
                            font.pixelSize: 10
                            color: pal.windowText
                            opacity: 0.60
                        }
                    }

                    // Score badge (green / orange / red)
                    Rectangle {
                        property real scoreVal: parseFloat(model.score) || 0
                        visible: scoreVal > 0
                        radius: 3
                        width: scoreLabel.implicitWidth + 10
                        height: 18
                        color: {
                            if (scoreVal >= 8.0) return Qt.rgba(0.298, 0.686, 0.314, 0.18)
                            if (scoreVal >= 6.5) return Qt.rgba(1.0,  0.596, 0.0,   0.18)
                            return                       Qt.rgba(0.937, 0.325, 0.314, 0.18)
                        }

                        Text {
                            id: scoreLabel
                            anchors.centerIn: parent
                            text: "\u2605 " + (parseFloat(model.score) || 0).toFixed(1)
                            font.pixelSize: 10
                            font.bold: true
                            color: {
                                var s = parseFloat(model.score) || 0
                                if (s >= 8.0) return "#4CAF50"
                                if (s >= 6.5) return "#FF9800"
                                return "#EF5350"
                            }
                        }
                    }
                }

                // Episode progress (watch history)
                Text {
                    Layout.fillWidth: true
                    visible: (model.episode || "") !== ""
                    text: {
                        var ep    = model.episode || ""
                        var total = model.total_episodes || 0
                        var tl    = model.translation || ""
                        var base  = ep + (total > 0 ? " / " + total : "")
                        return tl ? base + "  \u00B7  " + tl : base
                    }
                    font.pixelSize: 12
                    color: pal.highlight
                    elide: Text.ElideRight
                }

                // Episode count (search results)
                Text {
                    Layout.fillWidth: true
                    visible: (model.episode === undefined || model.episode === "") &&
                             (model.total_episodes || 0) > 0
                    text: model.total_episodes + " ep"
                    font.pixelSize: 12
                    color: pal.windowText
                    opacity: 0.55
                }

                // Genres
                Text {
                    Layout.fillWidth: true
                    visible: (model.genres || "") !== ""
                    text: model.genres || ""
                    font.pixelSize: 11
                    color: pal.windowText
                    opacity: 0.50
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }
            }
        }

        // Hover overlay (rendered on top of content, below pointer)
        Rectangle {
            anchors.fill: parent
            color: pal.highlight
            opacity: mouseArea.containsMouse ? 0.12 : 0
            Behavior on opacity { NumberAnimation { duration: 80 } }
        }

        // Row separator
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: pal.mid
            opacity: 0.25
        }
    }
}
