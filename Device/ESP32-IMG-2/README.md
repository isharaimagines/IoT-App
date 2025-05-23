# WellSync - IoT & AI Based Digital Wellness Assistant

---

# WellSync IoT Device (ESP32 CAM)

---

## Project Overview

The WellSync IoT device is a core component of an AI-driven digital wellness system designed to monitor and mitigate technostress through real-time emotion detection during computer interactions. This ESP32 CAM-based device integrates emotion-sensing capabilities with Firebase/Firestore integration for data analysis and personalized intervention delivery.

---

## Prerequisites

### Hardware Requirements

- **ESP32 CAM Module** (Ai-Thinker Model)
- **USB Cable** (for programming)
- **Power Supply** (5V type-C USB compatible for Recharge Device)
- **3.7V 1800mA 18650 Li-ion Rechargeable Battery** (Battery Storage)
- **TP4056 5V 1A Micro USB 18650 Special Lithium Battery Charging Module** (Battery Charge)

### Software Requirements

- **Arduino IDE** (v2.0+)
- **ESP32 Board Support** (install via Arduino IDE Preferences)
- **Firebase Arduino Library** (install via Library Manager)
- **ArduinoJSON** (for structured data handling)

---

## Key Features

### Emotion-Sensing Architecture

| Component                | Functionality                                                                      |
| ------------------------ | ---------------------------------------------------------------------------------- |
| **Wi-Fi Configuration**  | Stores SSID, password, IP, and user UID in EEPROM for persistent connectivity.     |
| **EEPROM Management**    | Provides robust read/write utilities for handling configuration storage.           |
| **Web Server Interface** | Handles RESTful API endpoints for status, configuration, reset, and image capture. |
| **Camera Setup**         | Initializes OV2640 camera with specified GPIO mappings and parameters.             |
| **JPEG Streaming**       | Captures and serves a JPEG image over HTTP from the ESP32-CAM camera module.       |
| **Fallback AP Mode**     | Creates an access point for initial setup if Wi-Fi credentials are not found.      |
| **User Configuration**   | Accepts and saves SSID, password, UID, and token via `/config-100` endpoint.       |
| **Reset Functionality**  | Clears EEPROM data and reboots the device via `/reset-440` endpoint.               |
| **Device Status Check**  | Returns IP address and Wi-Fi connection status via `/status-100` endpoint.         |
| **CORS Support**         | Sends CORS headers in relevant endpoints for cross-origin access.                  |
| **Serial Debugging**     | Prints EEPROM content and operational messages for troubleshooting via serial.     |

### Core Capabilities

| **Capability**                | **Description**                                                                               |
| ----------------------------- | --------------------------------------------------------------------------------------------- |
| **Persistent Configuration**  | Stores and retrieves Wi-Fi credentials and user identifiers using EEPROM.                     |
| **Dynamic Network Mode**      | Switches between **Station Mode** and **Access Point Mode** based on EEPROM data presence.    |
| **Camera Integration**        | Initializes and configures the **ESP32-CAM** for JPEG image capture.                          |
| **HTTP Server Handling**      | Hosts multiple HTTP endpoints for configuration, image capture, reset, and status monitoring. |
| **EEPROM Utility Functions**  | Provides reusable functions for safely reading and writing strings to EEPROM.                 |
| **Remote Management**         | Enables device control (e.g., reset, configuration) over the network.                         |
| **Status Reporting**          | Offers real-time IP and connection status to clients.                                         |
| **Image Streaming**           | Captures camera frames and streams JPEGs over HTTP.                                           |
| **Cross-Origin Access**       | Enables front-end clients from other origins to access camera/image resources.                |
| **Device Restart Automation** | Automatically restarts the device after updates to Wi-Fi or UID credentials.                  |

---

## Troubleshooting

| Issue                         | Solution                                                        |
| ----------------------------- | --------------------------------------------------------------- |
| **No Serial Output**          | Check USB cable/power; Ensure BOOT button pressed during upload |
| **Firebase Connection Fails** | Verify API key validity; Check firewall rules                   |

---

## Requirement Library

```ino
#include <WiFi.h>
#include <WebServer.h>
#include <EEPROM.h>
#include "esp_camera.h"
#include <Arduino.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
```

## Code Structure

```plaintext
├── ESP32-IMG-2/
│   └── ESP32-IMG-2.ino      # full code

```

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

## Contributing

1. Fork repository
2. Create feature branch
3. Commit changes with clear commit messages
4. Push to branch
5. Create Pull Request

**Contact**: Goigoda Siriwardhana | Plymouth Index: 10898919 | Email: [10898919@students.plymouth.ac.uk]

---

## Documentation Links

- **ESP32 CAM Datasheet**: [Ai-Thinker ESP32-CAM](https://docs.ai-thinker.com/en/esp32-cam)
- **Firebase Arduino**: [Firebase Arduino Library](https://github.com/FirebaseExtended/firebase-arduino)
