extends RefCounted
## Shader sources + cached shared materials/textures. All original, procedural.

static var _shaders := {}
static var _mats := {}
static var _tex := {}
## World-shader materials that fade when they occlude the focus (driven by Art._process).
static var occluder_mats: Array = []

# Shared toon ramp: two soft bands, painterly feel. Rim light is added in fragment as emission.
const TOON_LIGHT := """
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(-0.15, 0.12, ndl) * 0.62 + smoothstep(0.35, 0.62, ndl) * 0.38;
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
"""

const UNIT := """
shader_type spatial;
render_mode cull_back, specular_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float glow_strength = 1.5;
uniform float glow_boost = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.82, 0.6, 1.0);
uniform float rim_strength = 0.45;
uniform float rim_pow = 2.6;
uniform float dissolve = 0.0;
uniform float ao_height = 1.8;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
void fragment() {
	float n = texture(noise_tex, UV2 * 0.45).r;
	float n2 = texture(noise_tex, UV2 * 1.9 + vec2(0.37, 0.11)).r;
	vec3 base = COLOR.rgb;
	base *= 0.78 + 0.44 * n;
	base = mix(base, base * vec3(1.08, 0.97, 0.88), n2 * 0.35);
	float ao = mix(0.5, 1.0, clamp(UV2.y / (ao_height * 0.55), 0.0, 1.0)) * UV.y;
	base *= ao;
	base *= tint.rgb;
	ALBEDO = mix(base, flash.rgb, flash.a * 0.65);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_pow);
	vec3 em = COLOR.rgb * UV.x * (glow_strength + glow_boost * 2.5) * (0.8 + 0.4 * n);
	em += rim_color.rgb * fres * rim_strength * (0.6 + 0.4 * ao);
	em += glow_color.rgb * glow_boost * fres * 1.5;
	em += flash.rgb * flash.a * 0.9;
	if (dissolve > 0.001) {
		float dn = n2 * 0.8 + n * 0.2;
		if (dn < dissolve) { discard; }
		em += glow_color.rgb * (1.0 - smoothstep(0.0, 0.09, dn - dissolve)) * 5.0;
	}
	EMISSION = em;
}
""" + TOON_LIGHT

# Translucent parts (wings) and ghosts (afterimage)
const UNIT_GHOST := """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 glow_color : source_color = vec4(0.3, 1.0, 0.9, 1.0);
uniform float glow_strength = 1.0;
uniform float glow_boost = 0.0;
uniform float dissolve = 0.0;
uniform float alpha = 0.55;
uniform float ao_height = 1.8;
uniform float use_vcol = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
void fragment() {
	float n = texture(noise_tex, UV2 * 0.9 + vec2(TIME * 0.05, -TIME * 0.11)).r;
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.6);
	vec3 c = mix(glow_color.rgb, COLOR.rgb * glow_color.rgb * 1.6, use_vcol) * tint.rgb;
	float a = alpha * (0.25 + 0.95 * fres) * (0.7 + 0.5 * n) * (1.0 - dissolve);
	a *= 0.75 + 0.25 * sin(TIME * 7.0 + UV2.y * 9.0);
	ALBEDO = c * a * (glow_strength + glow_boost) + flash.rgb * flash.a * 0.5;
}
"""

