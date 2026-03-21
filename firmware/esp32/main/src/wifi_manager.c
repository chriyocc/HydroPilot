#include "wifi_manager.h"

#include <string.h>

#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "sdkconfig.h"

#include "app_state.h"

static const char *TAG = "wifi_manager";

static volatile bool s_wifi_connected = false;
static volatile bool s_wifi_failed = false;
static int s_retry_count = 0;
static esp_netif_t *s_sta_netif = NULL;
static char s_ip_address[16] = "";

static void wifi_event_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    (void)arg;

    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        ESP_LOGI(TAG, "Wi-Fi station started");
        ESP_ERROR_CHECK(esp_wifi_connect());
        return;
    }

    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        s_wifi_connected = false;
        app_state_set_wifi_connected(false);
        app_state_set_local_ip("");

        if (s_retry_count < CONFIG_WIFI_MAXIMUM_RETRY) {
            s_retry_count++;
            ESP_LOGW(TAG, "Wi-Fi disconnected, retry %d/%d", s_retry_count, CONFIG_WIFI_MAXIMUM_RETRY);
            ESP_ERROR_CHECK(esp_wifi_connect());
        } else {
            s_wifi_failed = true;
            ESP_LOGE(TAG, "Wi-Fi connection failed after %d retries", CONFIG_WIFI_MAXIMUM_RETRY);
        }
        return;
    }

    if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
        s_wifi_connected = true;
        s_wifi_failed = false;
        s_retry_count = 0;
        snprintf(s_ip_address, sizeof(s_ip_address), IPSTR, IP2STR(&event->ip_info.ip));
        app_state_set_wifi_connected(true);
        app_state_set_local_ip(s_ip_address);
        ESP_LOGI(TAG, "Connected with IP: %s", s_ip_address);
    }
}

esp_err_t wifi_manager_start(const hydro_config_t *config)
{
    if (config == NULL || config->wifi_ssid[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    s_wifi_connected = false;
    s_wifi_failed = false;
    s_retry_count = 0;
    s_ip_address[0] = '\0';

    s_sta_netif = esp_netif_create_default_wifi_sta();
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL));

    wifi_config_t wifi_config = {
        .sta = {
            .threshold.authmode = WIFI_AUTH_WPA2_PSK,
        },
    };

    strlcpy((char *)wifi_config.sta.ssid, config->wifi_ssid, sizeof(wifi_config.sta.ssid));
    strlcpy((char *)wifi_config.sta.password, config->wifi_password, sizeof(wifi_config.sta.password));
    if (config->wifi_password[0] == '\0') {
        wifi_config.sta.threshold.authmode = WIFI_AUTH_OPEN;
    }

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    app_state_set_mode(HYDRO_MODE_STA_CONNECTING);
    return ESP_OK;
}

esp_err_t wifi_manager_stop(void)
{
    esp_event_handler_unregister(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler);
    esp_event_handler_unregister(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler);
    esp_wifi_stop();
    esp_wifi_deinit();
    if (s_sta_netif != NULL) {
        esp_netif_destroy(s_sta_netif);
        s_sta_netif = NULL;
    }
    s_wifi_connected = false;
    s_wifi_failed = false;
    s_retry_count = 0;
    s_ip_address[0] = '\0';
    app_state_set_wifi_connected(false);
    app_state_set_local_ip("");
    return ESP_OK;
}

bool wifi_manager_is_connected(void)
{
    return s_wifi_connected;
}

bool wifi_manager_has_failed(void)
{
    return s_wifi_failed;
}

const char *wifi_manager_get_ip(void)
{
    return s_ip_address;
}
