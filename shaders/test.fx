#define M_PI 3.14159265359

float4 sampleQuad(Texture2D tx, int index, float2 uv){
  if (index < 0 || index >= 8) return float4(1, 0, 0, 1);

  float h = 820/2048.;
  float w = 420/2048.;
  float2 ps[] = {
    float2(1062/2048., 1203/2048.),
    float2(655/2048., 1203/2048.),
    float2(215/2048., 1203/2048.),
    float2(1070/2048., 2044/2048.),
    float2(1457/2048., 1203/2048.),
    float2(1513/2048., 2044/2048.),
    float2(222/2048., 2044/2048.),
    float2(667/2048., 2044/2048.),
  };

  float lod = tx.CalculateLevelOfDetail(samLinear, uv * w);

  float2 p = ps[index];
  uv.x = lerp(p.x - w / 2, p.x + w / 2, uv.x);
  uv.y = lerp(p.y - h, p.y, uv.y);

  // float4 p = ps[…];
  // uv = p.xy + p.zw * uv;

  return tx.SampleLevel(samLinear, uv, lod);
}

float2 rotate2d(float2 vec, float angle){
	float sinX = sin(angle);
	float cosX = cos(angle);
	float sinY = sin(angle);
	return mul(float2x2(cosX, -sinX, sinY, cosX), vec);
}

float4 sampleAbove(Texture2D tx, float2 dir, float2 uv){
  float2 f = float2(1650/2048., 770/2048.);
  float2 s = float2(387/2048., 431/2048.);
  f.x -= (s.y - s.x) / 2;
  s.x = s.y;

  // TODO: do it differently

  uv = rotate2d(uv * 2 - 1, gOffset - atan2(gDir.x, gDir.z));
  if (length(uv * float2(431/387., 1)) > 1) return 0;

  uv = f + s * (uv * 0.5 + 0.5);

  // uv = f + s * uv * 0.5 + s * 0.5;
  // s2 = s * 0.5
  // f2 = f + s2

  // if (uv.x < 1650/2048.) return 0;
  return tx.Sample(samLinear, uv);
}

float smootherstep(float x){
  return x * x * x * (x * (x * 6 - 15) + 10);
}

float4 mixSides(float4 v0, float4 v1, float mix){  
  float4 ret = lerp(v0, v1, mix);
  ret.w = (ret.w + min(v0.w, v1.w)) / 2;
  // return lerp(v0, v1, smootherstep(mix));
  return ret;
}

float4 sampleQuadMix(Texture2D tx, float index, float2 uv){
  if (any(uv < 0) || any(uv > 1)) return 0;
  float4 v0 = sampleQuad(tx, floor(index) % 8, uv);
  float4 v1 = sampleQuad(tx, ceil(index) % 8, uv);
  float mix = index - floor(index);
  return mixSides(v0, v1, mix);
}

float4 sample3D(Texture2D tx, float angle, float2 uv, float3 posC){
  float sideIndex = (angle / M_PI + 1) * 4;
  float aboveMix = saturate(abs(gDir.y) - uv.y * (1 - abs(gDir.y)));

  float2 uvS = uv;
  float tilt = pow(abs(gDir.y), 6 + 4 * saturate(abs(gDir.y) * 3 - 2));
  // uv.x = (uv.x * 2 - 1) * (1 + uv.y * 2 * tilt) * 0.5 + 0.5;
  uvS.y = uvS.y * (1 + tilt);
  float w = 0.04 * uvS.y;
  float m = abs(uvS.x - 0.5) / w;
  if (m < 1){
    uvS.y += pow(m, 2) * abs(gDir.y)  * uvS.y * w;
  }
  float4 vSide = sampleQuadMix(tx, sideIndex, uvS);

  float2 uvA = uv;
  uvA.y = 1 - pow(1 - uvA.y, 2 - 1 * abs(gDir.y));
  float4 vAbove = sampleAbove(tx, posC.xz, uvA);
  
  // return vSide;
  // return vAbove;

  vAbove.w *= saturate((aboveMix - 0.4) / 0.2);
  vSide.w *= saturate((aboveMix - 0.8) / -0.1);

  vSide = lerp(vSide, vAbove, max(saturate(1 - vSide.w * 4), vAbove.w * smootherstep(aboveMix)));
  return vSide;
}

void sampleTex(float angle, float2 uv, float3 posC,
    out float4 col, out float4 nm, out float4 ss, out float4 occ){
  float4 noise = txNoise.SampleLevel(samLinear, uv, 0);
  angle += noise.x * 0.5;

  col = sample3D(txColor, angle, uv, posC);
  nm = sample3D(txNormal, angle, uv, posC);
  ss = sample3D(txSubsurface, angle, uv, posC);
  occ = sample3D(txOcclusion, angle, uv, posC);
  // occ = 1;
  // ss = 1;
}

float4 main(PS_IN pin) {
  float2 uv = pin.Tex;

  // if (any(abs(uv * 2 - 1) > 0.995)) return float4(10, 0, 0, 1);

  float angle = -atan2(pin.PosC.x, pin.PosC.z) + gOffset;

  float4 dif, nm, ss, occ;
  sampleTex(angle, uv, pin.PosC, dif, nm, ss, occ);

  // float3 gSide = normalize(cross(gDir, float3(0, 1, 0)));

  nm.rgb = nm.rgb * 2 - 1;

  float3 nmW = normalize(gSide * (nm.x + pin.Tex.x * 2 - 1) - gDir * pow(length((pin.Tex * 2 - 1) * float2(1, 0.5)), 2) + gUp * nm.y + gDir * nm.z);
  // float3 nmW = normalize(gSide * nm.x + gUp * nm.y + gDir * nm.z);
  // float3 nmW = nm;

  float4 col = dif;
  col.rgb *= gLightColor * pow(saturate(dot(nmW, gLightDirection)), 1/2.2) * saturate(occ.g * 2.5 - 0.5)
    + gAmbientColor * (0.3 * nmW.y + 0.7) * (1 - 0.3 * uv.y) * occ.g;

  float3 ssK = ss.g * dif.rgb / max(dif.r, max(dif.g, max(0.1, dif.b))) * occ.g;
  col.rgb += gLightColor * ssK * pow(saturate(-dot(gLightDirection, normalize(pin.PosC))), 4); 
  col.rgb += gLightColor * ssK * pow(saturate(-dot(gLightDirection, nmW)), 4) * 0.1; 

  col.rgb *= 0.45;
  col.rgb *= 0.9 + 0.2 * gBias;

  clip(col.w - 0.1);
  col.w = saturate((col.w - 0.1) * 4);

  float fresnel = 1 - abs(dot(normalize(pin.PosC), nmW));
  float4 refl = txReflectionCubemap.SampleLevel(samLinear, reflect(normalize(pin.PosC), nmW) * float3(-1, 1, 1), 5);
  col.rgb = lerp(col.rgb, refl.rgb, fresnel * 0.2);

  return pin.ApplyFog(col);
}
