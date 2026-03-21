#include "mqtt_runtime.h"

#include <inttypes.h>
#include <stdio.h>
#include <string.h>

#include "cJSON.h"
#include "esp_crt_bundle.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "mqtt_client.h"

#include "actuator_sim.h"
#include "app_state.h"

static const char *TAG = "mqtt_runtime";

static esp_mqtt_client_handle_t s_client = NULL;
static hydro_config_t s_config;
static bool s_connected = false;

static int64_t now_ms(void)
{
    return esp_timer_get_time() / 1000;
}

static void build_topic(char *buffer, size_t buffer_size, const char *suffix)
{
    snprintf(buffer, buffer_size, "%s/device/%s/%s", s_config.topic_prefix, s_config.device_id, suffix);
}

static void publish_json(const char *topic, const char *payload)
{
    if (s_client == NULL || !s_connected) {
        return;
    }

    esp_mqtt_client_publish(s_client, topic, payload, 0, 1, 0);
}

static bool read_bool_target(cJSON *json, const char *field_name)
{
    cJSON *item = cJSON_GetObjectItemCaseSensitive(json, field_name);
    if (cJSON_IsBool(item)) {
        return cJSON_IsTrue(item);
    }
    return false;
}

static const char *read_request_id(cJSON *json)
{
    cJSON *item = cJSON_GetObjectItemCaseSensitive(json, "requestId");
    return cJSON_IsString(item) ? item->valuestring : "";
}

static void publish_online_snapshot(void)
{
    mqtt_runtime_publish_availability(true);
    mqtt_runtime_publish_state("pump", actuator_sim_is_pump_on(), "");
    mqtt_runtime_publish_state("light", actuator_sim_is_light_on(), "");
}

static void handle_command_message(const char *topic, const char *data)
{
    cJSON *json = cJSON_Parse(data);
    if (json == NULL) {
        ESP_LOGW(TAG, "Ignoring invalid JSON on %s", topic);
        return;
    }

    const char *request_id = read_request_id(json);

    if (strstr(topic, "/cmd/pump") != NULL) {
        const bool target = read_bool_target(json, "target");
        actuator_sim_set_pump(target);
        mqtt_runtime_publish_state("pump", target, request_id);
    } else if (strstr(topic, "/cmd/light") != NULL) {
        const bool target = read_bool_target(json, "target");
        actuator_sim_set_light(target);
        mqtt_runtime_publish_state("light", target, request_id);
    } else if (strstr(topic, "/cmd/nutrient/a") != NULL) {
        actuator_sim_pulse_nutrient_a();
        mqtt_runtime_publish_nutrient_result("a", request_id, true);
    } else if (strstr(topic, "/cmd/nutrient/b") != NULL) {
        actuator_sim_pulse_nutrient_b();
        mqtt_runtime_publish_nutrient_result("b", request_id, true);
    }

    cJSON_Delete(json);
}

static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    (void)handler_args;
    (void)base;
    esp_mqtt_event_handle_t event = event_data;

    switch ((esp_mqtt_event_id_t)event_id) {
        case MQTT_EVENT_CONNECTED: {
            char topic[160];
            s_connected = true;
            app_state_set_mqtt_connected(true);
            app_state_set_mode(HYDRO_MODE_RUNTIME);
            build_topic(topic, sizeof(topic), "cmd/pump");
            esp_mqtt_client_subscribe(s_client, topic, 1);
            build_topic(topic, sizeof(topic), "cmd/light");
            esp_mqtt_client_subscribe(s_client, topic, 1);
            build_topic(topic, sizeof(topic), "cmd/nutrient/a");
            esp_mqtt_client_subscribe(s_client, topic, 1);
            build_topic(topic, sizeof(topic), "cmd/nutrient/b");
            esp_mqtt_client_subscribe(s_client, topic, 1);
            publish_online_snapshot();
            ESP_LOGI(TAG, "MQTT connected and subscriptions restored");
            break;
        }
        case MQTT_EVENT_DISCONNECTED:
            s_connected = false;
            app_state_set_mqtt_connected(false);
            if (app_state_is_wifi_connected()) {
                app_state_set_mode(HYDRO_MODE_STA_CONNECTED);
            }
            ESP_LOGW(TAG, "MQTT disconnected");
            break;
        case MQTT_EVENT_DATA: {
            char topic[event->topic_len + 1];
            char payload[event->data_len + 1];
            memcpy(topic, event->topic, event->topic_len);
            topic[event->topic_len] = '\0';
            memcpy(payload, event->data, event->data_len);
            payload[event->data_len] = '\0';
            handle_command_message(topic, payload);
            break;
        }
        default:
            break;
    }
}

