// OLED-like Vibrance + Warm Shader (GLES 3.00, Stable, Fixed)
#version 300 es
precision highp float;

uniform sampler2D tex;
in vec2 v_texcoord;
out vec4 fragColor;

void main() {
    vec4 texColor = texture(tex, v_texcoord);

    // Preserve original alpha
    float alpha = texColor.a;
    if (alpha <= 0.0) {
        fragColor = texColor;
        return;
    }

    vec3 color = texColor.rgb;

    // --- OLED-like tuning ---
    float vibrance   = 0.20; // gentler than before
    float saturation = 1.08; // slightly boosted
    float contrast   = 1.03; // deeper blacks, brighter lights
    float brightness = 1.00; // keep neutral

    // Perceived luma
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // Vibrance (gentle)
    vec3 diff = color - vec3(luma);
    color += diff * vibrance;

    // Saturation
    color = mix(vec3(luma), color, saturation);

    // Contrast (curved for OLED feel)
    color = (color - 0.5) * contrast + 0.5;

    // Gamma adjustment for richer depth (≈ OLED tone curve)
    color = pow(color, vec3(0.95));

    // Warm tweak (subtle)
    color.r *= 1.04;
    color.b *= 0.90;

    // Clamp to avoid clipping artifacts
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, alpha);
}
