import QtQuick
import QtQuick.Controls.Basic
import Themes

BusyIndicator {
    id: control

    contentItem: Item {
        implicitWidth: 32
        implicitHeight: 32

        Item {
            id: itemContainer
            width: parent.width
            height: parent.height
            anchors.centerIn: parent
            visible: control.running

            RotationAnimation on rotation {
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1200
                running: control.visible && control.running
            }

            Repeater {
                model: 8

                Rectangle {
                    x: itemContainer.width/2 - width/2
                    y: itemContainer.height/2 - height/2
                    width: 3
                    height: itemContainer.height * 0.35
                    radius: width/2
                    color: Themes.currentTheme.accent
                    transform: [
                        Translate {
                            y: -itemContainer.height * 0.25
                        },
                        Rotation {
                            angle: index * 360/8
                            origin.x: width/2
                            origin.y: height/2
                        }
                    ]
                    opacity: 0.1 + (0.9 * (index + 1) / 8)
                }
            }
        }
    }
}
