# 📱 Quickshell for Hyprland (Material You / Pixel UI)

<div align="center">

[English](README.md) | **Русский**

[![Hyprland](https://img.shields.io/badge/Hyprland-0.42%2B-00ADD8?logo=hyprland&logoColor=white)](https://hyprland.org/)
[![Quickshell](https://img.shields.io/badge/Quickshell-Qt6%20%2F%20QML-41CD52?logo=qt&logoColor=white)](https://git.outfoxxed.me/outfoxxed/quickshell)
[![Style](https://img.shields.io/badge/Style-Material%20You%20%2F%20Pixel-4285F4?logo=google&logoColor=white)](https://m3.material.io/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*Полнофункциональное окружение рабочего стола для Hyprland на базе Quickshell в аутентичном стиле Google Pixel / Material Design 3.*

</div>

---

## ⚡ Быстрая установка (One-line installer)

Установка в 1 команду: скрипт автоматически проверит зависимости, установит фирменные шрифты (Google Sans, Rubik, Material Symbols), развернет конфигурацию Quickshell и добавит готовые кейбинды в Hyprland:

```bash
curl -fsSL https://raw.githubusercontent.com/StopNope/quickshell-hyprland/main/install.sh | bash
```

### Ручная установка

```bash
git clone https://github.com/StopNope/quickshell-hyprland.git ~/.quickshell-repo
cd ~/.quickshell-repo
./install.sh
```

---

## 🔄 Автообновление

Обновление до самой свежей версии из GitHub в 1 команду:

```bash
quickshell-update
```

*(Или через графический интерфейс: `Super + G` ➔ вкладка «Система» ➔ кнопка «Обновить»).*

---

## ✨ Возможности

### 🌟 Dynamic Bar (Панель задач)
* **Гибкая модульная архитектура**: монолитный режим либо парящие капсулы (островки).
* **Горизонтальный и вертикальный режимы** с индивидуальным расположением модулей.
* **Pixel Scallop Clock**: часы-цветок в стиле Google Pixel с орбитальной точкой-секундой.
* **Pebble Weather**: органический 72-точечный контур погоды Pebble с плавной адаптацией.
* **Объединение модулей** в единые капсулы (например, `[ CPU | RAM | GPU ]` или `[ Часы + Погода ]`) с тонкими разделителями.
* **Полнофункциональный System Tray**:
  * Всплывающие контекстные меню DBus (Telegram, Discord, Steam и т.д.).
  * Кнопка мгновенного завершения процесса (**«Завершить процесс (Kill)»**).

### 🎛 Quick Settings & SidePanel (Шторка управления)
* Плитки быстрых настроек в стиле Android 14/15: Wi-Fi, Bluetooth, Ethernet, DND, Ночной свет, Энергосбережение.
* **Реальный режим «Не беспокоить» (DND)**: синхронизация с системным демоном `swaync`.
* **Реальный «Ночной свет»**: аппаратный GLSL-шейдер фильтрации синего света для Hyprland (`hyprctl keyword decoration:screen_shader`).
* **Реальный режим энергосбережения**: мгновенно отключает размытие, тени и анимации Hyprland для максимальной автономности и FPS.
* Плавные слайдеры звука и яркости с цветовой индикацией.

### 📱 Pixel Dock (Док-бар)
* Плавный автохайдинг с продуманной физикой и жестами мыши.
* Закрепление приложений, индикаторы запущенных окон, контекстное меню по ПКМ.

### 🧩 Bento Desktop Widgets (Виджеты рабочего стола)
* Набор виджетов Material 3: Часы, Календарь с мягкой пилюлей активного дня, Погода с прогнозом, Мониторинг ресурсов (Vitals), Медиаплеер, Хранилище, Заметки.
* **Визуальный редактор виджетов** (`Super + Shift + W`): интерактивное перемещение, изменение размеров и радиуса скругления прямо на рабочем столе.

### 🪟 Windows 11 Alt+Tab App Switcher
* Переключение окон по `Alt + Tab` с живыми превью, иконками приложений и мгновенным фокусом при отпускании клавиш.

### 🔍 Spotlight Launcher & Буфер обмена
* Быстрый поиск и лаунчер приложений в стиле Android 15 (`Super + R` / `Super + Space`).
* Менеджер истории буфера обмена (`Super + V`) с поддержкой текста и картинок.

### 📸 Инструмент скриншотов
* Интерактивный полноэкранный оверлей (`Super + Shift + S` / `Print`) для удобного захвата областей и окон.

### 🌐 Бесконечный рабочий стол (VxWM Spatial Canvas)
* Пространственная навигация окнами (`Super + D`), плавное панорамирование стрелками или колесом мыши, масштабирование холста (Zoom In/Out).

---

## ⌨ Горячие клавиши

| Сочетание | Описание |
| :--- | :--- |
| **`Super + G`** | Центр настроек (Бар, Док, Виджеты, Темы, Система) |
| **`Super + U`** | Шторка быстрых настроек (SidePanel) |
| **`Super + L`** | Экран блокировки (Lockscreen) |
| **`Super + R`** / **`Super + Space`** | Лаунчер приложений и поиск |
| **`Super + V`** | Менеджер буфера обмена |
| **`Alt + Tab`** | Переключатель окон в стиле Windows 11 с превью |
| **`Super + Shift + S`** / **`Print`** | Интерактивный скриншот |
| **`Super + Shift + W`** | Визуальный редактор виджетов рабочего стола |
| **`Super + N`** | Меню сетей Wi-Fi |
| **`Super + B`** | Меню Bluetooth |
| **`Super + E`** | Меню проводной сети Ethernet |
| **`Super + D`** | Вкл/выкл бесконечный рабочий стол (VxWM) |
| **`Super + Shift + D`** | Ограничивать окна текущим монитором (Clamp) |
| **`Super + Ctrl + ← / → / ↑ / ↓`** | Панорамирование холста бесконечного стола |
| **`Super + Mouse Wheel`** | Вертикальный скролл бесконечного холста |
| **`Super + Shift + Mouse Wheel`** | Горизонтальный скролл бесконечного холста |
| **`Super + =`** / **`Super + -`** | Zoom In / Zoom Out холста |
| **`Super + 0`** | Сброс масштаба холста |

---

## 🛠 Зависимости

* **Hyprland** (0.42+)
* **Quickshell** (0.0.1+ / outfoxxed)
* **Python 3**
* **jq**, **grim**, **slurp**, **wl-clipboard**, **cliphist**

---

## 📄 Лицензия

Проект распространяется под лицензией MIT.
