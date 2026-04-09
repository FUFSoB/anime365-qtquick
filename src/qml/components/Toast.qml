import QtQuick
import QtQuick.Controls

Popup {
    id: toast

    property string toastMessage: ""
    property string toastType: "info"  // "success", "error", "info"

    function show(message, type) {
        toastMessage = message
        toastType = type || "info"
        if (opened) {
            hideTimer.restart()
            return
        }
        open()
        hideTimer.restart()
    }

    x: (parent.width - implicitWidth) / 2
    y: parent.height - implicitHeight - 28

    padding: 0
    modal: false
    focus: false
    closePolicy: Popup.NoAutoClose
    dim: false

    background: Rectangle {
        radius: 8
        color: {
            switch (toast.toastType) {
                case "success": return Qt.rgba(0.18, 0.53, 0.20, 0.94)
                case "error":   return Qt.rgba(0.75, 0.20, 0.20, 0.94)
                default:        return Qt.rgba(0.14, 0.14, 0.14, 0.94)
            }
        }
    }

    contentItem: Label {
        text: toast.toastMessage
        color: "white"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        leftPadding: 18
        rightPadding: 18
        topPadding: 10
        bottomPadding: 10
        wrapMode: Text.WordWrap
        maximumLineCount: 3
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutQuart }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 220 }
    }

    Timer {
        id: hideTimer
        interval: 3500
        repeat: false
        onTriggered: toast.close()
    }
}
