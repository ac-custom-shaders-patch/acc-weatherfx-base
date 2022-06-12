

-- ac.TrackConditions()

-- Disable cars exposure values, reset camera exposure
-- ac.setCarExposureActive(false)
-- ac.setCameraExposure(33)

-- ac.setReflectionsSaturation(4)

local light = ac.LightSource(ac.LightType.Regular)
light.position = vec3(0, 15, 0)
light.direction = vec3(0, -1, 0)
light.spot = 150
light.spotSharpness = 0.99
light.color = rgb(0, 10, 10)
light.range = 30
light.shadows = true

-- local cloudsCover = ac.SkyCloudsCover()
-- cloudsCover:setTexture('clouds/iw_d26.dds')
-- ac.addWeatherCloudCover(cloudsCover)
-- cloudsCover.colorExponent = rgb(0.9, 1, 1)
-- cloudsCover.colorMultiplier = rgb(2.4, 2.3, 2.2)
-- cloudsCover.opacityExponent = 0.3
-- cloudsCover.opacityMultiplier = 1
-- cloudsCover.opacityCutoff = 0
-- cloudsCover.opacityFade = 0.5 -- texture fading to this alpha below horizon
-- cloudsCover.texRemapY = 1.02
-- cloudsCover.shadowRadius = 10000 -- meters
-- cloudsCover.shadowOpacityMultiplier = 1
-- cloudsCover:setFogParams(0.5, 0, 1, 1)

function RunDevTests()
  -- light:dispose()
  -- light.color.r = light.color.r + dt * 10

  -- if true then
  --   -- ac.setLightDirection(vec3(0, 1, 1))
  --   -- ac.setLightColor(rgb(10, 10, 10))
  --   ruBase:update(gameDT, forceUpdate)
  --   return 0
  -- end
  -- cloudsCover.texOffsetX = cloudsCover.texOffsetX + dt * 0.01

  -- ac.setAutoExposureActive(false)
  -- ac.setAutoExposureMeasuringArea(vec2(0.5, 0.25), vec2(0.4, 0.4))
  -- ac.setAutoExposureTarget(100)
  -- ac.setAutoExposureInfluencedByGlare(false)
  -- ac.setAutoExposureLimits(0, 0.22)

  -- ac.setShadows(ac.ShadowsState.Off)
  -- ac.setShadows(ac.ShadowsState.On)
  -- ac.setShadowsResolution(32)

  -- ac.debug('getCloudsShadow', ac.getCloudsShadow())

  -- ac.setShadowsResolution(512)
  -- ac.setShadowsResolution(2048)
  -- ac.setShadowsResolution(128)

  -- ac.debug('ac.getCameraOcclusion(vec3(0, 1, 0))', ac.getCameraOcclusion(vec3(0, 1, 0)))
  -- ac.debug('ac.getCameraLookOcclusion()', ac.getCameraLookOcclusion())

  -- For debugging:
  -- numlutTest()
end


-- some render examples:

local function testRenderQuad()
  render.setBlendMode(render.BlendMode.AlphaBlend)
  render.setCullMode(render.CullMode.None)
  render.setDepthMode(render.DepthMode.Off)

  render.quad(
    vec3(-198.32, -11.51, -289.19),
    vec3(-189.03, -11.77, -293.84),
    vec3(-186.98, -12.61, -285.31),
    vec3(-196.93, -12.32, -279.93),
    rgbm(1, 1, 0, 1),
    'clouds/atlas.dds' 
  )

  render.shaderedQuad({
    p1 = vec3(-198.32, -11.51, -289.19),
    p2 = vec3(-189.03, -11.77, -293.84),
    p3 = vec3(-186.98, -12.61, -285.31),
    p4 = vec3(-196.93, -12.32, -279.93),
    textures = {
      txAtlas =  'clouds/atlas.dds'
    },
    values = {
      gColor =  rgbm(1, 0, 0, 1),
    },
    shader = [[float4 main(PS_IN pin) {
      return pin.ApplyFog(txAtlas.Sample(samLinear, pin.Tex * 4) * gColor);
    }]]
  })
end


-- shader, how to get pos in world space:
--[[
  float depthValue = txDepth.SampleLevel(samLinearSimple, pin.Tex, 0);
  float4 posW = mul(float4(pin.Tex, depthValue, 1), gTexToCamera);
  posW.xyz /= posW.w;
  posW.xyz += gCameraPosition;  
  return float4(frac(posW.xyz), 0.5);
]]