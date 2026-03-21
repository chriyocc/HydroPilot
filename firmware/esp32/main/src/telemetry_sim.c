#include "telemetry_sim.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "esp_log.h"

#include "app_state.h"
#include "mqtt_runtime.h"

static const char *TAG = "telemetry_sim";
static bool s_started = false;

static void telemetry_task(void *arg)
{
    (void)arg;

    int tick = 0;
    float water_level = 82.0f;

    while (true) {
        const float ph = 6.1f + ((float)(tick % 8) * 0.05f);
        const float ec = 1.7f + ((float)(tick % 6) * 0.04f);
        const float water_temperature = 24.0f + ((float)(tick % 5) * 0.2f);

        if (app_state_is_pump_on()) {
            water_level -= 0.6f;
        } else if (water_level < 82.0f) {
            water_level += 0.3f;
        }

        if (water_level < 58.0f) {
            water_level = 58.0f;
        } else if (water_level > 82.0f) {
            water_level = 82.0f;
        }

        app_state_set_telemetry(ph, ec, water_temperature, water_level);
        mqtt_runtime_publish_telemetry("ph", ph);
        mqtt_runtime_publish_telemetry("ec", ec);
        mqtt_runtime_publish_telemetry("temp", water_temperature);
        mqtt_runtime_publish_telemetry("waterlevel", water_level);

        tick++;
        vTaskDelay(pdMS_TO_TICKS(CONFIG_TELEMETRY_PUBLISH_INTERVAL_MS));
    }
}

esp_err_t telemetry_sim_start(void)
{
    if (s_started) {
        return ESP_OK;
    }

    BaseType_t result = xTaskCreate(telemetry_task, "telemetry_sim", 4096, NULL, 5, NULL);
    if (result != pdPASS) {
        return ESP_FAIL;
    }

    s_started = true;
    ESP_LOGI(TAG, "Telemetry simulator started");
    return ESP_OK;
}
