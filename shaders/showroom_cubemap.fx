float saturate(float v, float e) {
  return saturate(v * e + 0.5);
}

float GetFakeHorizon(float3 d, float e) {
	return saturate((d.y + 0.02) * 5.0 * e) * saturate(1 - pow(d.y * 1.5, 2)) * 0.3;
}

float GetFakeStudioLights(float3 d, float e) {
  return (
    saturate(0.3 - abs(0.6 - d.y), e) +
    saturate(0.1 - abs(0.1 - d.y), e)
    ) * saturate(0.3 - abs(0.1 + sin(d.x * 11.0)), e);
}

float4 main(PS_IN pin) {
  float3 reflected = normalize(pin.PosC.xyz);
  float edge = 10.0;
  float fake = saturate(GetFakeHorizon(reflected, edge) + GetFakeStudioLights(reflected, edge));
  return float4(gBackgroundColor * (1 - fake) * 1.1 + fake * 1.8, 1);
}
