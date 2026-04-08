import QtQuick

// Shared stateless helper functions; instantiate once per component:
//   Globals { id: globals }
// then call globals.scoreColor(score), globals.formatSize(bytes), etc.
QtObject {
    // Tooltip delay used across all screens (ms)
    readonly property int tooltipDelay: 600

    // Smooth score gradient: red(0) → orange(6.0) → green(7.5) → vivid-green(10)
    function scoreColor(score) {
        var s = Math.max(0, Math.min(10, parseFloat(score) || 0))
        var r, g, b
        if (s >= 7.5) {
            var t = (s - 7.5) / 2.5
            r = 0.298 * (1 - t)
            g = 0.686 + t * (0.902 - 0.686)
            b = 0.314 + t * (0.463 - 0.314)
        } else if (s >= 6.0) {
            var t = (s - 6.0) / 1.5
            r = 1.000 - t * (1.000 - 0.298)
            g = 0.596 + t * (0.686 - 0.596)
            b = t * 0.314
        } else {
            var t = s / 6.0
            r = 0.827 + t * (1.000 - 0.827)
            g = 0.184 + t * (0.596 - 0.184)
            b = 0.184 * (1 - t)
        }
        return Qt.rgba(r, g, b, 1.0)
    }

    function formatSize(bytes) {
        if (bytes <= 0) return ""
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(0) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec <= 0) return ""
        if (bytesPerSec < 1024) return bytesPerSec + " B/s"
        if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
    }

    function formatDate(timestamp) {
        if (!timestamp) return ""
        var d = new Date(timestamp * 1000)
        var now = new Date()
        var pad = (n) => n < 10 ? "0" + n : "" + n
        var time = pad(d.getHours()) + ":" + pad(d.getMinutes())
        if (d.toDateString() === now.toDateString())
            return "Today " + time
        var yesterday = new Date(now)
        yesterday.setDate(yesterday.getDate() - 1)
        if (d.toDateString() === yesterday.toDateString())
            return "Yesterday " + time
        return pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + d.getFullYear() + " " + time
    }

    function isVideoFile(filename) {
        return filename.endsWith(".mp4") || filename.endsWith(".mkv") || filename.endsWith(".webm")
    }
}
