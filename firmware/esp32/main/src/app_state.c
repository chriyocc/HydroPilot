#include "app_state.h"

#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

typedef struct {
    hydro_state_snapshot_t snapshot;
    bool reprovision_requested;
    SemaphoreHandle_t mutex;
} hydro_app_state_t;

static hydro_app_state_t s_state;

static void lock_state(void)
{
    xSemaphoreTake(s_state.mutex, portMAX_DELAY);
}

static void unlock_state(void)
{
    xSemaphoreGive(s_state.mutex);
}

void app_state_init(void)
{
    memset(&s_state, 0, sizeof(s_state));
    s_state.snapshot.mode = HYDRO_MODE_AP;
    s_state.snapshot.water_level = 82.0f;
    s_state.snapshot.water_temperature = 24.0f;
    s_state.snapshot.ph = 6.2f;
    s_state.snapshot.ec = 1.8f;
    s_state.mutex = xSemaphoreCreateMutex();
}

void app_state_set_mode(hydro_runtime_mode_t mode)
{
    lock_state();
    s_state.snapshot.mode = mode;
    unlock_state();
}

hydro_runtime_mode_t app_state_get_mode(void)
{
    hydro_runtime_mode_t mode;
    lock_state();
    mode = s_state.snapshot.mode;
    unlock_state();
    return mode;
}

const char *app_state_get_mode_label(void)
{
    switch (app_state_get_mode()) {
        case HYDRO_MODE_AP:
            return "ap";
        case HYDRO_MODE_STA_CONNECTING:
            return "sta_connecting";
        case HYDRO_MODE_STA_CONNECTED:
            return "sta_connected";
        case HYDRO_MODE_RUNTIME:
            return "runtime";
        case HYDRO_MODE_FALLBACK_AP:
            return "fallback_ap";
        default:
            return "unknown";
    }
}

void app_state_set_wifi_connected(bool connected)
{
    lock_state();
    s_state.snapshot.wifi_connected = connected;
    unlock_state();
}

bool app_state_is_wifi_connected(void)
{
    bool connected;
    lock_state();
    connected = s_state.snapshot.wifi_connected;
    unlock_state();
    return connected;
}

void app_state_set_mqtt_connected(bool connected)
{
    lock_state();
    s_state.snapshot.mqtt_connected = connected;
    unlock_state();
}

bool app_state_is_mqtt_connected(void)
{
    bool connected;
    lock_state();
    connected = s_state.snapshot.mqtt_connected;
    unlock_state();
    return connected;
}

void app_state_set_local_ip(const char *ip_address)
{
    lock_state();
    strlcpy(s_state.snapshot.local_ip, ip_address == NULL ? "" : ip_address, sizeof(s_state.snapshot.local_ip));
    unlock_state();
}

void app_state_set_pump_on(bool on)
{
    lock_state();
    s_state.snapshot.pump_on = on;
    unlock_state();
}

void app_state_set_light_on(bool on)
{
    lock_state();
    s_state.snapshot.light_on = on;
    unlock_state();
}

bool app_state_is_pump_on(void)
{
    bool on;
    lock_state();
    on = s_state.snapshot.pump_on;
    unlock_state();
    return on;
}

bool app_state_is_light_on(void)
{
    bool on;
    lock_state();
    on = s_state.snapshot.light_on;
    unlock_state();
    return on;
}

void app_state_set_telemetry(float ph, float ec, float water_temperature, float water_level)
{
    lock_state();
    s_state.snapshot.ph = ph;
    s_state.snapshot.ec = ec;
    s_state.snapshot.water_temperature = water_temperature;
    s_state.snapshot.water_level = water_level;
    unlock_state();
}

void app_state_get_snapshot(hydro_state_snapshot_t *snapshot)
{
    lock_state();
    *snapshot = s_state.snapshot;
    unlock_state();
}

void app_state_request_reprovision(void)
{
    lock_state();
    s_state.reprovision_requested = true;
    unlock_state();
}

bool app_state_consume_reprovision_request(void)
{
    bool requested;
    lock_state();
    requested = s_state.reprovision_requested;
    s_state.reprovision_requested = false;
    unlock_state();
    return requested;
}
