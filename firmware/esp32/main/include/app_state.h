#ifndef APP_STATE_H
#define APP_STATE_H

#include <stdbool.h>

#include "config_store.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    HYDRO_MODE_AP = 0,
    HYDRO_MODE_STA_CONNECTING,
    HYDRO_MODE_STA_CONNECTED,
    HYDRO_MODE_RUNTIME,
    HYDRO_MODE_FALLBACK_AP,
} hydro_runtime_mode_t;

typedef struct {
    hydro_runtime_mode_t mode;
    bool wifi_connected;
    bool mqtt_connected;
    bool pump_on;
    bool light_on;
    float ph;
    float ec;
    float water_temperature;
    float water_level;
    char local_ip[16];
} hydro_state_snapshot_t;

void app_state_init(void);
void app_state_set_mode(hydro_runtime_mode_t mode);
hydro_runtime_mode_t app_state_get_mode(void);
const char *app_state_get_mode_label(void);
void app_state_set_wifi_connected(bool connected);
bool app_state_is_wifi_connected(void);
void app_state_set_mqtt_connected(bool connected);
bool app_state_is_mqtt_connected(void);
void app_state_set_local_ip(const char *ip_address);
void app_state_set_pump_on(bool on);
void app_state_set_light_on(bool on);
bool app_state_is_pump_on(void);
bool app_state_is_light_on(void);
void app_state_set_telemetry(float ph, float ec, float water_temperature, float water_level);
void app_state_get_snapshot(hydro_state_snapshot_t *snapshot);
void app_state_request_reprovision(void);
bool app_state_consume_reprovision_request(void);

#ifdef __cplusplus
}
#endif

#endif
