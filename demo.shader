shader_type canvas_item;
render_mode blend_mix;

uniform vec2 screen_size;

uniform sampler2D fg_tex ;

void fragment() {
	COLOR = vec4( texture( fg_tex, UV).rgb , COLOR.a );
}