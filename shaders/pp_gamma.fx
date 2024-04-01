float3 toSrgb(float3 linearRGB) {  
	bool3 cutoff = linearRGB < 0.0031308;
	float3 higher = 1.055 * pow(max(linearRGB, 0), 1. / 2.4) - 0.055;
	float3 lower = linearRGB * 12.92;
	return lerp(higher, lower, cutoff ? 1 : 0);
}

float4 main(PS_IN pin) {
  return float4(toSrgb(txHDR.SampleLevel(samLinear, pin.Tex, 0).rgb * gBrightness), 1);
}