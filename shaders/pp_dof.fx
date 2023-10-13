// Based on https://blog.voxagon.se/2018/05/04/bokeh-depth-of-field-in-single-pass.html

#define GOLDEN_ANGLE 2.4
#define MAX_BLUR_SIZE 10.0
#define RAD_SCALE 1

float getBlurSize(float depth) {
  return saturate(abs((focusPoint - depth) * focusScale)) * MAX_BLUR_SIZE;
}

float4 main(PS_IN pin){
	float centerDepth = txDepth.SampleLevel(samLinearSimple, pin.Tex, 0);
	float centerSize = getBlurSize(centerDepth);
	float3 color = txInput.SampleLevel(samLinearSimple, pin.Tex, 0).rgb;
	float tot = 1;
	float radius = 1;
	for (float ang = 0.0; radius < MAX_BLUR_SIZE; ang += GOLDEN_ANGLE) {
		float2 tc = pin.Tex + float2(cos(ang), sin(ang)) * uPixelSize * radius;
		float4 sampleColor = txDOF.SampleLevel(samLinearClamp, tc, 0);
		float sampleDepth = sampleColor.w;
		float sampleSize = getBlurSize(sampleDepth);
		if (sampleDepth > centerDepth) sampleSize = clamp(sampleSize, 0.0, centerSize*2.0);
		float m = smoothstep(radius - 0.5, radius + 0.5, sampleSize);
		color += lerp(color / tot, sampleColor.rgb, m);
		tot += 1.0;
    radius += RAD_SCALE / radius;
	}
  color /= tot;
	return float4(color, 1);
}