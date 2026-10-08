// Home crystal bridge plank (UI v2): pale ice crystal with inner facets, a frosted top, a
// soft cyan glow along the plank seams and a fresnel sheen; opaque (cheap, no sorting).
// Used on a MultiMesh of box planks; `half` is the plank's half size.
shader_type spatial;
render_mode cull_back;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 body : source_color = vec4(0.74, 0.89, 0.98, 1.0);
uniform vec4 deep : source_color = vec4(0.45, 0.72, 0.9, 1.0);
uniform vec4 edge : source_color = vec4(0.56, 0.85, 0.94, 1.0);
uniform vec3 half = vec3(1.3, 0.09, 0.58);
uniform float seam_glow = 0.35;

varying vec3 lp;
varying vec3 wp;
varying float up;

void vertex() {
	lp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = NORMAL.y;
}

void fragment() {
	vec3 u = lp / half;
	// Distance to the plank's border on the top face (0 at the edge).
	float bx = 1.0 - abs(u.x);
	float bz = 1.0 - abs(u.z);
	float b = min(bx * half.x, bz * half.z);
	float n1 = texture(noise_tex, wp.xz * 0.35).r;
	float n2 = texture(noise_tex, wp.xz * 1.3 + vec2(n1 * 0.3, 0.0)).r;
	// Faceted interior: quantised noise bands read as crystal planes.
	float facet = floor((n1 * 0.6 + n2 * 0.4) * 6.0) / 6.0;
	vec3 col = mix(deep.rgb, body.rgb, 0.55 + facet * 0.45);
	float top = step(0.5, up);
	// Bevel light along the top border.
	float bevel = 1.0 - smoothstep(0.0, 0.06, b);
	col = mix(col, vec3(0.95, 0.99, 1.0), bevel * 0.45);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	col = mix(col, vec3(1.0, 0.99, 0.97), fres * 0.4);
	ALBEDO = col;
	ROUGHNESS = 0.18;
	SPECULAR = 0.75;
	METALLIC = 0.05;
	float seam = (1.0 - smoothstep(0.0, 0.05, bz * half.z)) * top;
	EMISSION = edge.rgb * (seam * seam_glow + 0.06) + deep.rgb * (1.0 - top) * 0.12;
}
