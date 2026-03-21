idf_component_register(SRCS "src/main.c" "src/wifi_manager.c" "src/wifi_ap.c"
                            "src/config_store.c" "src/app_state.c" "src/actuator_sim.c"
                            "src/telemetry_sim.c" "src/mqtt_runtime.c" "src/http_server_local.c"
                      PRIV_REQUIRES esp_driver_gpio esp_wifi nvs_flash esp_netif esp_event esp_http_server mqtt json esp_timer
                       INCLUDE_DIRS "." "include")