# Static world geometry: vertex colors + triplanar painterly noise + optional bricks + fake torch light.
const WORLD := """
shader_type spatial;
render_mode cull_back, specular_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float brick_h = 0.55;
uniform float brick_w = 1.15;
uniform float glow_strength = 2.0;
uniform vec4 lights[12];
uniform vec3 light_col = vec3(1.0, 0.55, 0.22);
uniform vec4 rim_color : source_color = vec4(0.45, 0.55, 0.9, 1.0);
uniform float rim_strength = 0.12;
uniform float flicker = 1.0;
// occluder fade: screen-door dither inside a capsule from the camera (occ_a) to the focus (occ_b)
uniform vec3 occ_a = vec3(0.0);
uniform vec3 occ_b = vec3(0.0);
uniform float occ_r = 2.1;
uniform float occ_on = 0.0;
varying vec3 wp;
varying vec3 wn;
float bayer4(vec2 fc) {
	ivec2 i = ivec2(mod(fc, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i.x + i.y * 4] + 0.5) / 16.0;
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float tri_noise(float s) {
	vec3 b = pow(abs(wn), vec3(4.0));
	b /= (b.x + b.y + b.z);
	return texture(noise_tex, wp.zy * s).r * b.x + texture(noise_tex, wp.xz * s).r * b.y + texture(noise_tex, wp.xy * s).r * b.z;
}
void fragment() {
	float occ_k = 0.0;
	if (occ_on > 0.5) {
		vec3 ab = occ_b - occ_a;
		float t = clamp(dot(wp - occ_a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
		float d = length(wp - (occ_a + ab * t));
		occ_k = (1.0 - smoothstep(occ_r * 0.55, occ_r, d)) * (1.0 - smoothstep(0.9, 0.97, t)) * smoothstep(0.2, 0.8, wp.y);
		if (occ_k * 0.88 > bayer4(FRAGCOORD.xy)) { discard; }
	}
	float n = tri_noise(0.18);
	float n2 = tri_noise(0.9);
	vec3 base = COLOR.rgb * (0.74 + 0.5 * n);
	base = mix(base, base * vec3(0.9, 0.95, 1.12), smoothstep(0.55, 0.8, n2) * 0.5);
	// bricks (UV.y = mask, UV2 = brick coords in meters)
	if (UV.y > 0.01) {
		float row = UV2.y / brick_h;
		float rf = fract(row);
		float off = mod(floor(row), 2.0) * 0.5;
		float cf = fract(UV2.x / brick_w + off);
		float e = min(min(rf, 1.0 - rf) * brick_h, min(cf, 1.0 - cf) * brick_w);
		float mortar = 1.0 - smoothstep(0.018, 0.045 + n2 * 0.03, e);
		float h = fract(sin(dot(floor(vec2(UV2.x / brick_w + off, row)), vec2(12.9898, 78.233))) * 43758.5453);
		vec3 bc = base * (0.72 + 0.42 * h) * mix(vec3(1.0), vec3(1.08, 0.98, 0.9), step(0.6, fract(h * 7.3)));
		bc *= mix(0.78, 1.0, smoothstep(0.0, 0.14, e));
		base = mix(base, mix(bc, base * 0.32, mortar), UV.y);
	}
	ALBEDO = base;
	vec3 add = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		vec4 L = lights[i];
		if (L.w <= 0.0) { continue; }
		vec3 lp = vec3(L.x, 2.4, L.y);
		vec3 d = lp - wp;
		float dist = length(d);
		float f = clamp(1.0 - dist / L.z, 0.0, 1.0);
		float facing = clamp(dot(wn, d / max(dist, 0.001)) * 0.7 + 0.3, 0.0, 1.0);
		add += light_col * L.w * f * f * facing;
	}
	float fl = 0.88 + 0.12 * sin(TIME * 9.0 + wp.x) * flicker;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = base * add * fl + COLOR.rgb * UV.x * glow_strength * (0.75 + 0.5 * n2) + rim_color.rgb * fres * rim_strength;
	// faint ember edge on the dithered part so the cut-away still reads as solid stone
	EMISSION += vec3(1.0, 0.45, 0.15) * occ_k * 0.12;
}
""" + TOON_LIGHT

