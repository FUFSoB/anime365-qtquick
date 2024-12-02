pragma Singleton
import QtCore
import QtQuick 2.15
import QtQuick.Controls 2.15

QtObject {
    // Theme definitions
    readonly property var light: {
        return {
            // Base colors
            background: "#FFFFFF",
            secondaryBackground: "#F5F5F5",
            thirdBackground: "#EEEEEE",
            border: "#E0E0E0",
            accent: "#2196F3",

            // Buttons and other elements
            elementBase: "#E8E8E8",
            elementHover: "#D8D8D8",
            elementPress: "#C8C8C8",

            // Text
            text: "#202020",
            secondaryText: "#505050",
            placeholderText: "#757575",
            link: "#0066CC",

            // Text input
            inputBackground: "#E8E8E8",
            inputFieldBackground: "#F8F8F8",

            // DropDown
            dropdownElementHover: "#E8E8E8",

            // Colorful
            colorfulText: "#FFFFFF",
            fail: "#EF5350",
            cancelBase: "#EF5350",
            cancelHover: "#E57373",
            cancelPress: "#EF9A9A",
            success: "#66BB6A",
            applyBase: "#66BB6A",
            applyHover: "#81C784",
            applyPress: "#A5D6A7",

            // Additional theme-specific properties
            isDark: false
        }
    }

    readonly property var dark: {
        return {
            // Base colors
            background: "#121212",
            secondaryBackground: "#1E1E1E",
            thirdBackground: "#252525",
            border: "#2C2C2C",
            accent: "#64B5F6",

            // Buttons and other elements
            elementBase: "#2C2C2C",
            elementHover: "#353535",
            elementPress: "#3E3E3E",

            // Text
            text: "#FFFFFF",
            secondaryText: "#E0E0E0",
            placeholderText: "#9E9E9E",
            link: "#64B5F6",

            // Text input
            inputBackground: "#2C2C2C",
            inputFieldBackground: "#353535",

            // DropDown
            dropdownElementHover: "#353535",

            // Colorful
            colorfulText: "#FFFFFF",
            fail: "#D32F2F",
            cancelBase: "#D32F2F",
            cancelHover: "#E53935",
            cancelPress: "#F44336",
            success: "#2E7D32",
            applyBase: "#2E7D32",
            applyHover: "#388E3C",
            applyPress: "#43A047",

            isDark: true
        }
    }

    property var currentTheme: {
        var settingsDefined = settingsBackend.get("theme")
        if (settingsDefined && settingsDefined !== "auto") {
            return settingsDefined === "dark" ? dark : light
        }
        return Application.styleHints.colorScheme === Qt.ColorScheme.Dark ? dark : light
    }

    function setLightTheme() {
        currentTheme = light
    }

    function setDarkTheme() {
        currentTheme = dark
    }

    function toggleTheme() {
        currentTheme = (currentTheme.isDark ? light : dark)
    }
}
