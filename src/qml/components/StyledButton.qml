import QtQuick
import QtQuick.Controls

Button {
    id: btn
    implicitHeight: 36
    implicitWidth: Math.max(100, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: 16
    rightPadding: 16
    font.pixelSize: 14
    opacity: !enabled ? 0.4
           : Qt.application.state !== Qt.ApplicationActive ? 0.6
           : 1.0

    background: Rectangle {
        radius: 6
        color: btn.pressed ? Qt.darker(palette.button, 1.08)
             : btn.hovered ? Qt.lighter(palette.button, 1.06)
             : palette.button
        border.color: btn.pressed ? palette.shadow
                    : btn.hovered ? palette.highlight
                    : palette.mid
        border.width: 1

        Behavior on color        { ColorAnimation { duration: 80 } }
        Behavior on border.color { ColorAnimation { duration: 80 } }
    }
}
