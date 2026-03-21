#ifndef HTTP_SERVER_LOCAL_H
#define HTTP_SERVER_LOCAL_H

#include <stdbool.h>

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t http_server_local_start(void);
esp_err_t http_server_local_stop(void);
bool http_server_local_is_running(void);

#ifdef __cplusplus
}
#endif

#endif
