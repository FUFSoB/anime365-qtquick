import QtQuick
import QtQuick.Controls
import Themes

SpinBox {
    id: control
    editable: true

    background: Rectangle {
        color: Themes.currentTheme.inputBackground
        radius: 4
    }

    contentItem: TextInput {
        z: 2
        text: control.textFromValue(control.value, control.locale)
        font: control.font
        color: Themes.currentTheme.text
        selectionColor: Themes.currentTheme.accent
        selectedTextColor: Themes.currentTheme.text
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter

        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly

        onFocusChanged: {
            if (focus) {
                selectAll()
            }
        }
    }

    up.indicator: Rectangle {
        x: parent.width - width
        height: parent.height/2
        width: height
        color: up.pressed ? Themes.currentTheme.accent : (up.hovered ? Themes.currentTheme.secondaryBackground : Themes.currentTheme.thirdBackground)
        opacity: control.value < control.to ? 1 : 0.5
        radius: 4

        Text {
            text: "+"
            color: Themes.currentTheme.text
            anchors.centerIn: parent
            font.pixelSize: control.font.pixelSize
        }
    }

    down.indicator: Rectangle {
        x: parent.width - width
        y: parent.height - height
        height: parent.height/2
        width: height
        color: down.pressed ? Themes.currentTheme.accent : (down.hovered ? Themes.currentTheme.secondaryBackground : Themes.currentTheme.thirdBackground)
        opacity: control.value > control.from ? 1 : 0.5
        radius: 4

        Text {
            text: "-"
            color: Themes.currentTheme.text
            anchors.centerIn: parent
            font.pixelSize: control.font.pixelSize
        }
    }

    MouseArea {
        anchors.fill: parent
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                if (control.value < control.to) {
                    control.increase()
                }
            } else {
                if (control.value > control.from) {
                    control.decrease()
                }
            }
        }
        propagateComposedEvents: true
        onPressed: (mouse) => mouse.accepted = false
        onReleased: (mouse) => mouse.accepted = false
        onClicked: (mouse) => mouse.accepted = false
    }

    validator: IntValidator {
        bottom: control.from
        top: control.to
    }

    onValueModified: {
        if (value > to) value = to
        if (value < from) value = from
    }
}
