import QtQuick
import QtQuick.Controls

Button {
    implicitHeight: 36
    implicitWidth: Math.max(100, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: 16
    rightPadding: 16
    font.pixelSize: 14
    opacity: !enabled ? 0.4
           : Qt.application.state !== Qt.ApplicationActive ? 0.6
           : 1.0
}
