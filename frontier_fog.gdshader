shader_type spatial;
// Final world-only blend. No screen-color copy, shadow pass, mipmaps or compute.
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D visibility_mask : repeat_disable, filter_nearest;
uniform vec2 map_origin = vec2(-96.0, -80.0);
uniform vec2 map_size = vec2(192.0, 160.0);
uniform vec2 mask_world_size = vec2(192.0, 160.0);
uniform vec3 fog_color : source_color = vec3(0.048, 0.072, 0.079);
uniform float memory_opacity : hint_range(0.0, 1.0) = 0.72;

void vertex() {
	// Godot 4.3+ reverse Z. Also prevents geometry-height leaks through a ground plane.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 world_position = world.xyz / world.w;
	vec2 local = world_position.xz - map_origin;
	float inside = step(0.0, local.x) * step(0.0, local.y)
		* step(local.x, map_size.x) * step(local.y, map_size.y);
	vec2 mask = textureLod(visibility_mask, local / mask_world_size, 0.0).rg * inside;
	float explored = step(0.5, mask.r);
	float visible_now = step(0.5, mask.g);
	ALBEDO = fog_color;
	ALPHA = (1.0 - visible_now) * mix(1.0, memory_opacity, explored);
}
