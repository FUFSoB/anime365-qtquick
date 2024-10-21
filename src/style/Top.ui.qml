

/*
This is a UI file (.ui.qml) that is intended to be edited in Qt Design Studio only.
It is supposed to be strictly declarative and only uses a subset of QML. If you edit
this file manually, you might introduce QML code that is not supported by Qt Design Studio.
Check out https://doc.qt.io/qtcreator/creator-quick-ui-forms.html for details on .ui.qml files.
*/
import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 1280
    height: 720

    Button {
        id: removeButton
        x: 21
        y: 662
        width: 158
        height: 34
        text: qsTr("Remove from history")
    }

    Button {
        id: selectButton
        x: 1079
        y: 662
        width: 158
        height: 34
        text: qsTr("Select anime")
    }

    TextField {
        id: searchField
        x: 21
        y: 117
        width: 500
        height: 32
        placeholderText: qsTr("Text Field")
    }

    Button {
        id: searchButton
        objectName: "searchButton"
        x: 527
        y: 116
        text: qsTr("Search")
    }

    ComboBox {
        id: sortBy
        x: 753
        y: 117
        width: 107
        height: 32
        editable: false
        flat: false
    }

    Button {
        id: openFilters
        x: 663
        y: 116
        text: qsTr("Filters")
    }

    ComboBox {
        id: selectList
        x: 663
        y: 663
        width: 197
        height: 32
    }

    GridView {
        id: animeList
        x: 21
        y: 163
        width: 839
        height: 480
        model: ListModel {
            ListElement {
                name: "Grey"
                colorCode: "grey"
            }

            ListElement {
                name: "Red"
                colorCode: "red"
            }

            ListElement {
                name: "Blue"
                colorCode: "blue"
            }

            ListElement {
                name: "Green"
                colorCode: "green"
            }
        }
        delegate: Item {
            x: 5
            height: 50
            Column {
                spacing: 5
                Rectangle {
                    width: 40
                    height: 40
                    color: colorCode
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    x: 5
                    text: name
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
        cellWidth: 70
        cellHeight: 70
    }

    Image {
        id: coverPreview
        x: 899
        y: 163
        width: 338
        height: 480
        source: "file:///home/fufsob/vuz/git/anime365-qtquick/src/style/anime_image_placeholder.png"
        fillMode: Image.PreserveAspectFit
    }
}
