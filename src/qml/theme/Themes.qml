pragma Singleton
import QtQuick 2.15

QtObject {
    // Theme definitions
    readonly property var light: {
        return {
            // Base colors
            background: "#F0F0F0",
            secondaryBackground: "#E0E0E0",
            thirdBackground: "#D0D0D0",

            // Buttons and other elements
            elementBase: "#E0E0E0",
            elementHover: "#D0D0D0",
            elementPress: "#C0C0C0",

            // Text
            text: "black",
            secondaryText: "#333",
            placeholderText: "#888",
            link: "blue",

            // Text input
            inputBackground: "#E0E0E0",
            inputFieldBackground: "#D0D0D0",

            // DropDown
            dropdownElementHover: "#E0E0E0",

            // Colorful
            fail: "#CC3333",
            dangerBase: "#CC3333",
            dangerHover: "#CC4444",
            dangerPress: "#CC5555",
            success: "#33CC33",
            saveBase: "#33CC33",
            saveHover: "#44CC44",
            savePress: "#55CC55",

            // Additional theme-specific properties
            isDark: false
        }
    }

    readonly property var dark: {
        return {
            // Base colors
            background: "#1E1E1E",
            secondaryBackground: "#2A2A2A",
            thirdBackground: "#333333",

            // Buttons and other elements
            elementBase: "#333333",
            elementHover: "#383838",
            elementPress: "#404040",

            // Text
            text: "white",
            secondaryText: "#CCC",
            placeholderText: "#888",
            link: "cyan",

            // Text input
            inputBackground: "#333333",
            inputFieldBackground: "#404040",

            // DropDown
            dropdownElementHover: "#333333",

            // Colorful
            fail: "#993333",
            dangerBase: "#993333",
            dangerHover: "#994444",
            dangerPress: "#995555",
            success: "#339933",
            saveBase: "#339933",
            saveHover: "#449944",
            savePress: "#559955",

            // Additional theme-specific properties
            isDark: true
        }
    }

    property var currentTheme: light

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
