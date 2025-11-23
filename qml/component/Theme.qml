pragma Singleton
import QtQuick

QtObject {
    readonly property var light: ({
        windowBg: "#f5f7fb",
        cardBg: "#ffffff",
        stroke: "#e4e8f0",
        text: "#0f172a",
        muted: "#5f6b80",
        accent: "#0a84ff",
        panelBg: "#f8fafc",
        panelBorder: "#e5e7eb",
        canvasBg: "#f9fafc",
        grid: "#e7ebf3",
        label: "#9ca3af"
    })

    readonly property var dark: ({
        windowBg: "#0b1220",
        cardBg: "#0f172a",
        stroke: "#1f2937",
        text: "#e5e7eb",
        muted: "#94a3b8",
        accent: "#4f9cff",
        panelBg: "#0d1626",
        panelBorder: "#1f2937",
        canvasBg: "#111827",
        grid: "#1f2a3a",
        label: "#9ca3af"
    })
}
