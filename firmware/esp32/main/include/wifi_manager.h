#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

#include <stdbool.h>

#include "config_store.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t wifi_manager_start(const hydro_config_t *config);
esp_err_t wifi_manager_stop(void);
bool wifi_manager_is_connected(void);
bool wifi_manager_has_failed(void);
const char *wifi_manager_get_ip(void);

#ifdef __cplusplus
}
#endif

#endif
