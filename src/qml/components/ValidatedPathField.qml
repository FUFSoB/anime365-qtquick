import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Binary path input that validates with settingsBackend.is_valid_binary() after
// a short debounce.  Usage:
//
//   ValidatedPathField {
//       id: mpvPathField
//       placeholderText: defaults.mpv_path || "Path to binary"
//   }
//
// Read the entered path via `mpvPathField.text`.
// isValidPath is true when the field is empty (inherits default) or when the
// binary was found; false while the user is typing or the path is invalid.

ColumnLayout {
    id: root

    property alias text: pathInput.text
    property alias placeholderText: pathInput.placeholderText
    property bool isValidPath: true

    spacing: 0

    Globals { id: globals }

    StyledTextField {
        id: pathInput
        Layout.fillWidth: true

        onTextChanged: {
            if (text) {
                isValidPath = false
                validateTimer.restart()
            } else {
                isValidPath = true
            }
        }

        background: Rectangle {
            color: palette.base
            border.color: root.isValidPath
                ? globals.colorSuccess
                : (pathInput.text ? globals.colorError : palette.mid)
            border.width: (root.isValidPath || pathInput.text) ? 2 : 1
            radius: 4
        }
    }

    Timer {
        id: validateTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (pathInput.text)
                root.isValidPath = settingsBackend.is_valid_binary(pathInput.text)
        }
    }
}
