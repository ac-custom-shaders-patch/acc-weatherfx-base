#include "pp_tonemapping.hlsl"

float main(PS_IN pin) {
  float4 col = txInput.SampleLevel(samLinearClamp, pin.Tex * gAreaSize + gAreaOffset, 0);
  if (USE_LINEAR_COLOR_SPACE) {
    col = pow(max(col * gGammaFixBrightnessOffset, 0), 1 / 2.2);
  }
  col.rgb = colorGrading(col.rgb);
  return log(dot(col.rgb, float3(0.2126, 0.7152, 0.0722)));
}