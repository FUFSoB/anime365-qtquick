import QtQuick
import QtQuick.Controls
import Themes

Button {
    id: customButton

    property color baseColor: Themes.currentTheme.elementBase
    property color hoverColor: Themes.currentTheme.elementHover
    property color pressColor: Themes.currentTheme.elementPress

    background: Rectangle {
        color: mouseArea.pressed ? pressColor : (mouseArea.containsMouse ? hoverColor : baseColor)
        radius: 4
    }

    contentItem: Text {
        text: parent.text
        color: Themes.currentTheme.text
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
