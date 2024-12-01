import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Themes

Rectangle {
    color: Themes.currentTheme.background

    function updateHistory() {
        var history = databaseBackend.get_list()
        historyModel.clear()
        for (var i = 0; i < history.length; i++) {
            historyModel.append(history[i])
        }
    }

    Component.onCompleted: {
        historyList.addContextMenuItem({
            title: "Remove Item",
            action: "delete",
            group: "dangerous",
            color: Themes.currentTheme.cancelBase
        })

        updateHistory()
    }

    Connections {
        target: databaseBackend

        function onList_updated() {
            updateHistory()
        }
    }

    Rectangle {
        id: mainContent
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        Column {
            id: topControls
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 12

            Row {
                width: parent.width
                height: 36
                spacing: 12

                TextField {
                    id: searchField
                    width: parent.width - searchButton.width - parent.spacing
                    height: parent.height
                    placeholderText: "Search anime"
                    background: Rectangle {
                        color: Themes.currentTheme.inputBackground
                        radius: 4
                    }
                    placeholderTextColor: Themes.currentTheme.placeholderText
                    color: Themes.currentTheme.text
                    font.pixelSize: 14
                    onAccepted: {
                        if (text.trim() !== "") {
                            searchBackend.perform_search(searchField.text.trim())
                            stackView.push(searchScreen, { searchQuery: text })
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
                            stackView.push(searchScreen, { searchQuery: searchField.text })
                        }
                    }
                }
            }

            CustomButton {
                width: parent.width
                height: 36
                text: "Tracker List"
                onClicked: console.log("Tracker List clicked")
            }

            Row {
                width: parent.width
                height: 36
                spacing: 12

                CustomButton {
                    width: (parent.width - parent.spacing) / 2
                    height: 36
                    text: "Open UGet"
                    onClicked: backend.open_uget()
                }

                CustomButton {
                    width: (parent.width - parent.spacing) / 2
                    height: 36
                    text: "Settings"
                    onClicked: stackView.push(settingsScreen)
                }
            }
        }

        Rectangle {
            anchors.top: topControls.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 12
            color: Themes.currentTheme.secondaryBackground
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
                onContextMenuAction: function(action, item) {
                    switch(action) {
                        case "goto_details":
                            searchResultsList.onItemClicked(item)
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
