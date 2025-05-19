#include <WiFi.h>
#include <WebServer.h>
#include <EEPROM.h>
#include "esp_camera.h"
#include <Arduino.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

#define EEPROM_SIZE 140  // accommodate all data safely
#define WIFI_SSID_ADDR 0
#define WIFI_SSID_LEN 32
#define WIFI_PASS_ADDR 32
#define WIFI_PASS_LEN 32
#define WIFI_CONNECT_IP 64  // Moved to avoid overlap (50+20=70 would overlap USER_UID)
#define WIFI_IP_LEN 20      // Enough for "192.168.1.100" (15 chars)
#define USER_UID 84         // 64 + 20
#define USER_UID_LEN 56     // 140 - 84 = 56 bytes remaining

WebServer server(80);

// pin definition for CAMERA_MODEL_AI_THINKER
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

String readEEPROM(int start, int len) {
  String val;
  for (int i = start; i < start + len; i++) {
    char c = EEPROM.read(i);
    if (c == 0 || c == 255) break;
    val += c;
  }
  return val;
}

void printEEPROMContents() {
  Serial.println("EEPROM DUMP (Address : Hex | ASCII)");

  for (int i = 0; i < EEPROM_SIZE; i++) {
    byte val = EEPROM.read(i);
    Serial.print(i < 10 ? "0" : "");
    Serial.print(i);
    Serial.print(" : 0x");
    if (val < 16) Serial.print("0");
    Serial.print(val, HEX);
    Serial.print(" | ");

    // Print ASCII if printable
    if (val >= 32 && val <= 126) {
      Serial.write(val);
    } else {
      Serial.print(".");
    }

    Serial.println();
  }
}


void writeEEPROM(int start, const String &data) {
  for (int i = 0; i < data.length(); i++) {
    EEPROM.write(start + i, data[i]);
  }
  EEPROM.write(start + data.length(), 0);
  EEPROM.commit();
}

void connectToWiFi(const String &ssid, const String &pass) {
  WiFi.mode(WIFI_STA);
  const char* namessid = "NUTSHELL";
  const char* namepass = "123321nut";
  WiFi.begin(ssid.c_str(), pass.c_str());
  //check wi-fi is connected to wi-fi network
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("WiFi connected..!");
  
}

void handleReset() {
  Serial.println("Resetting WiFi credentials...");

  for (int i = 0; i < EEPROM_SIZE; i++) {
    EEPROM.write(i, 0);
  }
  EEPROM.commit();

  server.send(200, "text/plain", "WiFi credentials cleared. Rebooting...");
  delay(500);
  ESP.restart();
}

void handleConfig() {
  if (server.hasArg("ssid") && server.hasArg("password") && server.hasArg("useruid") && server.hasArg("idtoken")) {
    String ssid = server.arg("ssid");
    String password = server.arg("password");
    String useruid = server.arg("useruid");
    String idToken = server.arg("idtoken");
    server.send(200, "text/plain", "success");

    // Now save data to EEPROM
    writeEEPROM(WIFI_SSID_ADDR, ssid);
    writeEEPROM(WIFI_PASS_ADDR, password);
    writeEEPROM(USER_UID, useruid);
    EEPROM.commit();

    Serial.println("\nData stored in EEPROM");
    delay(100);

    // Disconnect after getting IP
    WiFi.disconnect(true); 

    delay(2000);
    Serial.println("\nRestarting.....");
    ESP.restart();

  } else {
    server.send(400, "text/plain", "Missing SSID or password");
  }
}

// void sendIPToFirestore(const String& useruid, const String& ipAddress, const String& idToken) {
//   if (WiFi.status() != WL_CONNECTED) return;

//   HTTPClient http;

//   // YOUR_FIREBASE_PROJECT_ID
//   String url = "https://firestore.googleapis.com/v1/projects/iot-app-25108/databases/(default)/documents/deviceip/" + useruid;

//   // Build the JSON payload
//   String payload = "{\"fields\": {\"ip\": {\"stringValue\": \"" + ipAddress + "\"}}}";

//   http.begin(url);
//   http.addHeader("Content-Type", "application/json");
//   http.addHeader("Authorization", "Bearer " + idToken); // << Add Authorization header here!

//   int httpResponseCode = http.sendRequest("PATCH", payload);

//   if (httpResponseCode > 0) {
//     String response = http.getString();
//     Serial.println("Firestore update success:");
//     Serial.println(response);
//   } else {
//     Serial.print("Firestore update failed, error: ");
//     Serial.println(httpResponseCode);
//   }

//   http.end();
// }

void handleStatus() {
  String response;
  if (WiFi.status() == WL_CONNECTED) {
    response += WiFi.localIP().toString();
  } else {
    response += "Connected: false\n";
    response += "SSID: " + readEEPROM(WIFI_SSID_ADDR, 32) + "\n";
    response += "IP: Not connected\n";
  }

  server.send(200, "text/plain", response);
}

void handleJpeg() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Cache-Control", "no-cache");
  
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    server.send(500, "text/plain", "Camera error");
    return;
  }
  
  server.send_P(200, "image/jpeg", (const char*)fb->buf, fb->len);
  esp_camera_fb_return(fb);
}

void sendErrorResponse(const String& message) {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(500, "text/plain", message);
}

void setup() {
  Serial.begin(115200);
  EEPROM.begin(EEPROM_SIZE);

  printEEPROMContents();

  String ssid = readEEPROM(WIFI_SSID_ADDR, WIFI_SSID_LEN);
  String pass = readEEPROM(WIFI_PASS_ADDR, WIFI_PASS_LEN);
  String ip = readEEPROM(WIFI_CONNECT_IP, WIFI_IP_LEN);
  String useruid = readEEPROM(USER_UID, USER_UID_LEN);

  // init camera
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = Y2_GPIO_NUM;
  config.pin_d1       = Y3_GPIO_NUM;
  config.pin_d2       = Y4_GPIO_NUM;
  config.pin_d3       = Y5_GPIO_NUM;
  config.pin_d4       = Y6_GPIO_NUM;
  config.pin_d5       = Y7_GPIO_NUM;
  config.pin_d6       = Y8_GPIO_NUM;
  config.pin_d7       = Y9_GPIO_NUM;
  config.pin_xclk     = XCLK_GPIO_NUM;
  config.pin_pclk     = PCLK_GPIO_NUM;
  config.pin_vsync    = VSYNC_GPIO_NUM;
  config.pin_href     = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn     = PWDN_GPIO_NUM;
  config.pin_reset    = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_SVGA;
  config.jpeg_quality = 12;
  config.fb_count = 1;

  esp_camera_init(&config);

  if (!ssid.isEmpty()) {
    connectToWiFi(ssid, pass); 
    server.on("/status-100", HTTP_GET, handleStatus);
    server.on("/cap-image-hi.jpeg", HTTP_GET, handleJpeg);
    server.on("/cap-image-hi.jpg", HTTP_GET, handleJpeg);
    server.on("/reset-440", HTTP_GET, handleReset);

  } else {
    WiFi.mode(WIFI_AP);
    WiFi.softAP("ESP32-CAM-SETUP", "123456789");
    server.on("/config-100", HTTP_GET, handleConfig);

  }
  
  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();
  delay(1);
}