esp_err_t mqtt_runtime_start(const hydro_config_t *config)
{
    if (config == NULL || config->mqtt_host[0] == '\0' || config->device_id[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    if (s_client != NULL) {
        return ESP_OK;
    }

    memset(&s_config, 0, sizeof(s_config));
    s_config = *config;

    char broker_uri[160];
    snprintf(broker_uri, sizeof(broker_uri), "mqtts://%s:%u", s_config.mqtt_host, s_config.mqtt_port);

    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = broker_uri,
        .broker.verification.crt_bundle_attach = esp_crt_bundle_attach,
        .credentials.username = s_config.mqtt_username[0] == '\0' ? NULL : s_config.mqtt_username,
        .credentials.authentication.password = s_config.mqtt_password[0] == '\0' ? NULL : s_config.mqtt_password,
    };

    s_client = esp_mqtt_client_init(&mqtt_cfg);
    if (s_client == NULL) {
        return ESP_FAIL;
    }

    ESP_ERROR_CHECK(esp_mqtt_client_register_event(s_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL));
    ESP_ERROR_CHECK(esp_mqtt_client_start(s_client));
    ESP_LOGI(TAG, "MQTT runtime starting uri=%s device_id=%s", broker_uri, s_config.device_id);
    return ESP_OK;
}

void mqtt_runtime_stop(void)
{
    if (s_client == NULL) {
        return;
    }

    mqtt_runtime_publish_availability(false);
    esp_mqtt_client_stop(s_client);
    esp_mqtt_client_destroy(s_client);
    s_client = NULL;
    s_connected = false;
    app_state_set_mqtt_connected(false);
}

bool mqtt_runtime_is_connected(void)
{
    return s_connected;
}

esp_err_t mqtt_runtime_publish_availability(bool online)
{
    char topic[160];
    char payload[128];
    build_topic(topic, sizeof(topic), "availability");
    snprintf(payload, sizeof(payload), "{\"status\":\"%s\",\"ts\":%" PRId64 "}", online ? "online" : "offline", now_ms());
    publish_json(topic, payload);
    return ESP_OK;
}

esp_err_t mqtt_runtime_publish_state(const char *channel, bool actual, const char *request_id)
{
    char topic[160];
    char payload[192];
    char suffix[64];
    snprintf(suffix, sizeof(suffix), "state/%s", channel);
    build_topic(topic, sizeof(topic), suffix);
    snprintf(
        payload,
        sizeof(payload),
        "{\"requestId\":\"%s\",\"actual\":%s,\"on\":%s,\"ok\":true,\"ts\":%" PRId64 ",\"source\":\"device\"}",
        request_id == NULL ? "" : request_id,
        actual ? "true" : "false",
        actual ? "true" : "false",
        now_ms());
    publish_json(topic, payload);
    return ESP_OK;
}

esp_err_t mqtt_runtime_publish_nutrient_result(const char *channel, const char *request_id, bool ok)
{
    char topic[160];
    char payload[192];
    char suffix[64];
    snprintf(suffix, sizeof(suffix), "state/nutrient/%s", channel);
    build_topic(topic, sizeof(topic), suffix);
    snprintf(
        payload,
        sizeof(payload),
        "{\"requestId\":\"%s\",\"ok\":%s,\"action\":\"dose\",\"ts\":%" PRId64 ",\"source\":\"device\"}",
        request_id == NULL ? "" : request_id,
        ok ? "true" : "false",
        now_ms());
    publish_json(topic, payload);
    return ESP_OK;
}

esp_err_t mqtt_runtime_publish_telemetry(const char *field, float value)
{
    char topic[160];
    char payload[128];
    char suffix[64];
    snprintf(suffix, sizeof(suffix), "telemetry/%s", field);
    build_topic(topic, sizeof(topic), suffix);
    snprintf(payload, sizeof(payload), "{\"value\":%.2f,\"ts\":%" PRId64 "}", value, now_ms());
    publish_json(topic, payload);
    return ESP_OK;
}
