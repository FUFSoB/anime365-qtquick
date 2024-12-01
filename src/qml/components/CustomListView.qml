import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import Themes

ListView {
    id: root

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
        color: {
            return mouseArea.containsMouse ? Themes.currentTheme.elementHover :
                   (index % 2 == 0 ? "transparent" : Themes.currentTheme.thirdBackground)
        }

        ToolTip.visible: mouseArea.containsMouse && model.description !== ""
        ToolTip.text: model.description
        ToolTip.delay: 1000

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

                if (x + width > availableWidth) {
                    x = availableWidth - width
                }
                if (y + height > availableHeight) {
                    y = availableHeight - height
                }
                if (x < 0) x = 0
                if (y < 0) y = 0
            }


            background: Item {
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: -3
                    anchors.leftMargin: 1
                    anchors.rightMargin: -3
                    color: Qt.rgba(0, 0, 0, 0.2)
                    radius: parent.radius + 2
                    z: -1
                }

                Rectangle {
                    anchors.fill: parent
                    color: Themes.currentTheme.secondaryBackground
                    radius: 4
                    border.color: Themes.currentTheme.border
                    border.width: 1
                }
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
                           ? Themes.currentTheme.elementHover
                           : "transparent"

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
                            color: modelData.color || Themes.currentTheme.text
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
                    color: Themes.currentTheme.border
                }
            }
        }

        Row {
            spacing: 10
            padding: 10

            Image {
                width: 120
                height: 120
                source: model.image_url
                fillMode: Image.PreserveAspectFit
                cache: true
                asynchronous: true
            }

            Column {
                spacing: 5

                Text {
                    text: model.title
                    color: Themes.currentTheme.text
                    font.bold: true
                    font.pixelSize: 16
                }

                Text {
                    text: `Episodes: ${model.total_episodes}`
                    color: Themes.currentTheme.text
                    font.pixelSize: 14
                }

                Text {
                    text: `Genres: ${model.genres}`
                    color: Themes.currentTheme.text
                    font.pixelSize: 14
                }

                Text {
                    text: `Type: ${model.h_type} | Year: ${model.year}`
                    color: Themes.currentTheme.text
                    font.pixelSize: 14
                }

                Text {
                    text: `Score: ${model.score}`
                    color: Themes.currentTheme.text
                    font.pixelSize: 14
                }
            }
        }
    }
}
