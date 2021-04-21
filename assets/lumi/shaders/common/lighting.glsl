#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/common/lighting.glsl                  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo, Contributors   *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

// STRENGTHS
const float SKYLESS_AMBIENT_STR = 0.8;
const float SKYLESS_LIGHT_STR = 2.0;
const float BLOCK_LIGHT_STR = 3.0;
const float BASE_AMBIENT_STR = 0.02;
const float HELD_LIGHT_STR = 1.5;
const float EMISSIVE_LIGHT_STR = 1.0;
const float NIGHT_VISION_STR = 3.0;

// MULTIPLIERS
const float BRIGHT_FINAL_MULT = 2.0;

// ADJUSTERS
const float BLOCK_LIGHT_ADJUSTER = 6.0;

// PREFERENCE
const float DEFAULT_Z_WOBBLE = 0.1;

// LIGHT COLORS
#if BLOCK_LIGHT_MODE == BLOCK_LIGHT_MODE_NEUTRAL
 // Not 1-triplet for balance. Is this necessary though?
const vec3 BLOCK_LIGHT_COLOR = vec3(0.74152, 0.74152, 0.74152);
#else
const vec3 BLOCK_LIGHT_COLOR = vec3(1.0, 0.7, 0.4);
#endif
const vec3 NIGHT_VISION_COLOR = vec3(0.63, 0.55, 0.64);
const vec3 SKYLESS_LIGHT_COLOR = vec3(1.0, 1.0, 1.0);
const vec3 NETHER_SKYLESS_LIGHT_COLOR = vec3(1.0, 0.6, 0.5);

#if SKY_MODE == SKY_MODE_LUMI
const vec3 NEBULAE_COLOR = hdr_gammaAdjust(vec3(0.8, 0.3, 0.6));
#else
const vec3 NEBULAE_COLOR = vec3(0.9, 0.75, 1.0);
#endif