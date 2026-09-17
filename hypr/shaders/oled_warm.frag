#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;

out vec4 fragColor;

// --- tweakables (balanced preset) ---
const vec3  WARMTH_RGB   = vec3(1.0, 0.757, 0.518); // 3400K blackbody, industry-standard warm point
const float WARMTH_MIX   = 0.35;  // lighter blend -- noticeably warmer, still color-accurate

const float CONTRAST     = 1.08;  // subtle punch, not crushing
const float BLACK_LIFT   = 1.0;   // no shadow darkening -- OLED feel comes from contrast, not crushed blacks
const float SATURATION   = 1.06;  // small boost to keep colors vivid under the warm shift

vec3 adjustSaturation(vec3 color, float sat) {
    float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
    return mix(vec3(gray), color, sat);
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);

    vec3 color = (pixColor.rgb - 0.5) * CONTRAST + 0.5;
    color *= BLACK_LIFT;
    color *= mix(vec3(1.0), WARMTH_RGB, WARMTH_MIX);
    color = adjustSaturation(color, SATURATION);

    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, pixColor.a);
}
