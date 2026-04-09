import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

ApplicationWindow {
    id: mainWindow
    minimumWidth: 800
    minimumHeight: 500
    width: Math.min(Screen.width * 0.8, 1440)
    height: Math.min(Screen.height * 0.8, 900)
    visible: true
    title: "Anime365"

    function showToast(message, type) { toast.show(message, type) }

    function handleBackForCurrentScreen() {
        var current = stackView.currentItem
        if (current && typeof current.handleBack === "function") {
            current.handleBack()
        } else if (stackView.depth > 1) {
            stackView.pop()
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: handleBackForCurrentScreen()
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 0

            ToolButton {
                id: backButton
                opacity: stackView.depth > 1 ? 1.0 : 0.0
                enabled: stackView.depth > 1
                text: "\u2190"
                font.pixelSize: 18
                implicitWidth: 40
                onClicked: mainWindow.handleBackForCurrentScreen()
                ToolTip.text: "Back (Esc)"
                ToolTip.visible: hovered
                ToolTip.delay: 600
            }

            Image {
                source: appIconPath
                sourceSize: Qt.size(22, 22)
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: appIconPath !== ""
                Layout.rightMargin: 4
            }

            Label {
                text: "Anime365"
                font.pixelSize: 15
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            BusyIndicator {
                id: headerBusyIndicator
                running: stackView && stackView.currentItem ? (stackView.currentItem.isBusy === true) : false
                visible: running
                implicitWidth: 24
                implicitHeight: 24
                Layout.rightMargin: 4
            }

            ToolButton {
                text: "\u2302"
                font.pixelSize: 16
                implicitWidth: 40
                visible: stackView.depth > 1
                onClicked: stackView.pop(null)
                ToolTip.text: "Home (Ctrl+H)"
                ToolTip.visible: hovered
                ToolTip.delay: 600
            }

            ToolButton {
                text: "\u2193"
                font.pixelSize: 14
                implicitWidth: 40
                opacity: stackView.currentItem && stackView.currentItem.objectName === "downloadScreen" ? 0.4 : 1.0
                onClicked: {
                    if (stackView.currentItem.objectName !== "downloadScreen")
                        stackView.push(downloadScreen)
                }
                ToolTip.text: "Downloads (Ctrl+D)"
                ToolTip.visible: hovered
                ToolTip.delay: 600
            }

            ToolButton {
                text: "\u2699"
                font.pixelSize: 16
                implicitWidth: 40
                opacity: stackView.currentItem && stackView.currentItem.objectName === "settingsScreen" ? 0.4 : 1.0
                onClicked: {
                    if (stackView.currentItem.objectName !== "settingsScreen")
                        stackView.push(settingsScreen)
                }
                ToolTip.text: "Settings (Ctrl+,)"
                ToolTip.visible: hovered
                ToolTip.delay: 600
            }
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: mainScreen

        pushEnter: Transition {
            PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutQuart }
        }
        pushExit: Transition {
            PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
        }
        popEnter: Transition {
            PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutQuart }
        }
        popExit: Transition {
            PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
        }
    }

    Component { id: mainScreen;     MainScreen {} }
    Component { id: settingsScreen; SettingsScreen {} }
    Component { id: searchScreen;   SearchScreen {} }
    Component { id: animeScreen;    AnimeScreen {} }
    Component { id: downloadScreen; DownloadScreen {} }

    Toast { id: toast }

    Popup {
        id: shortcutHelp
        anchors.centerIn: Overlay.overlay
        modal: true
        padding: 24

        background: Rectangle {
            color: palette.window
            radius: 10
            border.color: palette.mid
            border.width: 1
        }

        contentItem: Column {
            spacing: 0

            Label {
                text: "Keyboard Shortcuts"
                font.pixelSize: 15
                font.bold: true
                bottomPadding: 14
            }

            component ShortcutRow: Row {
                property string keys: ""
                property string action: ""
                spacing: 0
                width: 340

                Label {
                    width: 160
                    text: parent.keys
                    font.pixelSize: 12
                    font.family: "monospace"
                    color: palette.highlight
                }
                Label {
                    width: 180
                    text: parent.action
                    font.pixelSize: 12
                    opacity: 0.75
                }
            }

            component ShortcutGroup: Label {
                property string heading: ""
                text: heading
                font.pixelSize: 10
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8
                font.bold: true
                opacity: 0.40
                topPadding: 12
                bottomPadding: 6
            }

            ShortcutGroup { heading: "Navigation" }
            ShortcutRow { keys: "Esc  /  Alt+Left"; action: "Go back" }
            ShortcutRow { keys: "Ctrl+H";           action: "Go to home" }
            ShortcutRow { keys: "Ctrl+D";           action: "Downloads" }
            ShortcutRow { keys: "Ctrl+,";           action: "Settings" }
            ShortcutRow { keys: "Ctrl+F  /  /";     action: "Focus search" }

            ShortcutGroup { heading: "Anime Screen" }
            ShortcutRow { keys: "N";                action: "Next episode" }
            ShortcutRow { keys: "P";                action: "Previous episode" }
            ShortcutRow { keys: "Space  /  Enter";  action: "Play in default player" }

            ShortcutGroup { heading: "General" }
            ShortcutRow { keys: "?";                action: "Show this help" }
        }
    }

    Shortcut {
        sequence: "Alt+Left"
        onActivated: mainWindow.handleBackForCurrentScreen()
    }
    Shortcut {
        sequence: "Ctrl+,"
        onActivated: {
            if (stackView.currentItem.objectName !== "settingsScreen")
                stackView.push(settingsScreen)
        }
    }
    Shortcut {
        sequence: "Ctrl+D"
        onActivated: {
            if (stackView.currentItem.objectName !== "downloadScreen")
                stackView.push(downloadScreen)
        }
    }
    Shortcut {
        sequence: "Ctrl+H"
        onActivated: {
            if (stackView.depth > 1)
                stackView.pop(null)
        }
    }
    Shortcut {
        sequence: "Ctrl+F"
        onActivated: {
            var current = stackView.currentItem
            if (current && current.focusSearch)
                current.focusSearch()
        }
    }
    Shortcut {
        sequence: "/"
        onActivated: {
            var current = stackView.currentItem
            if (current && current.focusSearch)
                current.focusSearch()
        }
    }
    Shortcut {
        sequence: "?"
        onActivated: shortcutHelp.open()
    }
}
