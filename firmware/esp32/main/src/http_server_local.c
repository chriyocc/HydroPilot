#include "http_server_local.h"

#include <inttypes.h>
#include <stdio.h>
#include <string.h>

#include "cJSON.h"
#include "esp_http_server.h"
#include "esp_log.h"
#include "esp_timer.h"

#include "actuator_sim.h"
#include "app_state.h"
#include "config_store.h"
#include "mqtt_runtime.h"

static const char *TAG = "http_local";
static httpd_handle_t s_server = NULL;

static esp_err_t send_json(httpd_req_t *req, const char *json)
{
    httpd_resp_set_type(req, "application/json");
    return httpd_resp_sendstr(req, json);
}

static esp_err_t send_bad_request(httpd_req_t *req, const char *message)
{
    httpd_resp_set_status(req, "400 Bad Request");
    return send_json(req, message);
}

static esp_err_t read_request_body(httpd_req_t *req, char *buffer, size_t buffer_size)
{
    if (req->content_len <= 0 || (size_t)req->content_len >= buffer_size) {
        return ESP_ERR_INVALID_SIZE;
    }

    int received = httpd_req_recv(req, buffer, req->content_len);
    if (received <= 0) {
        return ESP_FAIL;
    }

    buffer[received] = '\0';
    return ESP_OK;
}

static esp_err_t health_get_handler(httpd_req_t *req)
{
    hydro_state_snapshot_t snapshot;
    hydro_config_t config;
    char response[320];
    ESP_ERROR_CHECK(config_store_load(&config));
    app_state_get_snapshot(&snapshot);
    snprintf(
        response,
        sizeof(response),
        "{\"mode\":\"%s\",\"deviceId\":\"%s\",\"wifiConnected\":%s,\"mqttConnected\":%s,\"uptimeMs\":%" PRId64 "}",
        app_state_get_mode_label(),
        config.device_id,
        snapshot.wifi_connected ? "true" : "false",
        snapshot.mqtt_connected ? "true" : "false",
        esp_timer_get_time() / 1000);
    return send_json(req, response);
}

static esp_err_t status_get_handler(httpd_req_t *req)
{
    hydro_state_snapshot_t snapshot;
    char response[256];
    app_state_get_snapshot(&snapshot);
    snprintf(
        response,
        sizeof(response),
        "{\"ph\":%.2f,\"ec\":%.2f,\"waterTemperature\":%.2f,\"waterLevel\":%.2f,\"pumpOn\":%s,\"lightOn\":%s}",
        snapshot.ph,
        snapshot.ec,
        snapshot.water_temperature,
        snapshot.water_level,
        snapshot.pump_on ? "true" : "false",
        snapshot.light_on ? "true" : "false");
    return send_json(req, response);
}

static esp_err_t debug_status_get_handler(httpd_req_t *req)
{
    hydro_state_snapshot_t snapshot;
    char response[512];
    app_state_get_snapshot(&snapshot);
    snprintf(
        response,
        sizeof(response),
        "{\"mode\":\"%s\",\"wifiConnected\":%s,\"mqttConnected\":%s,\"localIp\":\"%s\",\"telemetry\":{\"ph\":%.2f,\"ec\":%.2f,\"waterTemperature\":%.2f,\"waterLevel\":%.2f},\"actuators\":{\"pumpOn\":%s,\"lightOn\":%s}}",
        app_state_get_mode_label(),
        snapshot.wifi_connected ? "true" : "false",
        snapshot.mqtt_connected ? "true" : "false",
        snapshot.local_ip,
        snapshot.ph,
        snapshot.ec,
        snapshot.water_temperature,
        snapshot.water_level,
        snapshot.pump_on ? "true" : "false",
        snapshot.light_on ? "true" : "false");
    return send_json(req, response);
}

static esp_err_t config_get_handler(httpd_req_t *req)
{
    hydro_config_t config;
    char response[512];
    ESP_ERROR_CHECK(config_store_load(&config));
    snprintf(
        response,
        sizeof(response),
        "{\"wifiSsid\":\"%s\",\"deviceId\":\"%s\",\"mqttHost\":\"%s\",\"mqttPort\":%u,\"mqttUsername\":\"%s\",\"mqttPasswordSet\":%s,\"topicPrefix\":\"%s\"}",
        config.wifi_ssid,
        config.device_id,
        config.mqtt_host,
        config.mqtt_port,
        config.mqtt_username,
        config.mqtt_password[0] == '\0' ? "false" : "true",
        config.topic_prefix);
    return send_json(req, response);
}

