shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Shared once per LOD/material. COLOR includes MultiMesh instance tint.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float specular_value : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	float weight = clamp(INSTANCE_CUSTOM.x, 0.0, 1.0);
	// CUSTOM0/1 are the next pose paired by stable UV2 corner ID at startup.
	VERTEX = mix(VERTEX, CUSTOM0.xyz, weight);
	vec3 blended_normal = mix(NORMAL, CUSTOM1.xyz, weight);
	float normal_length = length(blended_normal);
	NORMAL = normal_length > 0.00001 ? blended_normal / normal_length : NORMAL;
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * albedo_color.rgb * COLOR.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	SPECULAR = specular_value;
	// Deliberately no ALPHA assignment: these batches remain opaque.
}
