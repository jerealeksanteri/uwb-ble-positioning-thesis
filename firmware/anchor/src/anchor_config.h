/**
 * @file      anchor_config.h
 *
 * @brief     Per-anchor configuration for UWB indoor positioning thesis.
 *
 * ANCHOR_ID must be defined at compile time via -DANCHOR_ID=1, 2, or 3.
 * This is passed through cmake: cmake ... -DANCHOR_ID=1
 */

#ifndef ANCHOR_CONFIG_H
#define ANCHOR_CONFIG_H

#ifndef ANCHOR_ID
#error "ANCHOR_ID must be defined (1, 2, or 3). Pass -DANCHOR_ID=N on the cmake command line."
#endif

#if ANCHOR_ID == 1
  #define ANCHOR_DEVICE_NAME "UWB-Anchor-1"
#elif ANCHOR_ID == 2
  #define ANCHOR_DEVICE_NAME "UWB-Anchor-2"
#elif ANCHOR_ID == 3
  #define ANCHOR_DEVICE_NAME "UWB-Anchor-3"
#else
  #error "ANCHOR_ID must be 1, 2, or 3"
#endif

#endif /* ANCHOR_CONFIG_H */
