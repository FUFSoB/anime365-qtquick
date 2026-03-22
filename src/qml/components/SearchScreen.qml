import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    property string searchQuery: ""
    padding: 12

    Component.onCompleted: {
        busyIndicator.running = true
    }

    Connections {
        target: searchBackend

        function onSearch_completed(results) {
            searchResultsModel.clear()
            for (var i = 0; i < results.length; i++) {
                searchResultsModel.append(results[i])
            }
            busyIndicator.running = false
        }

        function onSearch_error(errorMessage) {
            console.error("Search error:", errorMessage)
            busyIndicator.running = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledButton {
                id: backButton
                text: "\u2190 Back"
                onClicked: stackView.pop()
            }

            StyledTextField {
                id: searchField
                Layout.fillWidth: true
                text: searchQuery
                placeholderText: "Search anime"
                onAccepted: {
                    if (text.trim() !== "") {
                        searchBackend.perform_search(searchField.text.trim())
                        searchQuery = text
                        busyIndicator.running = true
                    }
                }
            }

            StyledButton {
                text: "Search"
                onClicked: {
                    if (searchField.text.trim() !== "") {
                        searchBackend.perform_search(searchField.text.trim())
                        searchQuery = searchField.text
                        busyIndicator.running = true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: palette.base
            radius: 4

            CustomListView {
                id: searchResultsList
                anchors.fill: parent
                model: ListModel {
                    id: searchResultsModel
                }
                onItemClicked: (item) => {
                    if (!databaseBackend.put(item.id, item)) {
                        var _item = item
                        item = databaseBackend.get(item.id)
                        item.episode_list = _item.episode_list
                        item.episode_ids = _item.episode_ids
                    }
                    stackView.push(animeScreen, { anime: item })
                }
                Component.onCompleted: {
                    searchResultsList.addContextMenuItem({
                        title: "Open Details",
                        action: "goto_details",
                        group: "main"
                    })
                }
                onContextMenuAction: function(action, item) {
                    switch(action) {
                        case "goto_details":
                            searchResultsList.onItemClicked(item)
                            break
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledButton {
                text: "Filter"
                onClicked: console.log("Filter clicked")
            }

            StyledButton {
                text: "Sort"
                onClicked: console.log("Sort clicked")
            }

            Item { Layout.fillWidth: true }

            BusyIndicator {
                id: busyIndicator
                running: true
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
            }
        }
    }
}