static esp_err_t config_put_handler(httpd_req_t *req)
{
    char body[512];
    if (read_request_body(req, body, sizeof(body)) != ESP_OK) {
        return send_bad_request(req, "{\"error\":\"invalid request body\"}");
    }

    cJSON *json = cJSON_Parse(body);
    if (json == NULL) {
        return send_bad_request(req, "{\"error\":\"invalid json\"}");
    }

    hydro_config_t config;
    ESP_ERROR_CHECK(config_store_load(&config));

    cJSON *device_id = cJSON_GetObjectItemCaseSensitive(json, "deviceId");
    cJSON *mqtt_host = cJSON_GetObjectItemCaseSensitive(json, "mqttHost");
    cJSON *mqtt_port = cJSON_GetObjectItemCaseSensitive(json, "mqttPort");
    cJSON *mqtt_username = cJSON_GetObjectItemCaseSensitive(json, "mqttUsername");
    cJSON *mqtt_password = cJSON_GetObjectItemCaseSensitive(json, "mqttPassword");
    cJSON *topic_prefix = cJSON_GetObjectItemCaseSensitive(json, "topicPrefix");

    if (cJSON_IsString(device_id)) {
        strlcpy(config.device_id, device_id->valuestring, sizeof(config.device_id));
    }
    if (cJSON_IsString(mqtt_host)) {
        strlcpy(config.mqtt_host, mqtt_host->valuestring, sizeof(config.mqtt_host));
    }
    if (cJSON_IsNumber(mqtt_port)) {
        config.mqtt_port = (uint16_t)mqtt_port->valuedouble;
    }
    if (cJSON_IsString(mqtt_username)) {
        strlcpy(config.mqtt_username, mqtt_username->valuestring, sizeof(config.mqtt_username));
    }
    if (cJSON_IsString(mqtt_password)) {
        strlcpy(config.mqtt_password, mqtt_password->valuestring, sizeof(config.mqtt_password));
    }
    if (cJSON_IsString(topic_prefix)) {
        strlcpy(config.topic_prefix, topic_prefix->valuestring, sizeof(config.topic_prefix));
    }

    ESP_ERROR_CHECK(config_store_save(&config));
    cJSON_Delete(json);
    return send_json(req, "{\"ok\":true}");
}

static esp_err_t wifi_post_handler(httpd_req_t *req)
{
    char body[256];
    if (read_request_body(req, body, sizeof(body)) != ESP_OK) {
        return send_bad_request(req, "{\"error\":\"invalid request body\"}");
    }

    cJSON *json = cJSON_Parse(body);
    if (json == NULL) {
        return send_bad_request(req, "{\"error\":\"invalid json\"}");
    }

    cJSON *ssid = cJSON_GetObjectItemCaseSensitive(json, "ssid");
    cJSON *password = cJSON_GetObjectItemCaseSensitive(json, "password");
    if (!cJSON_IsString(ssid) || ssid->valuestring[0] == '\0' || !cJSON_IsString(password)) {
        cJSON_Delete(json);
        return send_bad_request(req, "{\"error\":\"ssid and password are required\"}");
    }

    ESP_ERROR_CHECK(config_store_save_wifi_credentials(ssid->valuestring, password->valuestring));
    app_state_request_reprovision();
    cJSON_Delete(json);
    return send_json(req, "{\"ok\":true,\"message\":\"wifi credentials saved\"}");
}

static esp_err_t pump_post_handler(httpd_req_t *req)
{
    char body[128];
    if (read_request_body(req, body, sizeof(body)) != ESP_OK) {
        return send_bad_request(req, "{\"error\":\"invalid request body\"}");
    }

    cJSON *json = cJSON_Parse(body);
    cJSON *on = json == NULL ? NULL : cJSON_GetObjectItemCaseSensitive(json, "on");
    if (!cJSON_IsBool(on)) {
        cJSON_Delete(json);
        return send_bad_request(req, "{\"error\":\"on must be boolean\"}");
    }

    actuator_sim_set_pump(cJSON_IsTrue(on));
    mqtt_runtime_publish_state("pump", cJSON_IsTrue(on), "");
    cJSON_Delete(json);
    return send_json(req, "{\"ok\":true}");
}

