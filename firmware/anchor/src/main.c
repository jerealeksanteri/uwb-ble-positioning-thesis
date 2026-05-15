/**
 * @file      main.c
 *
 * @brief     FreeRTOS main
 *
 * @author    Qorvo Applications
 *
 * @copyright SPDX-FileCopyrightText: Copyright (c) 2024-2025 Qorvo US, Inc.
 *            SPDX-License-Identifier: LicenseRef-QORVO-2
 *
 */

#include "HAL_error.h"
#include "HAL_cpu.h"
#include "uwbmac/uwbmac.h"
#include "nrf_drv_clock.h"
#include "nrfx_nvmc.h"
#include "persistent_time.h"
#include <stdint.h>

#include "fira_niq.h"
#include "niq.h"
#include "anchor_config.h"
#include "boards.h"
#include "HAL_crypto.h"
#include "rtls_version.h"
#include "deca_device_api.h"
#include "qos.h"
#include "qlog.h"
#if CONFIG_LOG
#include <log_processing.h>
#endif

#define DEAD_BEEF 0xDEADBEEF /**< Value used as error code on stack dump, can be used to identify stack location on stack unwind. */

extern const char ApplicationName[]; /**< Name of Application release. */
extern const char OsName[];
extern const char BoardName[]; /**< Name of Target. Indicated in the advertising data. */

#ifdef CONFIG_LOG
static const char version[] = FULL_VERSION;
#endif

extern void ble_init(char *gap_name);

/**
 * @brief Callback function for asserts in the SoftDevice.
 *
 * @details This function will be called in case of an assert in the SoftDevice.
 *
 * @warning This handler is an example only and does not fit a final product. You need to analyze
 *          how your product is supposed to react in case of Assert.
 * @warning On assert from the SoftDevice, the system can only recover on reset.
 *
 * @param[in]   line_num   Line number of the failing ASSERT call.
 * @param[in]   file_name  File name of the failing ASSERT call.
 */
void assert_nrf_callback(uint16_t line_num, const uint8_t *p_file_name)
{
    app_error_handler(DEAD_BEEF, line_num, p_file_name);
}

/**
 * @brief Function for application main entry.
 */
int main(void)
{
    handle_cpu_protect();
    handle_fpu_irq();

    ret_code_t ret = nrf_drv_clock_init();
    if ((ret != NRF_SUCCESS) && (ret != NRF_ERROR_MODULE_ALREADY_INITIALIZED))
    {
        error_handler(1, _ERR);
    }

    /* Start LFCLK for proper operation of the RTC. */
    nrfx_clock_lfclk_start();
    while (!nrfx_clock_lfclk_is_running())
        ;

    nrfx_nvmc_icache_enable();

    /* Initialize persistant time base. */
    persistent_time_init(0);

#if CONFIG_LOG
    /* Start Log processing task, right after configuring clock sources. */
    create_log_processing_task();
#endif

    /* Accessory Nearby Interaction Initialization */
    niq_init(StartUWB, StopUWB, (const void *)crypto_init, (const void *)crypto_deinit, (const void *)crypto_get_random_vector);

    CreateQaniTask();

    /* Initialize board LEDs */
    bsp_board_init(BSP_INIT_LEDS);
    bsp_board_led_on(BSP_BOARD_LED_0);  /* Green LED: power on / advertising */

    /* Start BLE */
    char advertising_name[32];
    snprintf(advertising_name, sizeof(advertising_name), "%s", ANCHOR_DEVICE_NAME);
    ble_init(advertising_name);

    QLOGI("=== Anchor %d Starting ===", ANCHOR_ID);
    QLOGI("Device Name: %s", ANCHOR_DEVICE_NAME);
    QLOGI("Application: %s", ApplicationName);
    QLOGI("BOARD: %s", BoardName);
    QLOGI("OS: %s", OsName);
#ifdef CONFIG_LOG
    QLOGI("Version: %s", version);
#endif
    QLOGI("%s", dwt_version_string());
    QLOGI("MAC: %s", uwbmac_get_version());

    /* Start FreeRTOS scheduler */
    qos_start();

    for (;;)
    {
        APP_ERROR_HANDLER(NRF_ERROR_FORBIDDEN);
    }
}
