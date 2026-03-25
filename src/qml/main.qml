import QtQuick
import QtQuick.Controls
import "components"

ApplicationWindow {
    id: mainWindow
    width: 1280
    height: 720
    visible: true
    title: "Anime365"

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: mainScreen
    }

    Component { id: mainScreen; MainScreen {} }
    Component { id: settingsScreen; SettingsScreen {} }
    Component { id: searchScreen; SearchScreen {} }
    Component { id: animeScreen; AnimeScreen {} }
    Component { id: downloadScreen; DownloadScreen {} }

    // Global keyboard shortcuts
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (stackView.depth > 1)
                stackView.pop()
        }
    }
    Shortcut {
        sequence: "Alt+Left"
        onActivated: {
            if (stackView.depth > 1)
                stackView.pop()
        }
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
}
