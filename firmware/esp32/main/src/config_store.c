#include "config_store.h"

#include <string.h>

#include "esp_log.h"
#include "nvs.h"
#include "nvs_flash.h"
#include "sdkconfig.h"

#define HYDRO_CFG_NAMESPACE "hydro_cfg"

static const char *TAG = "config_store";

static void copy_string(char *destination, size_t destination_size, const char *source)
{
    if (destination_size == 0) {
        return;
    }

    if (source == NULL) {
        destination[0] = '\0';
        return;
    }

    strlcpy(destination, source, destination_size);
}

static void load_defaults(hydro_config_t *config)
{
    memset(config, 0, sizeof(*config));
    copy_string(config->wifi_ssid, sizeof(config->wifi_ssid), CONFIG_WIFI_SSID);
    copy_string(config->wifi_password, sizeof(config->wifi_password), CONFIG_WIFI_PASSWORD);
    copy_string(config->device_id, sizeof(config->device_id), CONFIG_HYDRO_DEVICE_ID);
    copy_string(config->mqtt_host, sizeof(config->mqtt_host), CONFIG_MQTT_BROKER_HOST);
    config->mqtt_port = CONFIG_MQTT_BROKER_PORT;
    copy_string(config->mqtt_username, sizeof(config->mqtt_username), CONFIG_MQTT_USERNAME);
    copy_string(config->mqtt_password, sizeof(config->mqtt_password), CONFIG_MQTT_PASSWORD);
    copy_string(config->topic_prefix, sizeof(config->topic_prefix), CONFIG_HYDRO_TOPIC_PREFIX);
}

static esp_err_t read_string(nvs_handle_t handle, const char *key, char *buffer, size_t buffer_size)
{
    size_t required_size = buffer_size;
    esp_err_t err = nvs_get_str(handle, key, buffer, &required_size);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK;
    }
    return err;
}

static esp_err_t write_string(nvs_handle_t handle, const char *key, const char *value)
{
    if (value == NULL) {
        value = "";
    }

    return nvs_set_str(handle, key, value);
}

esp_err_t config_store_init(void)
{
    ESP_LOGI(TAG, "Config store ready");
    return ESP_OK;
}

esp_err_t config_store_load(hydro_config_t *out_config)
{
    if (out_config == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    hydro_config_t config;
    load_defaults(&config);

    nvs_handle_t handle;
    esp_err_t err = nvs_open(HYDRO_CFG_NAMESPACE, NVS_READONLY, &handle);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        *out_config = config;
        return ESP_OK;
    }
    ESP_ERROR_CHECK(err);

    ESP_ERROR_CHECK(read_string(handle, "wifi_ssid", config.wifi_ssid, sizeof(config.wifi_ssid)));
    ESP_ERROR_CHECK(read_string(handle, "wifi_pass", config.wifi_password, sizeof(config.wifi_password)));
    ESP_ERROR_CHECK(read_string(handle, "device_id", config.device_id, sizeof(config.device_id)));
    ESP_ERROR_CHECK(read_string(handle, "mqtt_host", config.mqtt_host, sizeof(config.mqtt_host)));
    ESP_ERROR_CHECK(read_string(handle, "mqtt_user", config.mqtt_username, sizeof(config.mqtt_username)));
    ESP_ERROR_CHECK(read_string(handle, "mqtt_pass", config.mqtt_password, sizeof(config.mqtt_password)));
    ESP_ERROR_CHECK(read_string(handle, "topic_prefix", config.topic_prefix, sizeof(config.topic_prefix)));

    uint16_t mqtt_port = config.mqtt_port;
    err = nvs_get_u16(handle, "mqtt_port", &mqtt_port);
    if (err == ESP_OK) {
        config.mqtt_port = mqtt_port;
    } else if (err != ESP_ERR_NVS_NOT_FOUND) {
        nvs_close(handle);
        return err;
    }

    nvs_close(handle);
    *out_config = config;
    return ESP_OK;
}

esp_err_t config_store_save(const hydro_config_t *config)
{
    if (config == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    nvs_handle_t handle;
    ESP_ERROR_CHECK(nvs_open(HYDRO_CFG_NAMESPACE, NVS_READWRITE, &handle));
    ESP_ERROR_CHECK(write_string(handle, "wifi_ssid", config->wifi_ssid));
    ESP_ERROR_CHECK(write_string(handle, "wifi_pass", config->wifi_password));
    ESP_ERROR_CHECK(write_string(handle, "device_id", config->device_id));
    ESP_ERROR_CHECK(write_string(handle, "mqtt_host", config->mqtt_host));
    ESP_ERROR_CHECK(nvs_set_u16(handle, "mqtt_port", config->mqtt_port));
    ESP_ERROR_CHECK(write_string(handle, "mqtt_user", config->mqtt_username));
    ESP_ERROR_CHECK(write_string(handle, "mqtt_pass", config->mqtt_password));
    ESP_ERROR_CHECK(write_string(handle, "topic_prefix", config->topic_prefix));
    ESP_ERROR_CHECK(nvs_commit(handle));
    nvs_close(handle);
    ESP_LOGI(TAG, "Saved config for device_id=%s", config->device_id);
    return ESP_OK;
}

esp_err_t config_store_save_wifi_credentials(const char *ssid, const char *password)
{
    hydro_config_t config;
    ESP_ERROR_CHECK(config_store_load(&config));
    copy_string(config.wifi_ssid, sizeof(config.wifi_ssid), ssid);
    copy_string(config.wifi_password, sizeof(config.wifi_password), password);
    return config_store_save(&config);
}

bool config_store_has_wifi_credentials(const hydro_config_t *config)
{
    if (config == NULL) {
        return false;
    }

    return config->wifi_ssid[0] != '\0';
}
