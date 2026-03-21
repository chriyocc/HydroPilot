#ifndef CONFIG_STORE_H
#define CONFIG_STORE_H

#include <stdbool.h>
#include <stdint.h>

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

#define HYDRO_CFG_SSID_MAX_LEN 32
#define HYDRO_CFG_PASSWORD_MAX_LEN 64
#define HYDRO_CFG_DEVICE_ID_MAX_LEN 32
#define HYDRO_CFG_HOST_MAX_LEN 96
#define HYDRO_CFG_USERNAME_MAX_LEN 64
#define HYDRO_CFG_TOPIC_PREFIX_MAX_LEN 32

typedef struct {
    char wifi_ssid[HYDRO_CFG_SSID_MAX_LEN + 1];
    char wifi_password[HYDRO_CFG_PASSWORD_MAX_LEN + 1];
    char device_id[HYDRO_CFG_DEVICE_ID_MAX_LEN + 1];
    char mqtt_host[HYDRO_CFG_HOST_MAX_LEN + 1];
    uint16_t mqtt_port;
    char mqtt_username[HYDRO_CFG_USERNAME_MAX_LEN + 1];
    char mqtt_password[HYDRO_CFG_PASSWORD_MAX_LEN + 1];
    char topic_prefix[HYDRO_CFG_TOPIC_PREFIX_MAX_LEN + 1];
} hydro_config_t;

esp_err_t config_store_init(void);
esp_err_t config_store_load(hydro_config_t *out_config);
esp_err_t config_store_save(const hydro_config_t *config);
esp_err_t config_store_save_wifi_credentials(const char *ssid, const char *password);
bool config_store_has_wifi_credentials(const hydro_config_t *config);

#ifdef __cplusplus
}
#endif

#endif
