shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Horizontal district pavement needs one world-XZ sample, not three triplanar
// samples. Buildings retain their established three-axis material mapping.
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float world_scale = 0.36;
varying vec2 pavement_uv;
void vertex() {
 pavement_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * world_scale;
}
void fragment() {
 ALBEDO = base_color.rgb * texture(surface_albedo, pavement_uv).rgb * COLOR.rgb;
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
}
