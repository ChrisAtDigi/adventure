// Full-screen cartoon ink lines, drawn where depth or surface direction changes sharply.
// Used on a quad parented to each room's camera (see Room._add_outline).
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec4 line_color : source_color = vec4(0.03, 0.02, 0.05, 1.0);
uniform float thickness = 1.3;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 p = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -p.z / p.w;
}

vec3 view_normal(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	vec2 dx = vec2(px.x, 0.0);
	vec2 dy = vec2(0.0, px.y);

	float c = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float l = view_depth(SCREEN_UV - dx, INV_PROJECTION_MATRIX);
	float r = view_depth(SCREEN_UV + dx, INV_PROJECTION_MATRIX);
	float u = view_depth(SCREEN_UV - dy, INV_PROJECTION_MATRIX);
	float d = view_depth(SCREEN_UV + dy, INV_PROJECTION_MATRIX);
	float nearest = min(c, min(min(l, r), min(u, d)));
	float bend = abs(l + r - 2.0 * c) + abs(u + d - 2.0 * c);
	float depth_edge = smoothstep(0.02, 0.05, bend / nearest);

	vec3 n = view_normal(SCREEN_UV);
	float turn = 0.0;
	turn += 1.0 - dot(n, view_normal(SCREEN_UV - dx));
	turn += 1.0 - dot(n, view_normal(SCREEN_UV + dx));
	turn += 1.0 - dot(n, view_normal(SCREEN_UV - dy));
	turn += 1.0 - dot(n, view_normal(SCREEN_UV + dy));
	float normal_edge = smoothstep(0.35, 0.8, turn);

	ALBEDO = line_color.rgb;
	ALPHA = max(depth_edge, normal_edge) * line_color.a;
}
