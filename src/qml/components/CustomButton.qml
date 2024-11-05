import QtQuick
import QtQuick.Controls

Button {
    id: customButton

    property color baseColor: "#333333"
    property color hoverColor: "#383838"
    property color pressColor: "#404040"

    background: Rectangle {
        color: mouseArea.pressed ? pressColor : (mouseArea.containsMouse ? hoverColor : baseColor)
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
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: parent.clicked()
    }
}