const FLOOR := """
shader_type spatial;
render_mode cull_back, specular_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 stone_a : source_color = vec4(0.30, 0.29, 0.30, 1.0);
uniform vec4 stone_b : source_color = vec4(0.40, 0.37, 0.34, 1.0);
uniform vec4 sand : source_color = vec4(0.48, 0.38, 0.26, 1.0);
uniform vec4 mortar_c : source_color = vec4(0.12, 0.10, 0.10, 1.0);
uniform vec4 ember : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform vec4 lights[12];
uniform vec3 light_col = vec3(1.0, 0.55, 0.22);
uniform vec4 pillars[3];
uniform vec3 sun_dir = vec3(0.45, 0.0, -0.6);
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	float r = length(p);
	if (r > 24.4) { discard; }
	float ang = atan(p.y, p.x);
	float n = texture(noise_tex, p * 0.03).r;
	float n2 = texture(noise_tex, p * 0.19).r;
	float n3 = texture(noise_tex, p * 0.85).r;
	vec3 col;
	float emis = 0.0;
	float edge;
	float tile_h;
	if (r < 4.2) {
		// central medallion: six wedges around an ember grate (the pit)
		float wedges = 6.0;
		float a01 = (ang + 3.14159) / 6.28318 * wedges;
		float wf = fract(a01);
		float we = min(wf, 1.0 - wf) * r * 6.28318 / wedges;
		float re = min(abs(r - 1.25), abs(r - 4.2));
		edge = min(we, re);
		tile_h = hash(vec2(floor(a01), r < 1.25 ? 1.0 : 2.0));
		col = mix(stone_a.rgb * 0.8, stone_b.rgb * 0.95, tile_h);
		// decorative inset brass band (static, unlit, no ticks) so it never reads as a telegraph
		float inlay = (1.0 - smoothstep(0.035, 0.075, abs(r - 3.55))) + (1.0 - smoothstep(0.02, 0.045, abs(r - 3.25))) * 0.55;
		col = mix(col, vec3(0.36, 0.30, 0.22) * (0.85 + 0.3 * n3), clamp(inlay, 0.0, 1.0) * 0.75);
		if (r < 1.25) {
			// grate with glowing embers below
			vec2 g = fract(p * 2.4);
			float bars = 1.0 - step(0.18, min(g.x, g.y));
			float glow = smoothstep(0.35, 0.8, texture(noise_tex, p * 0.9 + vec2(TIME * 0.05, TIME * 0.03)).r) * (1.0 - r / 1.25);
			col = mix(vec3(0.05, 0.03, 0.02), vec3(0.18, 0.16, 0.15), bars);
			emis += (1.0 - bars) * (0.6 + 2.5 * glow);
			edge = 1.0;
		}
	} else {
		float rr = r - 4.2;
		float ring_w = 1.75;
		float ri = floor(rr / ring_w);
		float rf = fract(rr / ring_w);
		float mid_r = 4.2 + (ri + 0.5) * ring_w;
		float segs = floor(6.28318 * mid_r / 1.9);
		float a01 = (ang + 3.14159) / 6.28318;
		float sa = a01 * segs + hash(vec2(ri, 3.1)) * 3.0;
		float si = floor(sa);
		float sf = fract(sa);
		edge = min(min(rf, 1.0 - rf) * ring_w, min(sf, 1.0 - sf) * 6.28318 * mid_r / segs);
		tile_h = hash(vec2(ri, mod(si, segs)));
		col = mix(stone_a.rgb, stone_b.rgb, tile_h);
		col *= 0.92 + 0.16 * hash(vec2(si, ri + 7.0));
		// broken / missing tiles
		if (hash(vec2(si * 1.3, ri * 2.1)) > 0.93) {
			col = sand.rgb * 0.75;
			edge = 1.0;
		}
	}
	col *= 0.8 + 0.34 * n2;
	col *= mix(0.72, 1.0, smoothstep(0.0, 0.22, edge));
	float mortar = 1.0 - smoothstep(0.03, 0.075 + n3 * 0.04, edge);
	col = mix(col, mortar_c.rgb, mortar);
	// cracks
	float crack = 1.0 - smoothstep(0.0, 0.012, abs(texture(noise_tex, p * 0.09 + vec2(4.0)).r - 0.5));
	float cmask = smoothstep(0.5, 0.62, texture(noise_tex, p * 0.045 + vec2(1.7, 3.3)).r);
	col *= 1.0 - crack * cmask * 0.45 * step(4.2, r);
	// sand drifts (more towards the wall and in patches)
	float sm = smoothstep(0.64, 0.82, n * 0.85 + n2 * 0.25 + smoothstep(15.0, 22.0, r) * 0.32 - 0.1);
	vec3 sandc = sand.rgb * (0.82 + 0.3 * n3);
	col = mix(col, sandc, sm * (r > 1.3 ? 1.0 : 0.0));
	// dark stains
	col *= 1.0 - smoothstep(0.62, 0.8, texture(noise_tex, p * 0.07 + vec2(9.0, 2.0)).r) * 0.35;
	// wall AO + pillar AO + fake cast shadows
	col *= mix(1.0, 0.42, smoothstep(19.8, 22.0, r));
	for (int i = 0; i < 3; i++) {
		vec2 pc = pillars[i].xy;
		float pr = pillars[i].z;
		float d = length(p - pc);
		col *= mix(0.55, 1.0, smoothstep(pr, pr + 1.4, d));
		vec2 sp = pc + normalize(sun_dir.xz) * 2.6;
		vec2 q = p - pc;
		vec2 sd = normalize(sun_dir.xz);
		float along = dot(q, sd);
		float side = abs(q.x * sd.y - q.y * sd.x);
		float sh = step(0.0, along) * (1.0 - smoothstep(pr * 0.85, pr * 1.25, side)) * (1.0 - smoothstep(4.0, 9.0, along));
		col *= 1.0 - sh * 0.38;
	}
	ALBEDO = col;
	vec3 add = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		vec4 L = lights[i];
		if (L.w <= 0.0) { continue; }
		float d = length(p - L.xy);
		float f = clamp(1.0 - d / L.z, 0.0, 1.0);
		add += light_col * L.w * f * f;
	}
	float fl = 0.9 + 0.1 * sin(TIME * 8.0 + p.x * 0.3);
	EMISSION = col * add * fl + ember.rgb * emis * 1.6;
}
""" + TOON_LIGHT

