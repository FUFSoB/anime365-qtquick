import QtQuick
import QtQuick.Controls
import Themes

Button {
    id: customButton

    property color textColor: Themes.currentTheme.text
    property color baseColor: Themes.currentTheme.elementBase
    property color hoverColor: Themes.currentTheme.elementHover
    property color pressColor: Themes.currentTheme.elementPress

    opacity: enabled ? 1.0 : 0.5

    background: Rectangle {
        color: mouseArea.pressed ? pressColor : (mouseArea.containsMouse ? hoverColor : baseColor)
        radius: 4
    }

    contentItem: Text {
        text: parent.text
        color: textColor
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
