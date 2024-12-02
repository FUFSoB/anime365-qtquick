import QtQuick
import QtQuick.Controls
import QtCore
import Themes

Rectangle {
    property string searchQuery: ""
    color: Themes.currentTheme.background

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

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        Column {
            anchors.fill: parent
            spacing: 12

            Rectangle {
                width: parent.width
                height: 36
                color: "transparent"

                Row {
                    width: parent.width
                    spacing: 12

                    CustomButton {
                        id: backButton
                        width: 100
                        height: 36
                        text: "← Back"
                        onClicked: stackView.pop()
                    }

                    TextField {
                        id: searchField
                        width: parent.width - backButton.width - searchButton.width - parent.spacing * 2
                        height: parent.height
                        text: searchQuery
                        placeholderText: "Search anime"
                        background: Rectangle {
                            color: Themes.currentTheme.inputBackground
                            radius: 4
                        }
                        color: Themes.currentTheme.text
                        placeholderTextColor: Themes.currentTheme.placeholderText
                        font.pixelSize: 14
                        onAccepted: {
                            if (text.trim() !== "") {
                                searchBackend.perform_search(searchField.text.trim())
                                searchQuery = text
                                busyIndicator.running = true
                            }
                        }
                    }

                    CustomButton {
                        id: searchButton
                        width: 100
                        height: parent.height
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
            }

            Row {
                width: parent.width
                height: parent.height - 96
                spacing: 12

                Rectangle {
                    width: parent.width
                    height: parent.height
                    color: Themes.currentTheme.secondaryBackground
                    radius: 4

                    CustomListView {
                        id: searchResultsList
                        width: parent.width
                        height: parent.height
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
            }

            Rectangle {
                width: parent.width
                height: 36
                color: "transparent"

                Row {
                    anchors.left: parent.left
                    height: parent.height
                    spacing: 12

                    CustomButton {
                        width: 100
                        height: parent.height
                        text: "Filter"
                        onClicked: console.log("Filter clicked")
                    }

                    CustomButton {
                        width: 100
                        height: parent.height
                        text: "Sort"
                        onClicked: console.log("Sort clicked")
                    }
                }

                CustomBusyIndicator {
                    id: busyIndicator
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    running: true
                }
            }
        }
    }
}
