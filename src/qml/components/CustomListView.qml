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

    // Smooth gradient: red(0) → orange(6.0) → green(7.5) → vivid-green(10)
    function scoreColor(score) {
        var s = Math.max(0, Math.min(10, parseFloat(score) || 0))
        var r, g, b
        if (s >= 7.5) {
            var t = (s - 7.5) / 2.5
            r = 0.298 * (1 - t)
            g = 0.686 + t * (0.902 - 0.686)
            b = 0.314 + t * (0.463 - 0.314)
        } else if (s >= 6.0) {
            var t = (s - 6.0) / 1.5
            r = 1.000 - t * (1.000 - 0.298)
            g = 0.596 + t * (0.686 - 0.596)
            b = t * 0.314
        } else {
            var t = s / 6.0
            r = 0.827 + t * (1.000 - 0.827)
            g = 0.184 + t * (0.596 - 0.184)
            b = 0.184 * (1 - t)
        }
        return Qt.rgba(r, g, b, 1.0)
    }

    clip: true

    delegate: Item {
        id: delegateRoot
        width: ListView.view.width
        height: 112

        property bool isDestroyed: false
        Component.onDestruction: isDestroyed = true

        // Alternating row background
        Rectangle {
            anchors.fill: parent
            color: index % 2 === 0 ? "transparent" : pal.alternateBase
        }

        // Left watch-progress bar
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3

            // Track (always visible, subtle)
            Rectangle {
                anchors.fill: parent
                color: pal.mid
                opacity: 0.20
            }

            // Fill (proportional to episode progress)
            Rectangle {
                // episodeFull format: "ONA 1 серия", "TV SP 3 серия", "1 серия", "Фильм", "Трейлер"
                property real ep: {
                    var s = (model.episode || "").trim()
                    if (!s || s === "\u0422\u0440\u0435\u0439\u043b\u0435\u0440") return 0  // empty or "Трейлер"
                    var m = s.match(/(\d+)\s+\u0441\u0435\u0440\u0438\u044f/)  // "N серия"
                    if (m) return parseFloat(m[1])
                    return 1  // "Фильм" or other single-episode strings
                }
                property real total: parseFloat(model.total_episodes) || 0
                property real frac:  (total > 0 && ep > 0) ? Math.min(ep / total, 1.0) : 0

                visible: frac > 0
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * frac
                color: pal.highlight
                opacity: 0.80
            }
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
            anchors.leftMargin: 11   // 3px accent + 8px gap
            anchors.rightMargin: 8
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 10

            // Cover image — clipped rect for aspect-crop
            Rectangle {
                Layout.preferredWidth: 68
                Layout.fillHeight: true
                radius: 5
                clip: true
                color: pal.alternateBase

                // Subtle gradient placeholder
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(0.5, 0.5, 0.5, 0.08) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.5, 0.5, 0.5, 0.18) }
                    }
                    visible: listItemImage.status !== Image.Ready
                }

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

                BusyIndicator {
                    anchors.centerIn: parent
                    running: listItemImage.status === Image.Loading
                    visible: running
                    width: 24
                    height: 24
                    padding: 0
                }
            }

            // Info column
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

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

                    // Type badge — colour-coded by type
                    Rectangle {
                        visible: (model.h_type || "") !== ""
                        radius: 4
                        width: typeLabel.implicitWidth + 12
                        height: 19
                        color: {
                            switch ((model.h_type || "").toLowerCase()) {
                                case "tv":      return Qt.rgba(0.129, 0.588, 0.953, 0.15)
                                case "movie":   return Qt.rgba(0.612, 0.153, 0.690, 0.15)
                                case "ova":     return Qt.rgba(0.000, 0.588, 0.533, 0.15)
                                case "ona":     return Qt.rgba(0.000, 0.588, 0.533, 0.15)
                                case "special": return Qt.rgba(1.000, 0.596, 0.000, 0.15)
                                default:        return Qt.rgba(0.5,   0.5,   0.5,   0.12)
                            }
                        }
                        border.color: Qt.rgba(0.5, 0.5, 0.5, 0.12)
                        border.width: 1

                        Text {
                            id: typeLabel
                            anchors.centerIn: parent
                            text: (model.h_type || "").toUpperCase()
                            font.pixelSize: 11
                            font.bold: true
                            color: {
                                switch ((model.h_type || "").toLowerCase()) {
                                    case "tv":      return "#2196F3"
                                    case "movie":   return "#9C27B0"
                                    case "ova":     return "#009688"
                                    case "ona":     return "#009688"
                                    case "special": return "#FF9800"
                                    default:        return pal.windowText
                                }
                            }
                            opacity: 0.85
                        }
                    }

                    // Year badge
                    Rectangle {
                        visible: (model.year || 0) > 0
                        radius: 4
                        width: yearLabel.implicitWidth + 12
                        height: 19
                        color: Qt.rgba(0.5, 0.5, 0.5, 0.10)
                        border.color: Qt.rgba(0.5, 0.5, 0.5, 0.12)
                        border.width: 1

                        Text {
                            id: yearLabel
                            anchors.centerIn: parent
                            text: model.year || ""
                            font.pixelSize: 11
                            color: pal.windowText
                            opacity: 0.60
                        }
                    }

                    // Score badge — continuous gradient
                    Rectangle {
                        property real scoreVal: parseFloat(model.score) || 0
                        property color sc: scoreVal > 0 ? root.scoreColor(scoreVal) : "transparent"
                        visible: scoreVal > 0
                        radius: 4
                        width: scoreLabel.implicitWidth + 12
                        height: 19
                        color: Qt.rgba(sc.r, sc.g, sc.b, 0.15)
                        border.color: Qt.rgba(sc.r, sc.g, sc.b, 0.30)
                        border.width: 1

                        Text {
                            id: scoreLabel
                            anchors.centerIn: parent
                            text: "\u2605 " + (parseFloat(model.score) || 0).toFixed(1)
                            font.pixelSize: 11
                            font.bold: true
                            color: parent.sc
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
                        var m = ep.match(/(\d+)\s+серия/)
                        var display = m ? m[1] + (total > 0 ? " / " + total : "") : ep
                        return tl ? display + "  \u00B7  " + tl : display
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
                    opacity: 0.45
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
