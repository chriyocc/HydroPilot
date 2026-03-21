#ifndef ACTUATOR_SIM_H
#define ACTUATOR_SIM_H

#include <stdbool.h>

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t actuator_sim_init(void);
esp_err_t actuator_sim_set_pump(bool on);
esp_err_t actuator_sim_set_light(bool on);
bool actuator_sim_is_pump_on(void);
bool actuator_sim_is_light_on(void);
void actuator_sim_pulse_nutrient_a(void);
void actuator_sim_pulse_nutrient_b(void);

#ifdef __cplusplus
}
#endif

#endif
