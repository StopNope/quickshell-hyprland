# 📱 Quickshell for Hyprland (Material You / Pixel UI)

<div align="center">

**English** | [Русский](README_ru.md)

[![Hyprland](https://img.shields.io/badge/Hyprland-0.42%2B-00ADD8?logo=hyprland&logoColor=white)](https://hyprland.org/)
[![Quickshell](https://img.shields.io/badge/Quickshell-Qt6%20%2F%20QML-41CD52?logo=qt&logoColor=white)](https://git.outfoxxed.me/outfoxxed/quickshell)
[![Style](https://img.shields.io/badge/Style-Material%20You%20%2F%20Pixel-4285F4?logo=google&logoColor=white)](https://m3.material.io/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*A complete, polished desktop environment shell for Hyprland powered by Quickshell, designed in authentic Google Pixel & Material Design 3 (Android 14/15).*

</div>

---

## ⚡ Quick Installation (One-line installer)

Install in a single command. The script automatically verifies dependencies, installs required fonts (Google Sans, Rubik, Material Symbols), deploys the Quickshell configuration, and safely appends keybindings to your Hyprland configuration:

```bash
curl -fsSL https://raw.githubusercontent.com/StopNope/quickshell-hyprland/main/install.sh | bash
```

### Manual Installation

```bash
git clone https://github.com/StopNope/quickshell-hyprland.git ~/.quickshell-repo
cd ~/.quickshell-repo
./install.sh
```

---

## 🔄 Automatic Updates

Update to the latest release directly from GitHub with one command:

```bash
quickshell-update
```

*(Or via the GUI: press `Super + G` ➔ "System" tab ➔ "Update" button).*

---

## ✨ Features

### 🌟 Dynamic Bar
* **Modular architecture**: Choose between a monolithic solid bar or floating islands / capsules.
* **Horizontal & Vertical modes**: Independent module layouts and orientations for primary and secondary monitors.
* **Pixel Scallop Clock**: Signature Google Pixel organic floral scallop clock with an orbiting second dot.
* **Pebble Weather**: 72-point smooth organic pebble contour with dynamic weather condition styling.
* **Module Grouping**: Combine multiple indicators into single unified capsules (e.g. `[ CPU | RAM | GPU ]` or `[ Clock + Weather ]`) with hairline dividers.
* **Full-featured System Tray**:
  * Native Wayland DBus context menus for background apps (Telegram, Discord, Steam, etc.).
  * Dedicated instant process termination action (**«Kill process»**).

### 🎛 Quick Settings & SidePanel
* Android 14/15 inspired quick setting tiles: Wi-Fi, Bluetooth, Ethernet, DND, Night Light, Power Saver.
* **Real Do Not Disturb (DND)**: Bi-directional synchronization with `swaync` notification daemon.
* **Hardware Night Light**: Built-in GLSL blue light filter shader for Hyprland (`hyprctl keyword decoration:screen_shader`).
* **Instant Power Saver Mode**: Dynamically disables Hyprland blur, drop shadows, and animations to minimize power consumption and maximize battery life / FPS.
* Smooth volume and brightness pill sliders with color feedback.

### 📱 Pixel Dock
* Smooth autohiding dock with realistic physics and gesture detection.
* App pinning, active window dots, and right-click context menus.

### 🧩 Bento Desktop Widgets
* Comprehensive Material 3 desktop widgets: Clock (Dual-line, Bento, Analog), Calendar with active day pill, Weather forecast, System Vitals (CPU/RAM/GPU), Media Player, Storage, and Quick Notes.
* **Live In-place Widget Editor** (`Super + Shift + W`): Drag, resize, and configure corner radiuses directly on your desktop.

### 🪟 Windows 11 Alt+Tab App Switcher
* Fast window switcher with live thumbnails, app icons, and instant focus on key release.

### 🔍 Spotlight Launcher & Clipboard Manager
* Android 15 inspired spotlight app launcher and search (`Super + R` / `Super + Space`).
* Full clipboard history manager (`Super + V`) supporting both rich text and images.

### 📸 Screenshot Utility
* Interactive full-screen capture overlay (`Super + Shift + S` / `Print`) for convenient region and window captures.

### 🌐 Infinite Canvas (VxWM Spatial Workspace)
* Spatial window canvas (`Super + D`), smooth panning via arrow keys or mouse wheel, and canvas zooming (Zoom In/Out).

---

## ⌨ Keybindings Cheat Sheet

| Shortcut | Description |
| :--- | :--- |
| **`Super + G`** | Settings Center (Bar, Dock, Widgets, Themes, System) |
| **`Super + U`** | Quick Settings Shade (SidePanel) |
| **`Super + L`** | Lock Screen |
| **`Super + R`** / **`Super + Space`** | Application Launcher & Search |
| **`Super + V`** | Clipboard History Manager |
| **`Alt + Tab`** | Windows 11 Style Window Switcher with Live Previews |
| **`Super + Shift + S`** / **`Print`** | Interactive Screenshot Tool |
| **`Super + Shift + W`** | Live Desktop Widget Editor |
| **`Super + N`** | Wi-Fi Network Menu |
| **`Super + B`** | Bluetooth Device Menu |
| **`Super + E`** | Ethernet Connection Menu |
| **`Super + D`** | Toggle Infinite Spatial Canvas (VxWM) |
| **`Super + Shift + D`** | Clamp Windows to Current Monitor |
| **`Super + Ctrl + ← / → / ↑ / ↓`** | Pan Spatial Canvas |
| **`Super + Mouse Wheel`** | Vertical Scroll on Spatial Canvas |
| **`Super + Shift + Mouse Wheel`** | Horizontal Scroll on Spatial Canvas |
| **`Super + =`** / **`Super + -`** | Zoom In / Zoom Out on Spatial Canvas |
| **`Super + 0`** | Reset Spatial Canvas Zoom |

---

## 🛠 Dependencies

* **Hyprland** (0.42+)
* **Quickshell** (0.0.1+ / outfoxxed)
* **Python 3**
* **jq**, **grim**, **slurp**, **wl-clipboard**, **cliphist**

---

## 📄 License

This project is licensed under the MIT License.
