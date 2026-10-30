import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    required property var cfg

    // 0: Focus (25m), 1: Short Break (5m), 2: Long Break (15m), 3: Custom
    property int currentMode: 0
    property int focusDurationSec: 25 * 60
    property int shortBreakDurationSec: 5 * 60
    property int longBreakDurationSec: 15 * 60
    property int customDurationSec: 10 * 60

    property int remainingSec: focusDurationSec
    property int totalSec: focusDurationSec
    property bool isRunning: false
    property int completedSessions: 0

    readonly property string modeName: {
        if (currentMode === 0) return "Фокус"
        if (currentMode === 1) return "Перерыв"
        if (currentMode === 2) return "Длинный отдых"
        return "Свое время"
    }

    readonly property string modeIcon: {
        if (currentMode === 0) return "󰄉"
        if (currentMode === 1) return "󰾪"
        if (currentMode === 2) return "󰒲"
        return "󱎫"
    }

    readonly property real progressRatio: totalSec > 0 ? (1.0 - (remainingSec / totalSec)) : 0.0

    function setCustomMinutes(mins) {
        let m = Math.max(1, Math.min(180, mins))
        customDurationSec = m * 60
        if (currentMode === 3) {
            totalSec = customDurationSec
            remainingSec = customDurationSec
            isRunning = false
        }
    }

    function addMinutes(deltaMins) {
        if (currentMode === 3) {
            let newMins = Math.max(1, Math.min(180, Math.round(customDurationSec / 60) + deltaMins))
            setCustomMinutes(newMins)
        } else {
            // Если в обычном режиме, переключаем на свое время с текущим + дельта
            let base = isRunning ? remainingSec : totalSec
            let newM = Math.max(1, Math.min(180, Math.round(base / 60) + deltaMins))
            currentMode = 3
            setCustomMinutes(newM)
        }
    }

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "00:00"
        let m = Math.floor(sec / 60)
        let s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    function toggle() {
        isRunning = !isRunning
    }

    function reset() {
        isRunning = false
        if (currentMode === 0) remainingSec = totalSec = focusDurationSec
        else if (currentMode === 1) remainingSec = totalSec = shortBreakDurationSec
        else if (currentMode === 2) remainingSec = totalSec = longBreakDurationSec
        else remainingSec = totalSec = customDurationSec
    }

    function setMode(m) {
        currentMode = m
        isRunning = false
        if (m === 0) totalSec = remainingSec = focusDurationSec
        else if (m === 1) totalSec = remainingSec = shortBreakDurationSec
        else if (m === 2) totalSec = remainingSec = longBreakDurationSec
        else totalSec = remainingSec = customDurationSec
    }

    function nextCycle() {
        if (currentMode === 0) {
            completedSessions++
            if (completedSessions % 4 === 0) {
                setMode(2) // Long break
            } else {
                setMode(1) // Short break
            }
        } else {
            setMode(0) // Back to focus
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.isRunning
        onTriggered: {
            if (root.remainingSec > 0) {
                root.remainingSec--
            } else {
                root.isRunning = false
                root.nextCycle()
                // Мягкое уведомление в quickshell без громких звуков
                if (root.cfg && root.cfg.pushNotification) {
                    root.cfg.pushNotification("Таймер", root.modeName + " завершен! Время переключиться.")
                }
            }
        }
    }
}