const GRASS := """
shader_type spatial;
render_mode cull_back, specular_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 grass_a : source_color = vec4(0.2, 0.34, 0.15, 1.0);
uniform vec4 grass_b : source_color = vec4(0.38, 0.48, 0.2, 1.0);
uniform vec4 dirt : source_color = vec4(0.45, 0.33, 0.2, 1.0);
uniform vec2 center = vec2(0.0, 40.0);
uniform vec4 lights[12];
uniform vec3 light_col = vec3(1.0, 0.6, 0.3);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	vec2 q = p - center;
	float r = length(q);
	if (r > 10.2) { discard; }
	float n = texture(noise_tex, p * 0.05).r;
	float n2 = texture(noise_tex, p * 0.35).r;
	float n3 = texture(noise_tex, p * 1.7).r;
	vec3 col = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.3, 0.75, n * 0.7 + n2 * 0.5));
	col *= 0.82 + 0.3 * n3;
	// dirt paths: ring + spokes to shop, fountain, spawn pad
	float ring = abs(r - 4.6);
	float path = 1.0 - smoothstep(0.7, 1.3 + n2 * 0.5, ring);
	vec2 targets[3] = vec2[3](vec2(-4.0, 2.0), vec2(4.0, 2.0), vec2(0.0, -3.0));
	for (int i = 0; i < 3; i++) {
		vec2 t = targets[i];
		float h = clamp(dot(q, t) / dot(t, t), 0.0, 1.0);
		float d = length(q - t * h);
		path = max(path, 1.0 - smoothstep(0.6, 1.1 + n2 * 0.4, d));
	}
	path = max(path, 1.0 - smoothstep(1.4, 2.2 + n2, length(q - vec2(0.0, -3.0))));
	vec3 dc = dirt.rgb * (0.8 + 0.4 * n3);
	col = mix(col, dc, path);
	// small flowers
	float fl = step(0.86, texture(noise_tex, p * 2.3).r) * (1.0 - path);
	col = mix(col, vec3(0.95, 0.85, 0.45), fl * 0.7);
	col *= mix(0.55, 1.0, smoothstep(10.2, 8.8, r));
	ALBEDO = col;
	vec3 add = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		vec4 L = lights[i];
		if (L.w <= 0.0) { continue; }
		float d = length(p - L.xy);
		float f = clamp(1.0 - d / L.z, 0.0, 1.0);
		add += light_col * L.w * f * f;
	}
	EMISSION = col * add;
}
""" + TOON_LIGHT

