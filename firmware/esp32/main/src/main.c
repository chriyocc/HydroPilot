// Pull in the core FreeRTOS definitions used by ESP-IDF.
#include "freertos/FreeRTOS.h"
// Gives us vTaskDelay(), which pauses the current task.
#include "freertos/task.h"
// Defines esp_err_t and ESP_ERROR_CHECK().
#include "esp_err.h"
// Lets us create and use the ESP-IDF event loop.
#include "esp_event.h"
#include "esp_log.h"
// Provides the network interface layer used by Wi-Fi.
#include "esp_netif.h"
// Provides non-volatile storage initialization for Wi-Fi and system data.
#include "nvs_flash.h"
// Exposes values generated from menuconfig, such as CONFIG_BLINK_PERIOD.
#include "sdkconfig.h"

#include "actuator_sim.h"
#include "app_state.h"
#include "config_store.h"
#include "http_server_local.h"
#include "mqtt_runtime.h"
#include "telemetry_sim.h"
#include "wifi_ap.h"
#include "wifi_manager.h"

static void start_ap_maintenance_mode(void)
{
    app_state_set_mode(HYDRO_MODE_AP);
    ESP_ERROR_CHECK(wifi_ap_start());
    ESP_ERROR_CHECK(http_server_local_start());
}

static void start_station_runtime(const hydro_config_t *config)
{
    app_state_set_mode(HYDRO_MODE_STA_CONNECTING);
    ESP_ERROR_CHECK(wifi_manager_start(config));
}

void app_main(void)
{
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    ESP_ERROR_CHECK(config_store_init());
    app_state_init();
    ESP_ERROR_CHECK(actuator_sim_init());
    ESP_ERROR_CHECK(telemetry_sim_start());

    hydro_config_t config;
    ESP_ERROR_CHECK(config_store_load(&config));

    if (config_store_has_wifi_credentials(&config)) {
        start_station_runtime(&config);
    } else {
        start_ap_maintenance_mode();
    }

    while (1) {
        if (app_state_consume_reprovision_request()) {
            ESP_LOGI("main", "Applying new WiFi provisioning and switching to STA mode");
            http_server_local_stop();
            wifi_ap_stop();
            config_store_load(&config);
            start_station_runtime(&config);
        }

        if (wifi_manager_is_connected()) {
            if (!http_server_local_is_running()) {
                http_server_local_start();
            }
            if (!mqtt_runtime_is_connected()) {
                app_state_set_mode(HYDRO_MODE_STA_CONNECTED);
                mqtt_runtime_start(&config);
            }
        }

        if (wifi_manager_has_failed()) {
            ESP_LOGW("main", "WiFi failed, falling back to AP maintenance mode");
            mqtt_runtime_stop();
            http_server_local_stop();
            wifi_manager_stop();
            app_state_set_mode(HYDRO_MODE_FALLBACK_AP);
            start_ap_maintenance_mode();
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}
