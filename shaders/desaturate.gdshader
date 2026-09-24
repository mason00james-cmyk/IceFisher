shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.5) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(gray), c.rgb, saturation), c.a);
}