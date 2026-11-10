shader_type spatial;
// Sol quadrillé en coordonnées monde : repère visuel de vitesse et de distance (1 m / 5 m).

uniform vec3 base_color : source_color = vec3(0.20, 0.21, 0.23);
uniform vec3 line_color : source_color = vec3(0.30, 0.32, 0.35);
uniform vec3 major_line_color : source_color = vec3(0.45, 0.48, 0.52);
uniform float cell_size = 1.0;
uniform float major_every = 5.0;
uniform float line_width = 0.025;

varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_mask(vec2 p, float size, float width) {
    vec2 distance_to_line = abs(fract(p / size - 0.5) - 0.5) * size;
    vec2 aa = fwidth(p);
    vec2 lines = 1.0 - smoothstep(vec2(width) - aa, vec2(width) + aa, distance_to_line);
    return max(lines.x, lines.y);
}

void fragment() {
    vec2 p = world_position.xz;
    float minor = grid_mask(p, cell_size, line_width);
    float major = grid_mask(p, cell_size * major_every, line_width * 1.6);
    vec3 color = mix(base_color, line_color, minor);
    color = mix(color, major_line_color, major);
    ALBEDO = color;
    ROUGHNESS = 0.9;
}
