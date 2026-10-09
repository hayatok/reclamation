shader_type spatial;
render_mode diffuse_burley, specular_disabled;

// Vertex RGB and UV2 interior mask are static baked data, no animation or light.
uniform sampler2D fibre_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float alarm : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = COLOR.rgb * texture(fibre_texture, UV).rgb;
	ROUGHNESS = 0.98;
	EMISSION = vec3(0.55, 0.08, 0.008) * UV2.x * alarm;
}