const WATER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled, unshaded;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 deep : source_color = vec4(0.05, 0.28, 0.42, 1.0);
uniform vec4 shallow : source_color = vec4(0.2, 0.75, 0.85, 1.0);
uniform float falling = 0.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	float t = TIME;
	float n;
	if (falling > 0.5) {
		n = texture(noise_tex, vec2(UV.x * 3.0, UV.y * 0.8 - t * 1.4)).r;
	} else {
		float a = texture(noise_tex, p * 0.6 + vec2(t * 0.05, t * 0.03)).r;
		float b = texture(noise_tex, p * 0.9 - vec2(t * 0.04, -t * 0.06)).r;
		n = a * 0.5 + b * 0.5;
	}
	float caust = smoothstep(0.55, 0.62, n) - smoothstep(0.62, 0.72, n);
	vec3 c = mix(deep.rgb, shallow.rgb, smoothstep(0.3, 0.7, n));
	c += vec3(0.7, 1.0, 1.0) * caust * 0.9;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	c += vec3(0.4, 0.6, 0.8) * fres * 0.4;
	ALBEDO = c * 1.25;
}
"""

const FLAME := """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 col_hot : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform vec4 col_cool : source_color = vec4(1.0, 0.32, 0.06, 1.0);
uniform float intensity = 1.9;
uniform vec3 occ_a = vec3(0.0);
uniform vec3 occ_b = vec3(0.0);
uniform float occ_r = 2.1;
uniform float occ_on = 0.0;
varying float seed;
varying float occ_fade;
void vertex() {
	seed = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 3.1;
	// cylindrical billboard (rotate around Y towards camera)
	vec3 cam = (INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
	vec3 fwd = normalize(vec3(cam.x, 0.0, cam.z));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 wpos = MODEL_MATRIX[3].xyz + right * VERTEX.x * sx + vec3(0.0, 1.0, 0.0) * VERTEX.y * sy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wpos, 1.0);
	occ_fade = 1.0;
	if (occ_on > 0.5) {
		vec3 base = MODEL_MATRIX[3].xyz;
		vec3 ab = occ_b - occ_a;
		float t = clamp(dot(base - occ_a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
		float d = length(base - (occ_a + ab * t));
		occ_fade = 1.0 - 0.8 * (1.0 - smoothstep(occ_r * 0.6, occ_r * 1.2, d)) * (1.0 - smoothstep(0.9, 0.97, t));
	}
}
void fragment() {
	vec2 uv = UV;
	float t = TIME * 1.6 + seed;
	float n = texture(noise_tex, vec2(uv.x * 0.8 + seed, uv.y * 0.9 + t)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 1.7 - seed, uv.y * 1.3 + t * 1.6)).r;
	float x = (uv.x - 0.5) * 2.0;
	float y = 1.0 - uv.y; // 0 bottom, 1 top
	float w = (1.0 - y) * 0.9 + 0.1;
	float shape = 1.0 - smoothstep(w * 0.55, w * 0.95, abs(x + (n - 0.5) * 0.5 * y));
	shape *= smoothstep(0.0, 0.12, y) * (1.0 - smoothstep(0.45 + n2 * 0.4, 1.0, y));
	float core = shape * (1.0 - smoothstep(0.0, 0.6, y)) * (1.0 - smoothstep(0.0, 0.5, abs(x)));
	vec3 c = mix(col_cool.rgb, col_hot.rgb, core);
	ALBEDO = c * shape * intensity * occ_fade;
}
"""

# Ground decals: telegraphs, aim indicators, pools, rune rings, shockwaves, scorch cracks.
const DECAL := """
shader_type spatial;
render_mode BLEND_MODE, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 color : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform vec4 color2 : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform int mode = 0;
uniform float fill = 0.0;
uniform float alpha = 1.0;
uniform float intensity = 1.0;
uniform vec2 size = vec2(2.0, 2.0);
uniform float edge_w = 0.14;
uniform float seed = 0.0;
uniform float arc = 0.8;
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	float ang = atan(uv.y, uv.x);
	float t = TIME;
	float a = 0.0;
	vec3 c = color.rgb;
	float r_world = size.x * 0.5;
	float ew = edge_w / max(r_world, 0.01);
	if (mode == 0) { // telegraph circle
		if (d > 1.0) { discard; }
		float ring = smoothstep(1.0 - ew, 1.0 - ew * 0.4, d) * (1.0 - smoothstep(0.985, 1.0, d));
		float inner = 0.16 + 0.06 * sin(t * 10.0);
		float f = step(d, fill) * 0.32;
		float fe = (1.0 - smoothstep(0.0, ew * 1.2, abs(d - fill))) * step(0.02, fill);
		float stripes = step(0.5, fract((uv.x + uv.y) * r_world * 0.9 - t * 1.5)) * 0.06;
		a = max(max(ring * 0.95, inner + f + stripes), fe * 0.9);
		c = mix(color.rgb, color2.rgb, max(ring, fe));
	} else if (mode == 1) { // telegraph line (uv.x across -1..1, UV.y along 0..1 from start)
		float along = UV.y;
		float ex = edge_w / max(size.x * 0.5, 0.01);
		float ey = edge_w / max(size.y, 0.01);
		float border = max(smoothstep(1.0 - ex, 1.0, abs(uv.x)), max(1.0 - smoothstep(0.0, ey, along), smoothstep(1.0 - ey, 1.0, along)));
		float f = step(along, fill) * 0.32;
		float fe = (1.0 - smoothstep(0.0, ey * 1.5, abs(along - fill))) * step(0.02, fill);
		float chev = step(0.75, fract(along * size.y * 0.5 - abs(uv.x) * 0.3 - t * 1.2)) * 0.12;
		a = max(max(border * 0.95, 0.15 + f + chev), fe * 0.9);
		c = mix(color.rgb, color2.rgb, max(border, fe));
	} else if (mode == 2) { // aim circle
		if (d > 1.0) { discard; }
		float ring = smoothstep(1.0 - ew, 1.0 - ew * 0.5, d) * (1.0 - smoothstep(0.98, 1.0, d));
		float dash = step(0.35, fract(ang / 6.28318 * 24.0 + t * 0.6));
		a = ring * (0.5 + 0.5 * dash) + 0.1 + 0.08 * smoothstep(0.4, 1.0, d);
	} else if (mode == 3) { // aim line / arrow
		float along = UV.y;
		float head = smoothstep(0.82, 0.84, along);
		float half_w = mix(1.0, 1.0 - (along - 0.84) / 0.16, head);
		if (abs(uv.x) > half_w * (head > 0.5 ? 1.0 : 0.55)) { discard; }
		float ex = edge_w / max(size.x * 0.5, 0.01);
		float border = smoothstep(half_w * (head > 0.5 ? 1.0 : 0.55) - ex, half_w * (head > 0.5 ? 1.0 : 0.55), abs(uv.x));
		float flow = step(0.6, fract(along * size.y * 0.6 - t * 2.0)) * 0.12;
		a = border * 0.85 + 0.14 + flow + head * 0.18;
	} else if (mode == 4) { // pool (bubbling)
		float wob = texture(noise_tex, vec2(ang * 0.4 + seed, t * 0.05) ).r;
		float edge = 0.78 + 0.2 * wob;
		if (d > edge) { discard; }
		float n = texture(noise_tex, uv * 0.8 + vec2(t * 0.04, -t * 0.03) + seed).r;
		float bub = smoothstep(0.7, 0.74, texture(noise_tex, uv * 1.6 + vec2(seed, t * 0.12)).r);
		c = mix(color.rgb, color2.rgb, n + bub);
		a = 0.82 * (1.0 - smoothstep(edge - 0.08, edge, d)) + 0.0;
		a = max(a, 0.0);
	} else if (mode == 5) { // rune ring
		if (d > 1.0) { discard; }
		float r1 = 1.0 - smoothstep(0.0, ew, abs(d - (1.0 - ew)));
		float r2 = 1.0 - smoothstep(0.0, ew * 0.7, abs(d - 0.68));
		float ra = ang + t * 0.8;
		float ticks = step(0.8, fract(ra / 6.28318 * 18.0)) * step(0.72, d) * step(d, 0.92);
		float spokes = (1.0 - smoothstep(0.0, 0.05, abs(fract(( ang - t * 0.5) / 6.28318 * 6.0) - 0.5) * d)) * step(0.3, d) * step(d, 0.68) * 0.6;
		float glow = (1.0 - d) * 0.25;
		a = max(max(r1, r2), max(ticks, spokes)) + glow;
		c = mix(color.rgb, color2.rgb, r1);
	} else if (mode == 6) { // shockwave ring at radius fill
		if (d > 1.0) { discard; }
		float w = 0.08 + 0.12 * (1.0 - fill);
		a = 1.0 - smoothstep(0.0, w, abs(d - fill));
		a *= 0.9;
		c = mix(color.rgb, color2.rgb, a);
	} else if (mode == 7) { // scorch / cracks
		if (d > 1.0) { discard; }
		float n = texture(noise_tex, vec2(ang * 1.2 + seed, d * 0.6)).r;
		float cr = 1.0 - smoothstep(0.0, 0.05, abs(fract(ang / 6.28318 * 7.0 + n * 0.6) - 0.5) * d);
		cr *= step(0.12, d) * (1.0 - smoothstep(0.6, 1.0, d));
		float scorch = (1.0 - smoothstep(0.0, 0.75, d)) * 0.55;
		c = mix(vec3(0.03, 0.02, 0.02), color2.rgb * 2.0, cr * fill);
		a = max(scorch, cr);
	} else if (mode == 9) { // hero ground ring: crisp outer ring, faint inner disc, 3 small notches
		if (d > 1.0) { discard; }
		float ring = 1.0 - smoothstep(0.0, ew * 0.9, abs(d - (1.0 - ew * 1.6)));
		float inner = (1.0 - smoothstep(0.55, 0.95, d)) * 0.16 + smoothstep(0.55, 0.9, d) * 0.22 * step(d, 1.0 - ew * 2.6);
		float notch = step(0.93, fract(ang / 6.28318 * 3.0 + t * 0.05)) * step(1.0 - ew * 4.0, d) * step(d, 1.0 - ew * 1.6);
		a = max(ring * (0.85 + 0.15 * sin(t * 2.4)), max(inner, notch * 0.9));
		c = mix(color.rgb, color2.rgb, ring * 0.5);
	} else if (mode == 10) { // cone wedge: forward = local -Z, arc = half angle (rad), fill = sweep 0..1
		float s = atan(uv.x, -uv.y);
		if (d > 1.0 || abs(s) > arc) { discard; }
		float sw = mix(-arc, arc, fill);
		float swept = step(s, sw + 0.001);
		float lead = (1.0 - smoothstep(0.0, 0.14, abs(s - sw))) * step(0.02, fill) * (1.0 - step(0.999, fill));
		float rim = smoothstep(0.84, 0.96, d) * (1.0 - smoothstep(0.98, 1.0, d));
		float side = 1.0 - smoothstep(0.0, 0.05 / max(d, 0.08), arc - abs(s));
		float n = texture(noise_tex, vec2(s * 0.9 + seed, d * 1.4 - t * 1.2)).r;
		a = swept * (0.12 + 0.6 * d * d * (0.55 + 0.7 * n) + rim * 0.9 + side * 0.5) + lead * d * 0.9;
		c = mix(color.rgb, color2.rgb, clamp(lead + rim * 0.8, 0.0, 1.0));
	} else if (mode == 11) { // zone: soft glowing disc, crisp rim, slow swirl
		if (d > 1.0) { discard; }
		float rim = 1.0 - smoothstep(0.0, ew, abs(d - (1.0 - ew)));
		float n = texture(noise_tex, vec2(ang * 0.5 + t * 0.04 + seed, d * 0.9 - t * 0.12)).r;
		float body = (0.1 + 0.26 * smoothstep(0.15, 1.0, d)) * (0.55 + 0.9 * n);
		float inner = 1.0 - smoothstep(0.0, ew * 0.6, abs(d - 0.78 - 0.015 * sin(t * 2.0)));
		float ticks = step(0.86, fract(ang / 6.28318 * 12.0 - t * 0.05)) * step(0.82, d) * step(d, 0.9);
		a = max(rim * 0.95, body + inner * 0.3 + ticks * 0.35);
		c = mix(color.rgb, color2.rgb, max(rim, n * 0.4));
	} else if (mode == 12) { // grave marker: mint glow, cracked earth, small tombstone glyph (top = -Z)
		if (d > 1.0) { discard; }
		vec2 q = uv;
		float stone = max(step(abs(q.x), 0.27) * step(-0.12, q.y) * step(q.y, 0.48), step(length(q - vec2(0.0, -0.12)), 0.27));
		float inner = max(step(abs(q.x), 0.17) * step(-0.12, q.y) * step(q.y, 0.38), step(length(q - vec2(0.0, -0.12)), 0.17));
		float crs = max(step(abs(q.x), 0.04) * step(-0.24, q.y) * step(q.y, 0.24), step(abs(q.y + 0.06), 0.04) * step(abs(q.x), 0.13));
		float n = texture(noise_tex, vec2(ang * 1.1 + seed, d * 0.5)).r;
		float cr = (1.0 - smoothstep(0.0, 0.07, abs(fract(ang / 6.28318 * 5.0 + n * 0.7 + seed) - 0.5) * d)) * step(0.52, d) * (1.0 - smoothstep(0.78, 0.98, d));
		float glow = pow(1.0 - d, 1.4) * 0.5;
		float outline = stone - inner;
		a = max(max(outline, crs * 0.85), max(cr * 0.75, glow));
		c = mix(color.rgb, color2.rgb, max(outline, crs));
	} else { // soft glow disc
		if (d > 1.0) { discard; }
		a = pow(1.0 - d, 2.0);
	}
	ALBEDO = c * intensity;
	ALPHA = clamp(a, 0.0, 1.0) * alpha * color.a;
}
"""

# Glow billboards and additive meshes (projectile cores, flashes, beams, columns)
const ADD := """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform vec4 color2 : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float intensity = 2.0;
uniform float alpha = 1.0;
uniform int mode = 0;
uniform bool billboard = false;
uniform float scroll = 1.0;
uniform float len = 1.0;
void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}
void fragment() {
	float a = 1.0;
	vec3 c = color.rgb;
	if (mode == 0) { // radial glow sprite
		float d = length(UV * 2.0 - 1.0);
		a = pow(clamp(1.0 - d, 0.0, 1.0), 1.6);
		c = mix(color.rgb, color2.rgb, pow(clamp(1.0 - d, 0.0, 1.0), 4.0));
	} else if (mode == 1) { // fresnel sphere core
		float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		c = mix(color.rgb, color2.rgb, pow(f, 3.0));
		a = 0.35 + 0.65 * pow(f, 0.8);
	} else if (mode == 2) { // beam strip across UV.x, along UV.y
		float x = abs(UV.x * 2.0 - 1.0);
		float n = texture(noise_tex, vec2(UV.x * 0.5, UV.y * len * 0.25 - TIME * 2.5 * scroll)).r;
		float core = 1.0 - smoothstep(0.0, 0.35, x);
		a = (1.0 - smoothstep(0.3 + n * 0.4, 1.0, x)) * (0.6 + 0.6 * n);
		c = mix(color.rgb, color2.rgb, core);
		a *= smoothstep(0.0, 0.03, UV.y) * (1.0 - smoothstep(0.97, 1.0, UV.y));
	} else if (mode == 3) { // vertical column (cylinder): UV.y 0 top 1 bottom
		float n = texture(noise_tex, vec2(UV.x * 2.0, UV.y * 0.7 + TIME * 0.9 * scroll)).r;
		a = pow(UV.y, 1.4) * (0.45 + 0.8 * n);
		float f = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
		a *= 0.35 + 0.65 * (1.0 - f) ;
		c = mix(color.rgb, color2.rgb, n * UV.y);
	} else if (mode == 4) { // crescent slash on quad
		vec2 p = UV * 2.0 - 1.0;
		float d = length(p - vec2(0.0, 0.6));
		float arc = 1.0 - smoothstep(0.0, 0.12, abs(d - 1.0));
		arc *= 1.0 - smoothstep(0.55, 1.0, abs(p.x));
		a = arc;
		c = mix(color.rgb, color2.rgb, arc);
	} else if (mode == 5) { // hex shell (carapace): fresnel + hex grid
		float f = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
		vec2 q = UV * vec2(24.0, 12.0);
		vec2 h = abs(fract(q + vec2(0.5 * floor(q.y), 0.0)) - 0.5);
		float hex = 1.0 - smoothstep(0.38, 0.47, max(h.x, h.y));
		a = 0.08 + pow(f, 2.0) * 0.8 + (1.0 - hex) * 0.35;
		c = mix(color.rgb, color2.rgb, f);
	} else if (mode == 6) { // rune glyph sprite
		vec2 p = UV * 2.0 - 1.0;
		float d = length(p);
		float ring = 1.0 - smoothstep(0.0, 0.08, abs(d - 0.8));
		float dia = 1.0 - smoothstep(0.0, 0.08, abs(abs(p.x) + abs(p.y) - 0.55));
		float bar = (1.0 - smoothstep(0.0, 0.06, abs(p.x))) * step(abs(p.y), 0.55);
		a = max(max(ring, dia), bar) + pow(clamp(1.0 - d, 0.0, 1.0), 2.0) * 0.4;
		c = mix(color.rgb, color2.rgb, max(dia, bar));
	}
	ALBEDO = c * intensity * a * alpha;
}
"""

# ----------------------------------------------------------------- factories

static func shader(key: String) -> Shader:
	if _shaders.has(key):
		return _shaders[key]
	var code := ""
	match key:
		"unit": code = UNIT
		"ghost": code = UNIT_GHOST
		"world": code = WORLD
		"floor": code = FLOOR
		"grass": code = GRASS
		"water": code = WATER
		"water_add": code = WATER.replace("render_mode cull_disabled, specular_disabled, unshaded;", "render_mode blend_add, depth_draw_never, cull_disabled, unshaded;")
		"flame": code = FLAME
		"decal_mix": code = DECAL.replace("BLEND_MODE", "blend_mix")
		"decal_add": code = DECAL.replace("BLEND_MODE", "blend_add")
		"add": code = ADD
		_: code = UNIT
	var s := Shader.new()
	s.code = code
	_shaders[key] = s
	return s

static func noise_tex() -> Texture2D:
	if _tex.has("noise"):
		return _tex["noise"]
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.012
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 4
	fn.seed = 7
	var img := fn.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["noise"] = t
	return t

static func glow_dot_tex() -> Texture2D:
	if _tex.has("dot"):
		return _tex["dot"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["dot"] = t
	return t

static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"world", "floor", "grass", "water", "flame":
			var sm := ShaderMaterial.new(); sm.shader = shader(key)
			sm.set_shader_parameter("noise_tex", noise_tex())
			if key == "world" or key == "flame":
				occluder_mats.append(sm)
			m = sm
		"water_fall":
			var sm := ShaderMaterial.new(); sm.shader = shader("water_add")
			sm.set_shader_parameter("noise_tex", noise_tex())
			sm.set_shader_parameter("falling", 1.0)
			m = sm
		"particle_add":
			var pm := StandardMaterial3D.new()
			pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pm.vertex_color_use_as_albedo = true
			pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			pm.albedo_texture = glow_dot_tex()
			pm.albedo_color = Color(2.2, 2.2, 2.2, 1.0)
			pm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			pm.disable_receive_shadows = true
			m = pm
		"particle_mix":
			var pm := StandardMaterial3D.new()
			pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pm.vertex_color_use_as_albedo = true
			pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			pm.albedo_texture = glow_dot_tex()
			pm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			m = pm
		"debris":
			var pm := StandardMaterial3D.new()
			pm.vertex_color_use_as_albedo = true
			pm.roughness = 1.0
			pm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			m = pm
		"debris_glow":
			var pm := StandardMaterial3D.new()
			pm.vertex_color_use_as_albedo = true
			pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pm.albedo_color = Color(2.5, 2.5, 2.5)
			m = pm
		"shadow":
			var sm := ShaderMaterial.new()
			var s := Shader.new()
			s.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = 1.0 - smoothstep(0.35, 1.0, d);
	ALBEDO = vec3(0.02, 0.015, 0.03);
	ALPHA = a * 0.62 * COLOR.a;
}
"""
			sm.shader = s
			m = sm
		_:
			var sm := ShaderMaterial.new(); sm.shader = shader("unit")
			sm.set_shader_parameter("noise_tex", noise_tex())
			m = sm
	_mats[key] = m
	return m

