shader_type canvas_item;
// Soft glowing outline for the selected farm object.
uniform vec4 outline_color : source_color = vec4(1.0, 0.92, 0.35, 1.0);
uniform float width = 6.0;
uniform float pulse = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
	}
	vec4 o = vec4(outline_color.rgb, outline_color.a * a * pulse);
	COLOR = mix(o, c, c.a);
}
