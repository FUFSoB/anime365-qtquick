import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Grid view for anime cards with cover images, titles, and badges
GridView {
    id: gridRoot

    property var contextMenuItems: []
    signal itemClicked(var item)
    signal contextMenuAction(string action, var item)

    function addContextMenuItem(item) {
        contextMenuItems.push(item)
    }

    Globals { id: globals }
    SystemPalette { id: pal; colorGroup: SystemPalette.Active }

    cellWidth: 170
    cellHeight: 280
    clip: true

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    delegate: Rectangle {
        id: delegateRoot
        width: gridRoot.cellWidth - 10
        height: gridRoot.cellHeight - 10
        radius: 6
        clip: true
        color: pal.alternateBase

        property bool isDestroyed: false
        property bool _hovered: false
        Component.onDestruction: isDestroyed = true

        // Cover image
        AsyncImage {
            id: coverImage
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.65
            radius: 6
            source: model.image_url || ""
        }

        // Info section below image
        ColumnLayout {
            anchors.top: coverImage.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            spacing: 4

            // Title
            Label {
                Layout.fillWidth: true
                text: model.title || ""
                font.pixelSize: 12
                font.bold: true
                color: pal.windowText
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            // Badges row
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Type badge
                Rectangle {
                    visible: model.type !== undefined
                    implicitWidth: typeLabel.implicitWidth + 8
                    implicitHeight: 18
                    radius: 3
                    color: {
                        var t = (model.type || "").toLowerCase()
                        if (t === "tv") return Qt.rgba(0.129, 0.588, 0.953, 0.2)
                        if (t === "movie") return Qt.rgba(0.612, 0.153, 0.690, 0.2)
                        if (t === "ova" || t === "ona") return Qt.rgba(0, 0.588, 0.533, 0.2)
                        return Qt.rgba(0.5, 0.5, 0.5, 0.15)
                    }
                    Label {
                        id: typeLabel
                        anchors.centerIn: parent
                        text: (model.type || "").toUpperCase()
                        font.pixelSize: 10
                        font.bold: true
                        color: {
                            var t = (model.type || "").toLowerCase()
                            if (t === "tv") return "#2196F3"
                            if (t === "movie") return "#9C27B0"
                            if (t === "ova" || t === "ona") return "#009688"
                            return pal.windowText
                        }
                    }
                }

                // Score badge
                Rectangle {
                    visible: model.score !== undefined && model.score > 0
                    implicitWidth: scoreLabel.implicitWidth + 8
                    implicitHeight: 18
                    radius: 3
                    color: Qt.rgba(globals.scoreColor(model.score).r,
                                   globals.scoreColor(model.score).g,
                                   globals.scoreColor(model.score).b, 0.2)
                    Label {
                        id: scoreLabel
                        anchors.centerIn: parent
                        text: model.score ? model.score.toFixed(1) : ""
                        font.pixelSize: 10
                        font.bold: true
                        color: globals.scoreColor(model.score)
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Year and episodes
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Label {
                    visible: model.year !== undefined && model.year > 0
                    text: model.year || ""
                    font.pixelSize: 10
                    color: pal.windowText
                    opacity: 0.6
                }

                Label {
                    visible: model.total_episodes !== undefined && model.total_episodes > 0
                    text: model.total_episodes + " ep"
                    font.pixelSize: 10
                    color: pal.windowText
                    opacity: 0.6
                }

                Item { Layout.fillWidth: true }
            }
        }

        // Hover overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: pal.highlight
            opacity: delegateRoot._hovered ? 0.12 : 0
            Behavior on opacity { NumberAnimation { duration: 80 } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onEntered: delegateRoot._hovered = true
            onExited: delegateRoot._hovered = false

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    contextMenu.itemData = {
                        id: model.id,
                        title: model.title,
                        image_url: model.image_url,
                        type: model.type,
                        score: model.score,
                        year: model.year,
                        total_episodes: model.total_episodes,
                        episode_list: model.episode_list,
                        episode_ids: model.episode_ids,
                        hentai: model.hentai,
                        h_type: model.h_type,
                        description: model.description,
                        genres: model.genres,
                        mal_id: model.mal_id,
                        world_art_id: model.world_art_id,
                        anidb_id: model.anidb_id,
                        ann_id: model.ann_id,
                        anime365_url: model.anime365_url
                    }
                    contextMenu.popup()
                } else {
                    gridRoot.itemClicked({
                        id: model.id,
                        title: model.title,
                        image_url: model.image_url,
                        type: model.type,
                        score: model.score,
                        year: model.year,
                        total_episodes: model.total_episodes,
                        episode_list: model.episode_list,
                        episode_ids: model.episode_ids,
                        hentai: model.hentai,
                        h_type: model.h_type,
                        description: model.description,
                        genres: model.genres,
                        mal_id: model.mal_id,
                        world_art_id: model.world_art_id,
                        anidb_id: model.anidb_id,
                        ann_id: model.ann_id,
                        anime365_url: model.anime365_url
                    })
                }
            }
        }

        // Context menu
        Menu {
            id: contextMenu
            property var itemData: ({})

            Repeater {
                model: gridRoot.contextMenuItems
                delegate: MenuItem {
                    text: modelData.title
                    onTriggered: gridRoot.contextMenuAction(modelData.action, contextMenu.itemData)
                }
            }
        }
    }
}
