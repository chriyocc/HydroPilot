import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
MAIN = ROOT / "main"
INCLUDE = MAIN / "include"
SRC = MAIN / "src"


class FirmwareSimulatorStructureTest(unittest.TestCase):
    def test_required_firmware_modules_exist(self):
        expected = [
            INCLUDE / "app_state.h",
            INCLUDE / "config_store.h",
            INCLUDE / "http_server_local.h",
            INCLUDE / "mqtt_runtime.h",
            INCLUDE / "actuator_sim.h",
            INCLUDE / "telemetry_sim.h",
            SRC / "app_state.c",
            SRC / "config_store.c",
            SRC / "http_server_local.c",
            SRC / "mqtt_runtime.c",
            SRC / "actuator_sim.c",
            SRC / "telemetry_sim.c",
        ]

        missing = [
            path.relative_to(ROOT).as_posix()
            for path in expected
            if not path.exists()
        ]
        self.assertFalse(missing, f"missing firmware modules: {missing}")

    def test_kconfig_exposes_runtime_simulation_settings(self):
        kconfig = (MAIN / "Kconfig.projbuild").read_text()

        expected_tokens = [
            "PUMP_LED_GPIO",
            "LIGHT_LED_GPIO",
            "MQTT_BROKER_HOST",
            "MQTT_BROKER_PORT",
            "MQTT_USERNAME",
            "MQTT_PASSWORD",
            "HYDRO_DEVICE_ID",
            "HYDRO_TOPIC_PREFIX",
            "TELEMETRY_PUBLISH_INTERVAL_MS",
            "NUTRIENT_PULSE_MS",
        ]

        for token in expected_tokens:
            self.assertIn(token, kconfig, f"{token} missing from Kconfig.projbuild")

    def test_readme_documents_simulator_runtime(self):
        readme = (ROOT / "README.md").read_text()

        expected_sections = [
            "ESP-IDF HydroPilot Firmware Simulator",
            "Boot Modes",
            "LED Mapping",
            "Local REST Endpoints",
            "MQTT Topics",
            "Build, Flash, Monitor",
            "Test Without Real Hardware",
            "Integration Notes for Teammates",
        ]

        for section in expected_sections:
            self.assertIn(section, readme, f"{section!r} missing from README.md")

    def test_main_wires_state_machine_modules(self):
        main_c = (SRC / "main.c").read_text()

        expected_tokens = [
            "config_store_init",
            "app_state_init",
            "http_server_local_start",
            "mqtt_runtime_start",
            "telemetry_sim_start",
            "actuator_sim_init",
        ]

        for token in expected_tokens:
            self.assertIn(token, main_c, f"{token} missing from main.c")

    def test_component_build_no_longer_depends_on_legacy_led_module(self):
        cmake_text = (MAIN / "CMakeLists.txt").read_text()
        self.assertNotIn('"src/led.c"', cmake_text)

    def test_sdkconfig_defaults_do_not_reference_removed_blink_symbols(self):
        defaults_files = list(ROOT.glob("sdkconfig.defaults*"))
        for defaults_file in defaults_files:
            text = defaults_file.read_text()
            self.assertNotIn("BLINK_LED_GPIO", text, f"legacy blink symbol remains in {defaults_file.name}")
            self.assertNotIn("BLINK_GPIO", text, f"legacy blink gpio remains in {defaults_file.name}")

    def test_http_server_header_declares_bool_safely(self):
        header_text = (INCLUDE / "http_server_local.h").read_text()
        self.assertIn("#include <stdbool.h>", header_text)

    def test_http_server_configures_enough_uri_handler_slots(self):
        source = (SRC / "http_server_local.c").read_text()
        self.assertIn("config.max_uri_handlers", source)

    def test_mqtt_runtime_uses_tls_and_certificate_bundle(self):
        source = (SRC / "mqtt_runtime.c").read_text()
        self.assertIn("mqtts://", source)
        self.assertIn("esp_crt_bundle_attach", source)
        self.assertIn("broker.verification.crt_bundle_attach", source)

    def test_readme_mentions_tls_for_secure_brokers(self):
        readme = (ROOT / "README.md").read_text()
        self.assertIn("TLS", readme)
        self.assertIn("mqtts://", readme)


if __name__ == "__main__":
    unittest.main()
