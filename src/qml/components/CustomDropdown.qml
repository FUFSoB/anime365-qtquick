import QtQuick
import QtQuick.Controls

Item {
    id: dropdown
    height: 36

    property var model: []
    property string selectedValue: ""
    property string placeholder: "Select option"
    property bool isOpen: false
    property int selectedIndex: -1
    property string searchText: ""

    signal selectionChanged(string value)
    signal selectionChangedIndex(int value)

    // Filtered model for search
    property var filteredModel: {
        if (searchText === "") return model;
        return model.filter(item =>
            item.toLowerCase().includes(searchText.toLowerCase())
        );
    }

    // Main button
    Rectangle {
        id: header
        width: parent.width
        height: parent.height
        color: "#333333"
        radius: 4

        Row {
            anchors.fill: parent
            anchors.margins: 8
            anchors.rightMargin: 12
            spacing: 8

            Text {
                width: parent.width - arrow.width - parent.spacing
                height: parent.height
                text: selectedValue || placeholder
                color: "white"
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Text {
                id: arrow
                width: 12
                height: parent.height
                text: dropdown.isOpen ? "▲" : "▼"
                color: "white"
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                searchText = ""
                dropdownPopup.open()
                if (selectedIndex >= 0) {
                    listView.positionViewAtIndex(selectedIndex, ListView.Center)
                }
            }
        }
    }

    // Popup for dropdown items
    Popup {
        id: dropdownPopup
        width: parent.width
        height: Math.min(searchRow.height + listView.contentHeight, 300)
        y: header.height + 4
        padding: 0
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        background: Rectangle {
            color: "#2A2A2A"
            radius: 4
        }

        onOpened: {
            dropdown.isOpen = true
            searchInput.forceActiveFocus()
        }

        onClosed: {
            dropdown.isOpen = false
            searchInput.text = ""
            searchText = ""
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // Search input
            Rectangle {
                id: searchRow
                width: parent.width
                height: 36
                color: "#333333"

                TextField {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 4
                    color: "white"
                    placeholderText: "Search..."
                    placeholderTextColor: "#888"
                    font.pixelSize: 14
                    background: Rectangle {
                        color: "#404040"
                        radius: 2
                    }
                    onTextChanged: {
                        searchText = text
                    }

                    // Handle Enter key
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (filteredModel.length > 0) {
                                // Select first matching item
                                const matchedItem = filteredModel[0]
                                dropdown.selectedValue = matchedItem
                                dropdown.selectedIndex = dropdown.model.indexOf(matchedItem)
                                dropdown.selectionChanged(matchedItem)
                                dropdown.selectionChangedIndex(dropdown.selectedIndex)
                                dropdownPopup.close()
                            }
                            event.accepted = true
                        }
                    }
                }

            }

            // Scrollable dropdown list
            ListView {
                id: listView
                width: parent.width
                height: parent.height - searchRow.height
                clip: true
                model: filteredModel
                delegate: Rectangle {
                    width: dropdown.width
                    height: 36
                    color: mouseArea.containsMouse ? "#383838" :
                           (modelData === dropdown.selectedValue ? "#404040" : "transparent")

                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
                        text: modelData
                        color: "white"
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            dropdown.selectedValue = modelData
                            dropdown.selectedIndex = dropdown.model.indexOf(modelData)
                            dropdown.selectionChanged(modelData)
                            dropdown.selectionChangedIndex(dropdown.selectedIndex)
                            dropdownPopup.close()
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {}
            }
        }
    }

    // Handle wheel events for changing selection
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: function(event) {
            if (!dropdown.isOpen && dropdown.model.length > 0) {
                if (event.angleDelta.y > 0) {
                    // Scroll up
                    if (selectedIndex > 0) {
                        selectedIndex--
                        selectedValue = dropdown.model[selectedIndex]
                        selectionChanged(selectedValue)
                        selectionChangedIndex(selectedIndex)
                    }
                } else {
                    // Scroll down
                    if (selectedIndex < dropdown.model.length - 1) {
                        selectedIndex++
                        selectedValue = dropdown.model[selectedIndex]
                        selectionChanged(selectedValue)
                        selectionChangedIndex(selectedIndex)
                    }
                }
            }
        }
    }

    // Update when model changes
    onModelChanged: {
    }
}