static esp_err_t light_post_handler(httpd_req_t *req)
{
    char body[128];
    if (read_request_body(req, body, sizeof(body)) != ESP_OK) {
        return send_bad_request(req, "{\"error\":\"invalid request body\"}");
    }

    cJSON *json = cJSON_Parse(body);
    cJSON *on = json == NULL ? NULL : cJSON_GetObjectItemCaseSensitive(json, "on");
    if (!cJSON_IsBool(on)) {
        cJSON_Delete(json);
        return send_bad_request(req, "{\"error\":\"on must be boolean\"}");
    }

    actuator_sim_set_light(cJSON_IsTrue(on));
    mqtt_runtime_publish_state("light", cJSON_IsTrue(on), "");
    cJSON_Delete(json);
    return send_json(req, "{\"ok\":true}");
}

static esp_err_t nutrient_post_handler(httpd_req_t *req, bool is_a)
{
    char body[128];
    if (read_request_body(req, body, sizeof(body)) != ESP_OK) {
        return send_bad_request(req, "{\"error\":\"invalid request body\"}");
    }

    cJSON *json = cJSON_Parse(body);
    cJSON *dose = json == NULL ? NULL : cJSON_GetObjectItemCaseSensitive(json, "dose");
    if (!cJSON_IsBool(dose) || !cJSON_IsTrue(dose)) {
        cJSON_Delete(json);
        return send_bad_request(req, "{\"error\":\"dose must be true\"}");
    }

    if (is_a) {
        actuator_sim_pulse_nutrient_a();
        mqtt_runtime_publish_nutrient_result("a", "", true);
    } else {
        actuator_sim_pulse_nutrient_b();
        mqtt_runtime_publish_nutrient_result("b", "", true);
    }

    cJSON_Delete(json);
    return send_json(req, "{\"ok\":true}");
}

static esp_err_t nutrient_a_post_handler(httpd_req_t *req)
{
    return nutrient_post_handler(req, true);
}

static esp_err_t nutrient_b_post_handler(httpd_req_t *req)
{
    return nutrient_post_handler(req, false);
}

static const httpd_uri_t s_routes[] = {
    {.uri = "/health", .method = HTTP_GET, .handler = health_get_handler, .user_ctx = NULL},
    {.uri = "/status", .method = HTTP_GET, .handler = status_get_handler, .user_ctx = NULL},
    {.uri = "/debug/status", .method = HTTP_GET, .handler = debug_status_get_handler, .user_ctx = NULL},
    {.uri = "/config", .method = HTTP_GET, .handler = config_get_handler, .user_ctx = NULL},
    {.uri = "/config", .method = HTTP_PUT, .handler = config_put_handler, .user_ctx = NULL},
    {.uri = "/wifi", .method = HTTP_POST, .handler = wifi_post_handler, .user_ctx = NULL},
    {.uri = "/control/pump", .method = HTTP_POST, .handler = pump_post_handler, .user_ctx = NULL},
    {.uri = "/control/light", .method = HTTP_POST, .handler = light_post_handler, .user_ctx = NULL},
    {.uri = "/control/nutrient/a", .method = HTTP_POST, .handler = nutrient_a_post_handler, .user_ctx = NULL},
    {.uri = "/control/nutrient/b", .method = HTTP_POST, .handler = nutrient_b_post_handler, .user_ctx = NULL},
};

esp_err_t http_server_local_start(void)
{
    if (s_server != NULL) {
        return ESP_OK;
    }

    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = 80;
    config.max_uri_handlers = (sizeof(s_routes) / sizeof(s_routes[0])) + 2;
    ESP_ERROR_CHECK(httpd_start(&s_server, &config));
    for (size_t i = 0; i < sizeof(s_routes) / sizeof(s_routes[0]); ++i) {
        ESP_ERROR_CHECK(httpd_register_uri_handler(s_server, &s_routes[i]));
    }
    ESP_LOGI(TAG, "Local maintenance HTTP server started");
    return ESP_OK;
}

esp_err_t http_server_local_stop(void)
{
    if (s_server == NULL) {
        return ESP_OK;
    }

    ESP_ERROR_CHECK(httpd_stop(s_server));
    s_server = NULL;
    ESP_LOGI(TAG, "Local maintenance HTTP server stopped");
    return ESP_OK;
}

bool http_server_local_is_running(void)
{
    return s_server != NULL;
}
