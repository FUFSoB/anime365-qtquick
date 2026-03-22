import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    padding: 12

    function updateHistory() {
        var history = databaseBackend.get_list()
        historyModel.clear()
        for (var i = 0; i < history.length; i++) {
            historyModel.append(history[i])
        }
    }

    Component.onCompleted: {
        updateHistory()
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

        StyledButton {
            Layout.fillWidth: true
            text: "Tracker List"
            onClicked: console.log("Tracker List clicked")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledButton {
                Layout.fillWidth: true
                text: "Open uGet"
                visible: !isAndroid
                enabled: settingsBackend.is_valid_binary(settingsBackend.get("uget_path"))
                onClicked: animeBackend.open_uget()
            }

            StyledButton {
                Layout.fillWidth: true
                text: "Settings"
                onClicked: stackView.push(settingsScreen)
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
