import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: mainWindow
    width: 1280
    height: 720
    visible: true
    color: "#1E1E1E"
    title: "Anime365"

    // Stack view to handle multiple screens
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: mainScreen
    }

    // Main screen component
    Component {
        id: mainScreen

        Rectangle {
            color: "#1E1E1E"

            Rectangle {
                id: mainContent
                anchors.fill: parent
                anchors.margins: 12
                color: "transparent"

                // Top controls column
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
                                color: "#333333"
                                radius: 4
                            }
                            color: "white"
                            font.pixelSize: 14
                            onAccepted: {
                                if (text.trim() !== "") {
                                    stackView.push(searchScreen, { searchQuery: text })
                                }
                            }
                        }

                        Button {
                            id: searchButton
                            width: 100
                            height: parent.height
                            text: "Search"
                            background: Rectangle {
                                color: searchMouseArea.pressed ? "#404040" : (searchMouseArea.containsMouse ? "#383838" : "#333333")
                                radius: 4
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                            }
                            MouseArea {
                                id: searchMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (searchField.text.trim() !== "") {
                                        stackView.push(searchScreen, { searchQuery: searchField.text })
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        width: parent.width
                        height: 36
                        text: "Shikimori list"
                        background: Rectangle {
                            color: mouseArea1.pressed ? "#404040" : (mouseArea1.containsMouse ? "#383838" : "#333333")
                            radius: 4
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: mouseArea1
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: console.log("Shikimori list clicked")
                        }
                    }

                    Row {
                        width: parent.width
                        height: 36
                        spacing: 12

                        Button {
                            width: (parent.width - parent.spacing) / 2
                            height: parent.height
                            text: "Open UGet"
                            background: Rectangle {
                                color: mouseArea2.pressed ? "#404040" : (mouseArea2.containsMouse ? "#383838" : "#333333")
                                radius: 4
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                            }
                            MouseArea {
                                id: mouseArea2
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: console.log("UGet clicked")
                            }
                        }

                        Button {
                            width: (parent.width - parent.spacing) / 2
                            height: parent.height
                            text: "Settings"
                            background: Rectangle {
                                color: mouseArea3.pressed ? "#404040" : (mouseArea3.containsMouse ? "#383838" : "#333333")
                                radius: 4
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                            }
                            MouseArea {
                                id: mouseArea3
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: stackView.push(settingsScreen)
                            }
                        }
                    }
                }

                Row {
                    anchors.top: topControls.bottom
                    anchors.bottom: bottomControls.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    spacing: 12

                    Rectangle {
                        width: parent.width * 0.6
                        height: parent.height
                        color: "#2A2A2A"
                        radius: 4

                        ListView {
                            id: animeList
                            anchors.fill: parent
                            anchors.margins: 4
                            clip: true
                            model: ListModel {
                                ListElement { title: "History entry 1" }
                                ListElement { title: "History entry 2" }
                                ListElement { title: "History entry 3" }
                                ListElement { title: "History entry 4" }
                                ListElement { title: "History entry 5" }
                            }
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 36
                                color: mouseArea.containsMouse ? "#383838" : (index % 2 == 0 ? "#2A2A2A" : "#333333")

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    text: title
                                    color: "white"
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: console.log("Selected anime:", title)
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width * 0.4
                        height: parent.height
                        color: "#2A2A2A"
                        radius: 4

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: "placeholder.png"
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                }

                Rectangle {
                    id: bottomControls
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 36
                    color: "transparent"

                    Row {
                        anchors.fill: parent
                        spacing: 12

                        Text {
                            id: episodeText
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: "Viewed 1 / 24 episodes — [en, sub, bd, 1080p] Doki"
                            color: "white"
                            font.pixelSize: 14
                        }

                        Item {
                            width: parent.width - episodeText.width - buttonRow.width - parent.spacing * 2
                            height: parent.height
                        }

                        Row {
                            id: buttonRow
                            height: parent.height
                            spacing: 12

                            Button {
                                width: 100
                                height: parent.height
                                text: "Remove"
                                background: Rectangle {
                                    color: removeMouseArea.pressed ? "#404040" : (removeMouseArea.containsMouse ? "#383838" : "#333333")
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: removeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: console.log("Remove clicked")
                                }
                            }

                            Button {
                                width: 100
                                height: parent.height
                                text: "Select"
                                background: Rectangle {
                                    color: selectMouseArea.pressed ? "#404040" : (selectMouseArea.containsMouse ? "#383838" : "#333333")
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: selectMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: console.log("Select clicked")
                                }
                            }

                            Button {
                                width: 120
                                height: parent.height
                                text: "Next Episode"
                                background: Rectangle {
                                    color: nextEpisodeMouseArea.pressed ? "#404040" : (nextEpisodeMouseArea.containsMouse ? "#383838" : "#333333")
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: nextEpisodeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: console.log("Next Episode clicked")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Settings screen component
    Component {
        id: settingsScreen

        Rectangle {
            color: "#1E1E1E"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 12
                color: "transparent"

                Column {
                    anchors.fill: parent
                    spacing: 12

                    // Header with back button
                    Rectangle {
                        width: parent.width
                        height: 36
                        color: "transparent"

                        Row {
                            spacing: 12

                            Button {
                                width: 100
                                height: 36
                                text: "← Back"
                                background: Rectangle {
                                    color: backMouseArea.pressed ? "#404040" : (backMouseArea.containsMouse ? "#383838" : "#333333")
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: backMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: stackView.pop()
                                }
                            }

                            Text {
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: "Settings"
                                color: "white"
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }
                    }

                    // MPV path setting
                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Path to MPV binary"
                            color: "white"
                            font.pixelSize: 14
                        }

                        Row {
                            width: parent.width
                            spacing: 12
                            height: 36

                            TextField {
                                id: mpvPathField
                                width: parent.width - parent.spacing
                                height: parent.height
                                text: "/usr/bin/mpv"
                                background: Rectangle {
                                    color: "#333333"
                                    radius: 4
                                }
                                color: "white"
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: searchScreen

        Rectangle {
            property string searchQuery: ""
            color: "#1E1E1E"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 12
                color: "transparent"

                Column {
                    anchors.fill: parent
                    spacing: 12

                    // Header with back button and search query
                    Rectangle {
                        width: parent.width
                        height: 36
                        color: "transparent"

                        Row {
                            spacing: 12

                            Button {
                                width: 100
                                height: 36
                                text: "← Back"
                                background: Rectangle {
                                    color: searchBackMouseArea.pressed ? "#404040" : (searchBackMouseArea.containsMouse ? "#383838" : "#333333")
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: searchBackMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: stackView.pop()
                                }
                            }

                            Text {
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: "Search Results: " + searchQuery
                                color: "white"
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }
                    }

                    // Search results list
                    Rectangle {
                        width: parent.width
                        height: parent.height - 96  // Account for header and bottom controls
                        color: "#2A2A2A"
                        radius: 4

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 4
                            clip: true
                            model: ListModel {
                                // Example results - in real app, this would be populated based on search
                                ListElement { title: "Search Result 1" }
                                ListElement { title: "Search Result 2" }
                                ListElement { title: "Search Result 3" }
                            }
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 36
                                color: searchResultMouseArea.containsMouse ? "#383838" : (index % 2 == 0 ? "#2A2A2A" : "#333333")

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    text: title
                                    color: "white"
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: searchResultMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: console.log("Selected search result:", title)
                                }
                            }
                        }
                    }

                    // Bottom controls
                    Rectangle {
                        width: parent.width
                        height: 36
                        color: "transparent"

                        Row {
                            anchors.right: parent.right
                            height: parent.height
                            spacing: 12

                            Button {
                                width: 100
                                height: parent.height
                                text: "Filter"
                                background: Rectangle {
                                    color: filterMouseArea.pressed ? "#404040" : (filterMouseArea.containsMouse ? "#383838" : "#333333")
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: filterMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: console.log("Filter clicked")
                                }
                            }

                            Button {
                                width: 100
                                height: parent.height
                                text: "Sort"
                                background: Rectangle {
                                    color: sortMouseArea.pressed ? "#404040" : (sortMouseArea.containsMouse ? "#383838" : "#333333")
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: sortMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: console.log("Sort clicked")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
