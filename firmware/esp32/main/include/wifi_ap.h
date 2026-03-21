#ifndef WIFI_AP_H
#define WIFI_AP_H

#include <stdbool.h>

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t wifi_ap_start(void);
esp_err_t wifi_ap_stop(void);
bool wifi_ap_is_running(void);

#ifdef __cplusplus
}
#endif

#endif
