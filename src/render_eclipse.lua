--[[
  A bit of a halo around the sun during full solar eclipse.
]]

local function renderEclipseGlare()
  local sunDirVisual = ac.fixHeading(SunDir)
  render.setDepthMode(render.DepthMode.ReadOnly)
  render.setBlendMode(render.BlendMode.BlendPremultiplied)
  render.shaderedQuad({
    pos = ac.getSim().cameraPosition + sunDirVisual * 1e4,
    width = 200,
    height = 200,
    values = {
      gSunDir = sunDirVisual,
      gIntensity = ac.getSkyAbsorption(sunDirVisual):scale(EclipseFullK * 0.2),
      gTime = ac.getSim().currentSessionTime / 1e5,
    },
    async = true,
    cacheKey = 1,
    shader = [[
      float4 noiseTex(float2 uv, float level = 0){
        float textureResolution = 32;
        uv = uv * textureResolution + 0.5;
        float2 i = floor(uv);
        float2 f = frac(uv);
        uv = i + f * f * (3 - 2 * f);
        uv = (uv - 0.5) / textureResolution;
        return txNoise.SampleLevel(samLinearSimple, uv, level);
      }

      float4 main(PS_IN pin) {
        float coord = atan2(pin.Tex.x * 2 - 1, pin.Tex.y * 2 - 1) / 3.141592;
        float4 noise0 = noiseTex(float2(coord, gTime));
        float d = saturate(dot(normalize(pin.PosC), gSunDir)) - 0.99999;
        float b = pow(saturate(1 + d * 0.5e5 * (1 + noise0.x)), 16) * pow(saturate(-d * 1e6), 2);
        return float4(gIntensity * b, 0);
      }
    ]]
  })
end

local subscribed ---@type fun()?

function UpdateEclipseGlare(active)
  if not subscribed and active then
    subscribed = RenderSkySubscribe(render.PassID.Main, renderEclipseGlare)
  elseif subscribed and not active then
    subscribed()
    subscribed = nil
  end
end
