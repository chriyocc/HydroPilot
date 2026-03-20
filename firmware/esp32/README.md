# HydroPilot ESP32 Firmware

This directory contains the ESP32 firmware for HydroPilot.

## Current State

The existing firmware was moved here from the Flutter app directory and preserved as a legacy Arduino sketch:

- [`/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/src/ESP32_AdafruitIO.ino`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/src/ESP32_AdafruitIO.ino)

It still reflects the older Adafruit IO smart-home prototype and should be treated as a starting point, not the final HydroPilot firmware.

## Structure

```text
firmware/esp32/
  src/
  include/
  lib/
  test/
  .vscode/
```

## Notes

- The sketch currently references `config.h`, which is not present in this repo.
- The next firmware step is to replace the Adafruit IO logic with the HydroPilot local REST + remote MQTT design documented in [`/Users/yoyojun/Documents/GitHub/HydroPilot/docs/API_DOCUMENTATION.md`](/Users/yoyojun/Documents/GitHub/HydroPilot/docs/API_DOCUMENTATION.md).
