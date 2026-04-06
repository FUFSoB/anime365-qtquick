import QtQuick
import QtQuick.Controls

Item {
    id: dropdown
    height: 36

    SystemPalette {
        id: pal
        colorGroup: Qt.application.state === Qt.ApplicationActive
            ? SystemPalette.Active : SystemPalette.Inactive
    }

    property var model: []
    property string selectedValue: ""
    property string placeholder: "Select option"
    property bool isOpen: false
    property int selectedIndex: -1

    signal selectionChanged(string value)
    signal selectionChangedIndex(int value)

    function fuzzyMatch(search, target) {
        if (search === "") return true;

        search = search.toLowerCase();
        target = target.toLowerCase();

        let searchIndex = 0;
        let targetIndex = 0;

        while (searchIndex < search.length && targetIndex < target.length) {
            if (search[searchIndex] === target[targetIndex]) {
                searchIndex++;
            }
            targetIndex++;
        }

        return searchIndex === search.length;
    }

    property var filteredModel: {
        if (searchInput.text === "") return model;
        return model.filter(item => fuzzyMatch(searchInput.text, item));
    }

    Rectangle {
        id: header
        width: parent.width
        height: parent.height
        color: headerMouse.containsMouse ? Qt.lighter(pal.button, 1.06) : pal.button
        radius: 6
        border.width: 1
        border.color: dropdown.isOpen ? pal.highlight
                    : headerMouse.containsMouse ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.5)
                    : pal.mid

        Behavior on color        { ColorAnimation { duration: 80 } }
        Behavior on border.color { ColorAnimation { duration: 80 } }

        Row {
            anchors.fill: parent
            anchors.margins: 8
            anchors.rightMargin: 12
            spacing: 8

            Text {
                width: parent.width - arrow.width - parent.spacing
                height: parent.height
                text: selectedValue || placeholder
                color: selectedValue ? pal.buttonText : Qt.rgba(pal.buttonText.r, pal.buttonText.g, pal.buttonText.b, 0.5)
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Text {
                id: arrow
                width: 12
                height: parent.height
                text: dropdown.isOpen ? "\u25B2" : "\u25BC"
                color: pal.mid
                font.pixelSize: 10
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property bool wasOpenOnPress: false
            onPressed: { wasOpenOnPress = dropdownPopup.visible }
            onClicked: {
                if (wasOpenOnPress) return
                dropdownPopup.open()
                if (selectedIndex >= 0)
                    listView.positionViewAtIndex(selectedIndex, ListView.Center)
            }
        }
    }

    Popup {
        id: dropdownPopup
        width: parent.width
        height: Math.min(searchRow.height + listView.contentHeight, 300)
        y: header.height + 4
        padding: 0
        closePolicy: Popup.CloseOnReleaseOutside | Popup.CloseOnEscape
        background: Rectangle {
            color: pal.base
            radius: 4
            border.color: pal.mid
            border.width: 1
        }

        onOpened: {
            dropdown.isOpen = true
            searchInput.forceActiveFocus()
        }

        onClosed: {
            dropdown.isOpen = false
            searchInput.text = ""
        }

        Column {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: searchRow
                width: parent.width
                height: 36
                color: pal.base

                StyledTextField {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 4
                    placeholderText: "Search..."
                    font.pixelSize: 14

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (filteredModel.length > 0 && searchInput.text !== "") {
                                const matchedItem = filteredModel[0]
                                dropdown.selectedValue = matchedItem
                                dropdown.selectedIndex = dropdown.model.indexOf(matchedItem)
                                dropdown.selectionChanged(matchedItem)
                                dropdown.selectionChangedIndex(dropdown.selectedIndex)
                            }
                            dropdownPopup.close()
                            event.accepted = true
                        }
                    }
                }

            }

            ListView {
                id: listView
                width: parent.width
                height: parent.height - searchRow.height
                clip: true
                model: filteredModel
                delegate: Rectangle {
                    width: dropdown.width
                    height: 36
                    color: mouseArea.containsMouse
                         ? pal.highlight
                         : modelData === dropdown.selectedValue
                           ? Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.15)
                           : "transparent"

                    // Selected indicator bar
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: pal.highlight
                        visible: modelData === dropdown.selectedValue && !mouseArea.containsMouse
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: modelData === dropdown.selectedValue ? 10 : 8
                        anchors.rightMargin: 8
                        text: modelData
                        color: mouseArea.containsMouse ? pal.highlightedText
                             : modelData === dropdown.selectedValue ? pal.highlight
                             : pal.text
                        font.pixelSize: 14
                        font.bold: modelData === dropdown.selectedValue
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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: function(event) {
            if (!dropdown.isOpen && dropdown.model.length > 0) {
                if (event.angleDelta.y > 0) {
                    if (selectedIndex > 0) {
                        selectedIndex--
                        changeSelection(selectedIndex)
                    }
                } else {
                    if (selectedIndex < dropdown.model.length - 1) {
                        selectedIndex++
                        changeSelection(selectedIndex)
                    }
                }
            }
        }
    }

    function changeSelection(index) {
        if (index >= 0 && index < dropdown.model.length) {
            selectedIndex = index
            selectedValue = dropdown.model[index]
            selectionChanged(selectedValue)
            selectionChangedIndex(selectedIndex)
        }
    }

    onModelChanged: {
        selectedValue = ""
        selectedIndex = -1
    }
}