static func new_unit_mat(glow: Color, ao_h: float) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = shader("unit")
	sm.set_shader_parameter("noise_tex", noise_tex())
	sm.set_shader_parameter("glow_color", glow)
	sm.set_shader_parameter("ao_height", ao_h)
	return sm

static func new_ghost_mat(glow: Color, alpha: float, use_vcol := 1.0) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = shader("ghost")
	sm.set_shader_parameter("noise_tex", noise_tex())
	sm.set_shader_parameter("glow_color", glow)
	sm.set_shader_parameter("alpha", alpha)
	sm.set_shader_parameter("use_vcol", use_vcol)
	return sm

static func new_decal_mat(additive: bool) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = shader("decal_add" if additive else "decal_mix")
	sm.set_shader_parameter("noise_tex", noise_tex())
	return sm

static func new_add_mat(c: Color, c2: Color, mode: int, intensity := 2.0, billboard := false) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = shader("add")
	sm.set_shader_parameter("noise_tex", noise_tex())
	sm.set_shader_parameter("color", c)
	sm.set_shader_parameter("color2", c2)
	sm.set_shader_parameter("mode", mode)
	sm.set_shader_parameter("intensity", intensity)
	sm.set_shader_parameter("billboard", billboard)
	return sm

## Cached additive material keyed by params (shared between instances that never change it).
static func add_mat_shared(c: Color, c2: Color, mode: int, intensity := 2.0, billboard := false) -> ShaderMaterial:
	var key := "add_%s_%s_%d_%.2f_%s" % [c.to_html(), c2.to_html(), mode, intensity, billboard]
	if not _mats.has(key):
		_mats[key] = new_add_mat(c, c2, mode, intensity, billboard)
	return _mats[key]
