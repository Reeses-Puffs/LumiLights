#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:reflection_config

/*******************************************************
 *  lumi:shaders/context/post/reflection.glsl          *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#if REFLECTION_PROFILE == REFLECTION_PROFILE_EXTREME
    const float HITBOX = 0.0375;
    const int MAXSTEPS = 109;
    const int PERIOD = 18;
    const int REFINE = 16;
#endif

#if REFLECTION_PROFILE == REFLECTION_PROFILE_HIGH
    const float HITBOX = 0.125;
    const int MAXSTEPS = 50;
    const int PERIOD = 9;
    const int REFINE = 16;
#endif

#if REFLECTION_PROFILE == REFLECTION_PROFILE_MEDIUM
    const float HITBOX = 0.125;
    const int MAXSTEPS = 36;
    const int PERIOD = 5;
    const int REFINE = 8;
#endif

#if REFLECTION_PROFILE == REFLECTION_PROFILE_LOW
    const float HITBOX = 0.25;
    const int MAXSTEPS = 19;
    const int PERIOD = 3;
    const int REFINE = 8;
#endif

const float REFLECTION_MAXIMUM_ROUGHNESS = REFLECTION_MAXIMUM_ROUGHNESS_RELATIVE / 10.0;


#if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
vec2 view2uv(vec3 view, mat4 projection)
{
    vec4 clip = projection * vec4(view, 1.0);
    clip.xyz /= clip.w;
    return clip.xy * 0.5 + 0.5;
}

float sample_depth(vec2 uv, in sampler2D sdepth)
{
    return texture2D(sdepth, uv).r;
}

vec3 uv2view(vec2 uv, mat4 inv_projection, in sampler2D sdepth)
{
    float depth = sample_depth(uv, sdepth);
    vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
    vec4 view = inv_projection * vec4(clip, 1.0);
    return view.xyz / view.w;
}

vec3 view2world(vec3 view, mat4 inv_view)
{
    return frx_cameraPos() + (inv_view * vec4(view, 1.0)).xyz;
}

vec3 sample_worldNormal(vec2 uv, in sampler2D snormal)
{
    return 2.0 * texture2D(snormal, uv).xyz - 1.0;
}

float skylight_adjust(float skyLight, float intensity)
{
    return l2_clampScale(0.03125, 1.0, skyLight) * intensity;
}

struct rt_Result
{
    vec2 reflected_uv;
    bool hit;
    int hits;
};

vec3 pbr_lightCalc(float roughness, vec3 f0, vec3 radiance, vec3 lightDir, vec3 viewDir)
{
    vec3 halfway = normalize(viewDir + lightDir);
    vec3 fresnel = pbr_fresnelSchlick(pbr_dot(viewDir, halfway), f0);
    float roughnessFade = smoothstep(REFLECTION_MAXIMUM_ROUGHNESS, REFLECTION_MAXIMUM_ROUGHNESS - 0.05, roughness);

    return clamp(fresnel * radiance * roughnessFade * (1-roughness), 0.0, 1.0);
}

rt_Result rt_reflection(
    vec3 ray_view, vec3 unit_view, vec3 normal, vec3 unit_march,
    mat3 normal_matrix, mat4 projection, mat4 inv_projection,
    in sampler2D reflector_depth, in sampler2D reflector_normal, in sampler2D reflected_depth, in sampler2D reflected_normal
)
{
    vec3 start_view = ray_view.xyz;
    float edge_z = start_view.z + 0.25;
    // float hitbox_z = mix(HITBOX, 1.0, sqrt(start_view.z/512.0));
    float hitbox_z = HITBOX;
    vec3 ray = unit_march * hitbox_z;

    float hitbox_mult;
    vec2 current_uv;
    vec3 current_view;
    float delta_z;
    bool backface;
    vec3 reflectedNormal;
    
    int hits = 0;
    int steps = 0;
    int refine_steps = 0;
    while (steps < MAXSTEPS) {
        ray_view += ray;
        current_uv = view2uv(ray_view, projection);
        current_view = uv2view(current_uv, inv_projection, reflected_depth);
        delta_z = current_view.z - ray_view.z;
        reflectedNormal = normalize(normal_matrix * sample_worldNormal(current_uv, reflected_normal));
        backface = dot(unit_march, reflectedNormal) > 0;
        // backface = backface || (unit_march.y != 0.0 && abs(current_view.y - start_view.y) < 1.0);
        if (delta_z > 0 && !backface && (current_view.z < edge_z || unit_march.z > 0.0)) {
            // Remove "occlusion factor" (result.hit > 1) because it doesn't work when looking down, i.e. where it is needed the most
            // if (current_uv.x >= 0.0 && current_uv.y >= 0.0
            //     && current_uv.x <= 1.0 && current_uv.y <= 1.0) {
            //     hits ++;
            // }

            // Pad hitbox to reduce "stripes" artifact when surface is almost perpendicular to camera
            hitbox_mult = 1.0 + 3.0 * (1.0 - dot(vec3(0.0, 0.0, 1.0), reflectedNormal)); // dot is unclamped intentionally

            if (delta_z < hitbox_z * hitbox_mult) {
                //refine
                vec2 prev_uv = current_uv;
                float prev_delta_z = delta_z;
                float refine_ray_length = 0.0625;
                ray = unit_march * refine_ray_length;
                // 0.01 is the delta_z at which no more detail will be achieved even for very nearby reflection
                // PERF: adapt based on initial z
                while (refine_steps < REFINE && abs(delta_z) > 0.01) {
                    if (abs(delta_z) < refine_ray_length) {
                        refine_ray_length = abs(delta_z);
                        ray = unit_march * refine_ray_length;
                    }
                    ray_view -= ray;
                    current_uv = view2uv(ray_view, projection);
                    current_view = uv2view(current_uv, inv_projection, reflected_depth);
                    delta_z = current_view.z - ray_view.z;
                    // Ensure delta_z never exceeds the amount we started with
                    if (abs(delta_z) > abs(prev_delta_z)) break;
                    prev_uv = current_uv;
                    prev_delta_z = delta_z;
                    refine_steps ++;
                }
                return rt_Result(prev_uv, true, hits);
            }
        }
        if (mod(steps, PERIOD) == 0) {
            ray *= 2.0;
            hitbox_z *= 2.0;
        }
        steps ++;
    }
    return rt_Result(current_uv, false, hits);
}
#endif
