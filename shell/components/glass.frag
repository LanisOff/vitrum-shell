#version 440
// Liquid glass drawn in the scene (Glass.qml): the backdrop seen through a
// body. `heightMap` is the body blurred, so it climbs from 0 at the edge to 1
// inside; its slope is the glass's normal. Near the rim the backdrop bends
// outward (a convex lens shows what lies beyond its edge), splits a little by
// colour, and catches light from the top left.
// Build: tools/build-shaders (qsb), the .qsb next to this file is what loads.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 bgRect;      // this effect in the backdrop's texture coordinates (x, y, w, h)
    vec2 px;          // one pixel of this effect in its texture coordinates
    float refraction; // pixels the rim bends the backdrop by
    float fringing;   // 0..1, how far red and blue part at the rim
    float edgeLight;  // rim highlight
    float saturation;
    float brightness;
    vec4 tint;        // premultiplied colour over the backdrop
};
layout(binding = 1) uniform sampler2D backdrop;
layout(binding = 2) uniform sampler2D body;
layout(binding = 3) uniform sampler2D heightMap;

vec3 saturate3(vec3 c, float s) {
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    return mix(vec3(l), c, s);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float a = texture(body, uv).a;
    if (a < 0.002) {
        fragColor = vec4(0.0);
        return;
    }
    float h = texture(heightMap, uv).a;
    vec2 d = px * 1.5;
    vec2 g = vec2(texture(heightMap, uv + vec2(d.x, 0.0)).a - texture(heightMap, uv - vec2(d.x, 0.0)).a,
                  texture(heightMap, uv + vec2(0.0, d.y)).a - texture(heightMap, uv - vec2(0.0, d.y)).a);
    float gl = length(g);
    vec2 n = gl > 1e-5 ? g / gl : vec2(0.0);          // inward, uphill
    float rim = clamp(1.0 - h, 0.0, 1.0);
    rim *= rim;

    vec2 bg = bgRect.xy + uv * bgRect.zw;
    vec2 o = -n * refraction * rim * px * bgRect.zw;   // outward, in backdrop coordinates
    vec3 c;
    c.r = texture(backdrop, bg + o * (1.0 + fringing)).r;
    c.g = texture(backdrop, bg + o).g;
    c.b = texture(backdrop, bg + o * (1.0 - fringing)).b;
    c = saturate3(c, saturation) + brightness;
    c = c * (1.0 - tint.a) + tint.rgb;

    // The rim facing the light shines, with a bright line at the very edge;
    // the far rim catches a little and sits in a touch of shade.
    float facing = dot(-n, normalize(vec2(-0.6, -0.8)));
    float lit = max(facing, 0.0) + 0.3 * max(-facing, 0.0);
    c *= 1.0 - 0.18 * rim * max(-facing, 0.0);
    c += edgeLight * lit * (0.5 * rim + 0.9 * pow(rim, 4.0));

    fragColor = vec4(c, 1.0) * a * qt_Opacity;
}
