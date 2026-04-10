# 🥊 Gamified Punching Bag: Impact Tracker

This repository contains the mobile application source code for a gamified heavy bag training system. Built with Flutter, this app interfaces via Bluetooth Low Energy (BLE) with a custom hardware module to provide real-time impact data, session history, and peak force visualization.

## 📱 Features
* **Real-Time Force Gauge:** High-performance UI rendering to capture and display peak impulse data dynamically.
* **Session History & Graphing:** Chronological logging of impacts, visualized via a continuous line chart to track user fatigue and power output.
* **Dynamic Theming:** User-selectable UI modes (Modern Dark, Clean Light, Neon Cyberpunk).
* **Hardware-Filtered BLE:** Custom BLE scanning logic optimized to isolate the specific training module in noisy engineering environments.

## 🔌 Hardware / Firmware Data Contract
For the mobile app to successfully parse incoming hardware data, the microcontroller (ESP32/nRF) must adhere to the following BLE standards:

* **Device Name:** Must contain the string `"PunchBag"` (e.g., `PunchBag_MCU_1`).
* **Payload Format:** Force data must be transmitted as a **16-bit unsigned integer** (`uint16_t`).
* **Byte Order:** Little Endian (Least significant byte transmitted first).
* **Sample Rate Expectation:** Hardware should capture impacts at $\ge400\text{ Hz}$ to ensure peak force accuracy before transmitting the finalized value to the app.

## 🚀 Installation & Testing

### Option 1: Direct Android Installation (Easiest)
For field testing, you do not need to compile the code. 
1. Navigate to the [Releases](../../releases) tab on the right side of this repository.
2. Download the latest `app-release.apk` file directly to your Android device.
3. Open the file to install (Ensure "Install from Unknown Sources" is enabled in your Android settings).

### Option 2: Local Development Setup
To contribute to the UI or modify the BLE logic, set up the local Flutter environment:
1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Clone this repository: 
   `git clone https://github.com/YourUsername/Gamified-Punching-Bag-App.git`
3. Fetch dependencies:
   `flutter pub get`
4. Run the app on a connected physical device (Required for Bluetooth access):
   `flutter run`
   *(Note: Web and Desktop emulators will crash when attempting to access the BLE radio).*

## 🛠 Tech Stack
* **Framework:** Flutter (Dart)
* **Bluetooth:** `flutter_blue_plus`
* **Visualization:** `fl_chart`, CustomPainter API
* **State Management:** `ValueNotifier`, `IndexedStack`
