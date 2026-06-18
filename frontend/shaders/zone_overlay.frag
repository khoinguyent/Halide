#version 460 core

#include <flutter/runtime_effect.glsl>

// ImageFilter / BackdropFilter: u_size + u_texture are set by the engine.
uniform vec2 u_size;
uniform float u_ev_target;
uniform float u_ev_anchor;
uniform float u_anchor_luminance;
uniform sampler2D u_texture;

out vec4 frag_color;

const float ZONE_BLEND = 0.6;
const float HYSTERESIS_EV = 0.12;

float log2v(float x) {
  return log(max(x, 0.0001)) / log(2.0);
}

float rec709Luma(vec3 rgb) {
  return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

// 3×3 Gaussian blur on luminance — temporal hysteresis / flicker reduction.
float blurredLuma(vec2 uv, vec2 texel) {
  float sum = 0.0;
  sum += rec709Luma(texture(u_texture, uv + texel * vec2(-1.0, -1.0)).rgb) * 1.0;
  sum += rec709Luma(texture(u_texture, uv + texel * vec2( 0.0, -1.0)).rgb) * 2.0;
  sum += rec709Luma(texture(u_texture, uv + texel * vec2( 1.0, -1.0)).rgb) * 1.0;
  sum += rec709Luma(texture(u_texture, uv + texel * vec2(-1.0,  0.0)).rgb) * 2.0;
  sum += rec709Luma(texture(u_texture, uv).rgb) * 4.0;
  sum += rec709Luma(texture(u_texture, uv + texel * vec2( 1.0,  0.0)).rgb) * 2.0;
  sum += rec709Luma(texture(u_texture, uv + texel * vec2(-1.0,  1.0)).rgb) * 1.0;
  sum += rec709Luma(texture(u_texture, uv + texel * vec2( 0.0,  1.0)).rgb) * 2.0;
  sum += rec709Luma(texture(u_texture, uv + texel * vec2( 1.0,  1.0)).rgb) * 1.0;
  return sum / 16.0;
}

vec4 zoneColorHard(float deltaEV) {
  if (deltaEV <= -5.0) return vec4(0.117, 0.0, 0.231, 1.0);   // Zone 0
  if (deltaEV <= -4.0) return vec4(0.0, 0.106, 0.282, 1.0);   // Zone I
  if (deltaEV <= -3.0) return vec4(0.0, 0.271, 0.525, 1.0);   // Zone II
  if (deltaEV <= -2.0) return vec4(0.0, 0.502, 1.0, 1.0);     // Zone III
  if (deltaEV <= -1.0) return vec4(0.0, 0.639, 0.639, 1.0);   // Zone IV
  if (deltaEV < 1.0)   return vec4(0.0, 1.0, 0.0, 1.0);         // Zone V
  if (deltaEV < 2.0)   return vec4(0.502, 1.0, 0.0, 1.0);     // Zone VI
  if (deltaEV < 3.0)   return vec4(1.0, 1.0, 0.0, 1.0);       // Zone VII
  if (deltaEV < 4.0)   return vec4(1.0, 0.502, 0.0, 1.0);     // Zone VIII
  if (deltaEV < 5.0)   return vec4(1.0, 0.251, 0.0, 1.0);     // Zone IX
  return vec4(1.0, 0.0, 0.0, 1.0);                              // Zone X
}

// Soft overlap at boundaries (±HYSTERESIS_EV) to reduce border flicker.
vec4 zoneColor(float deltaEV) {
  vec4 lower = zoneColorHard(deltaEV - HYSTERESIS_EV);
  vec4 upper = zoneColorHard(deltaEV + HYSTERESIS_EV);
  return mix(lower, upper, 0.5);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;

#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec4 rawColor = texture(u_texture, uv);
  vec2 texel = 2.0 / u_size;
  float luma = blurredLuma(uv, texel);
  float anchor = max(u_anchor_luminance, 0.001);
  float evPixel = u_ev_anchor + log2v(luma / anchor);
  float deltaEV = evPixel - u_ev_target;
  vec4 zColor = zoneColor(deltaEV);
  zColor.a = ZONE_BLEND;
  frag_color = mix(rawColor, zColor, ZONE_BLEND);
}
