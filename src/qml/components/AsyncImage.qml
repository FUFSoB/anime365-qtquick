import QtQuick
import QtQuick.Controls

// Reusable image component with loading placeholder, error fallback, and retry
Item {
    id: root

    property string source: ""
    property int radius: 0
    property int fillMode: Image.PreserveAspectCrop
    property bool showBusyIndicator: true

    // Internal state
    property bool _isDestroyed: false
    property bool _hasError: false

    Component.onDestruction: _isDestroyed = true

    // Container with clipping for radius
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        clip: radius > 0
        color: "transparent"

        // Gradient placeholder (visible while loading or on error)
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0.5, 0.5, 0.5, 0.08) }
                GradientStop { position: 1.0; color: Qt.rgba(0.5, 0.5, 0.5, 0.18) }
            }
            visible: img.status !== Image.Ready
        }

        // Error state overlay
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: Qt.rgba(0.5, 0.5, 0.5, 0.05)
            visible: root._hasError

            Label {
                anchors.centerIn: parent
                text: "\u26A0"
                font.pixelSize: Math.min(parent.width, parent.height) * 0.3
                opacity: 0.25
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root._hasError = false
                    img.source = ""
                    img.source = root.source ? imageCacheBackend.cache_image(root.source) : ""
                }
                ToolTip.text: "Click to retry"
                ToolTip.visible: containsMouse
                ToolTip.delay: 600
                hoverEnabled: true
            }
        }

        Image {
            id: img
            anchors.fill: parent
            source: root.source ? imageCacheBackend.cache_image(root.source) : ""
            fillMode: root.fillMode
            cache: true
            asynchronous: true

            onStatusChanged: {
                if (status === Image.Error && root.source) {
                    root._hasError = true
                }
            }

            Connections {
                target: imageCacheBackend
                enabled: !root._isDestroyed
                function onImage_downloaded(origUrl, localUrl) {
                    if (!root._isDestroyed && root.source && origUrl === root.source) {
                        root._hasError = false
                        img.source = localUrl
                    }
                }
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: root.showBusyIndicator && img.status === Image.Loading
            visible: running
            width: Math.min(24, parent.width * 0.4)
            height: width
            padding: 0
        }
    }
}
