#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tonemap.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl

/*******************************************************
 *  lumi:shaders/pipeline/post/common_vertex.glsl      *
 *******************************************************/

const vec3 day_sky = vec3(0.52, 0.69, 1.0);
const vec3 day_fog = vec3(0.75, 0.84375, 1.0);

vec3 calc_sky_color()
{
    vec3 skyColor;
    if (frx_isWorldTheOverworld()) {
        vec3 clear = frx_vanillaClearColor();
        float distanceToFog = distance(normalize(clear), normalize(day_fog));
        skyColor = mix(clear, day_sky, l2_clampScale(0.1, 0.05, distanceToFog));
    } else skyColor = frx_vanillaClearColor();
    vec3 grayScale = vec3(frx_luminance(skyColor));
    skyColor = mix(skyColor, grayScale, frx_playerFlag(FRX_PLAYER_EYE_IN_WATER) ? 1.0 : 0.0);
    return ldr_tonemap3(hdr_gammaAdjust(skyColor));
}
