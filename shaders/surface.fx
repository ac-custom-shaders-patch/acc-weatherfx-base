
float4 main(PS_IN pin) {
  float4 col = float4((1 + pin.Tex) * pin.GetCloudShadow(), 0, 1);
  return pin.ApplyFog(col);
}
