#include "actuator_sim.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "driver/gpio.h"
#include "esp_log.h"
#include "sdkconfig.h"

#include "app_state.h"

static const char *TAG = "actuator_sim";

static void set_gpio(gpio_num_t pin, bool on)
{
    ESP_ERROR_CHECK(gpio_set_level(pin, on ? 1 : 0));
}

esp_err_t actuator_sim_init(void)
{
    gpio_reset_pin(CONFIG_PUMP_LED_GPIO);
    gpio_reset_pin(CONFIG_LIGHT_LED_GPIO);
    ESP_ERROR_CHECK(gpio_set_direction(CONFIG_PUMP_LED_GPIO, GPIO_MODE_OUTPUT));
    ESP_ERROR_CHECK(gpio_set_direction(CONFIG_LIGHT_LED_GPIO, GPIO_MODE_OUTPUT));
    ESP_ERROR_CHECK(actuator_sim_set_pump(false));
    ESP_ERROR_CHECK(actuator_sim_set_light(false));
    ESP_LOGI(TAG, "Actuator simulator ready pump_gpio=%d light_gpio=%d",
             CONFIG_PUMP_LED_GPIO, CONFIG_LIGHT_LED_GPIO);
    return ESP_OK;
}

esp_err_t actuator_sim_set_pump(bool on)
{
    set_gpio(CONFIG_PUMP_LED_GPIO, on);
    app_state_set_pump_on(on);
    ESP_LOGI(TAG, "Pump simulated state=%s", on ? "on" : "off");
    return ESP_OK;
}

esp_err_t actuator_sim_set_light(bool on)
{
    set_gpio(CONFIG_LIGHT_LED_GPIO, on);
    app_state_set_light_on(on);
    ESP_LOGI(TAG, "Grow light simulated state=%s", on ? "on" : "off");
    return ESP_OK;
}

bool actuator_sim_is_pump_on(void)
{
    return app_state_is_pump_on();
}

bool actuator_sim_is_light_on(void)
{
    return app_state_is_light_on();
}

static void pulse_gpio(gpio_num_t pin, bool restore_on, const char *label)
{
    for (int i = 0; i < 2; ++i) {
        set_gpio(pin, true);
        vTaskDelay(pdMS_TO_TICKS(CONFIG_NUTRIENT_PULSE_MS));
        set_gpio(pin, false);
        vTaskDelay(pdMS_TO_TICKS(CONFIG_NUTRIENT_PULSE_MS));
    }
    set_gpio(pin, restore_on);
    ESP_LOGI(TAG, "%s nutrient pulse completed", label);
}

void actuator_sim_pulse_nutrient_a(void)
{
    pulse_gpio(CONFIG_PUMP_LED_GPIO, actuator_sim_is_pump_on(), "A");
}

void actuator_sim_pulse_nutrient_b(void)
{
    pulse_gpio(CONFIG_LIGHT_LED_GPIO, actuator_sim_is_light_on(), "B");
}
