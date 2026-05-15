# SPDX-FileCopyrightText: Copyright (c) 2024 Qorvo US, Inc.
# SPDX-License-Identifier: LicenseRef-QORVO-2

set(MY_BOARD DWM3001CDK)
set(MY_OS FreeRTOS)
set(MY_SAMPLE "QANI") # Sample name consitent with the sample directory name
set(MY_HAL nrfx)
set(MY_BSP Nordic)
set(MY_CPU NRF52833_XXAA)
set(MY_LD_FILE nRF52833.ld)
set(CMAKE_CUSTOM_C_FLAGS
    "-Werror \
    -DBOARD_CUSTOM \
    -DBOARD_DWM3001_A1 \
    -DCONFIG_GPIO_AS_PINRESET \
    -D${MY_CPU} \
    -DUSE_NIQ"
)

# Add Soft Device flags
string(
  CONCAT
    CMAKE_CUSTOM_C_FLAGS
    ${CMAKE_CUSTOM_C_FLAGS}
    " -DNRF_SD_BLE_API_VERSION=7 \
      -DS113 \
      -DSOFTDEVICE_PRESENT \
      -DINITIALIZE_USER_SECTIONS \
      -DNO_VTOR_CONFIG \
      -DUSE_RTT_PRINT=1"
)

# Add Soft Device debug flag
string(CONCAT CMAKE_CUSTOM_C_FLAGS ${CMAKE_CUSTOM_C_FLAGS} " -DDEBUG")

# Add Soft Device flags
string(CONCAT CMAKE_ASM_FLAGS ${CMAKE_ASM_FLAGS} " -DDBOARD_CUSTOM \
                                                   -DS113 \
                                                   -DSOFTDEVICE_PRESENT"
)

set(MY_TARGET ${MY_BOARD}-${MY_SAMPLE}-${MY_OS})

add_definitions(-Os)

# Processor related defines
set(PROJECT_ARCH "m4")
set(PROJECT_FP "hard")
set(PROJECT_FPU "fpv4-sp-d16")

set(USE_DRV_DW3000 1)
set(USE_DRV_DW3720 0)

set(USE_CRYPTO_BACKEND_MBEDTLS 1)
set(USE_CRYPTO_SPEED_OPTIMIZATION 0)

if(USE_DRV_DW3720)
  message(FATAL_ERROR "Enabling DW3720 is not compatible with ${MY_BOARD} board.")
endif()

# Anchor identity for UWB positioning thesis
# Pass -DANCHOR_ID=1/2/3 on the cmake command line
if(DEFINED ANCHOR_ID)
  string(CONCAT CMAKE_CUSTOM_C_FLAGS ${CMAKE_CUSTOM_C_FLAGS} " -DANCHOR_ID=${ANCHOR_ID}")
  message("Building for Anchor ${ANCHOR_ID}")
endif()
