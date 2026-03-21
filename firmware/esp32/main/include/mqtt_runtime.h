#ifndef MQTT_RUNTIME_H
#define MQTT_RUNTIME_H

#include <stdbool.h>

#include "config_store.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t mqtt_runtime_start(const hydro_config_t *config);
void mqtt_runtime_stop(void);
bool mqtt_runtime_is_connected(void);
esp_err_t mqtt_runtime_publish_availability(bool online);
esp_err_t mqtt_runtime_publish_state(const char *channel, bool actual, const char *request_id);
esp_err_t mqtt_runtime_publish_nutrient_result(const char *channel, const char *request_id, bool ok);
esp_err_t mqtt_runtime_publish_telemetry(const char *field, float value);

#ifdef __cplusplus
}
#endif

#endif
