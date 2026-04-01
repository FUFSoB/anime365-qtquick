import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ListView {
    id: root

    SystemPalette { id: pal }

    property var onItemClicked: function(item) {}

    property var onContextMenuAction: function(action, item) {
        console.log("Context Menu Action: " + action)
    }

    property var contextMenuModel: []

    function setContextMenu(menuModel) {
        contextMenuModel = menuModel
    }

    function addContextMenuItem(menuItem) {
        contextMenuModel.push(menuItem)
    }

    clip: true

    delegate: Rectangle {
        id: delegateRoot
        width: ListView.view.width
        height: 140
        color: mouseArea.containsMouse ? pal.highlight
             : (index % 2 == 0 ? "transparent" : pal.alternateBase)

        property bool isDestroyed: false
        Component.onDestruction: isDestroyed = true

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
            width: 250
            height: contextMenuListView.contentHeight
            padding: 0
            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
            focus: true

            property var menuForItem: null

            x: 0
            y: 0
            parent: Overlay.overlay

            onAboutToShow: {
                var availableWidth = parent ? parent.width : 0
                var availableHeight = parent ? parent.height : 0

                if (x + width > availableWidth)
                    x = availableWidth - width
                if (y + height > availableHeight)
                    y = availableHeight - height
                if (x < 0) x = 0
                if (y < 0) y = 0
            }

            background: Rectangle {
                color: pal.base
                radius: 4
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
                    color: delegateMouseArea.containsMouse
                           ? pal.highlight : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Image {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            source: modelData.icon || ""
                            fillMode: Image.PreserveAspectFit
                            visible: source !== ""
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            color: delegateMouseArea.containsMouse
                                   ? pal.highlightedText
                                   : (modelData.color || pal.text)
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }
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
                }
            }
        }

        Row {
            spacing: 10
            padding: 10

            Image {
                id: listItemImage
                width: 120
                height: 120
                source: model.image_url ? imageCacheBackend.cache_image(model.image_url) : ""
                fillMode: Image.PreserveAspectFit
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

            Column {
                spacing: 5

                Text {
                    text: model.title || ""
                    color: mouseArea.containsMouse ? pal.highlightedText : pal.windowText
                    font.bold: true
                    font.pixelSize: 16
                }

                Text {
                    text: `Episode "${model.episode || ""}" by "${model.translation || ""}" out of ${model.total_episodes || 0} episodes`
                    color: mouseArea.containsMouse ? pal.highlightedText : pal.highlight
                    visible: model.episode !== undefined && model.episode !== ""
                    font.pixelSize: 14
                }

                Text {
                    text: `Episodes: ${model.total_episodes || 0}`
                    color: mouseArea.containsMouse ? pal.highlightedText : pal.windowText
                    visible: model.episode === undefined || model.episode === ""
                    font.pixelSize: 14
                }

                Text {
                    text: `Genres: ${model.genres || ""}`
                    color: mouseArea.containsMouse ? pal.highlightedText : pal.windowText
                    font.pixelSize: 14
                }

                Text {
                    text: `Type: ${model.h_type || ""} | Year: ${model.year || ""}`
                    color: mouseArea.containsMouse ? pal.highlightedText : pal.windowText
                    font.pixelSize: 14
                }

                Text {
                    text: `Score: ${model.score || "N/A"}`
                    color: mouseArea.containsMouse ? pal.highlightedText : pal.windowText
                    font.pixelSize: 14
                }
            }
        }
    }
}
