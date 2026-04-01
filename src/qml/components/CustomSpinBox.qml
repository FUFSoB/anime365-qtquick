import QtQuick
import QtQuick.Controls

SpinBox {
    id: control
    editable: true

    MouseArea {
        anchors.fill: parent
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                if (control.value < control.to)
                    control.value += control.stepSize
            } else {
                if (control.value > control.from)
                    control.value -= control.stepSize
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
