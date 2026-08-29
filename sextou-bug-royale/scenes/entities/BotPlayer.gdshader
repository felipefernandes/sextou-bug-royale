shader_type canvas_item;

uniform vec4 key_color : source_color = vec4(1.0, 0.0, 1.0, 1.0); // Magenta puro (#FF00FF)
uniform float tolerance : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// Calcula a distância entre a cor do pixel e a cor chave
	float diff = distance(tex.rgb, key_color.rgb);
	
	// Descarta o pixel se estiver dentro da tolerância
	if (diff < tolerance) {
		discard;
	}
	
	COLOR = tex;
}