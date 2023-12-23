--[[
  Very simple and static weather for generating previews.
]]

ac.setMoonEclipse(false)
ac.setManualCloudsInvalidation(true)
ac.setSkyUseV2(true)
ac.setCloudArcMultiplier(1)
ac.setFogAlgorithm(ac.FogAlgorithm.New)
ac.fixSkyColorCalculateResult(true)
ac.fixSkyColorCalculateOrder(true)
ac.fixSkyV2Fog(true)
ac.fixCloudsV2Fog(true)
ac.setLambertGamma(1 / 2.2)
ac.setCloudShadowMaps(true)

-- Basic neutral blue sky
ac.setSkyV2MieKCoefficient(ac.SkyRegion.All, vec3(0.686, 0.678, 0.666))
ac.setSkyV2NumMolecules(ac.SkyRegion.All, 2.542e25)
ac.setSkyV2MieCoefficient(ac.SkyRegion.All, 0.005)
ac.setSkyV2Primaries(ac.SkyRegion.All, vec3(6.8e-7, 5.5e-7, 4.5e-7))
ac.setSkyV2Turbidity(ac.SkyRegion.All, 2.0)
ac.setSkyV2Rayleigh(ac.SkyRegion.All, 1)
ac.setSkyV2MieDirectionalG(ac.SkyRegion.All, 0.8)
ac.setSkyV2RefractiveIndex(ac.SkyRegion.All, 1.0003)
ac.setSkyV2DepolarizationFactor(ac.SkyRegion.All, 0.035)
ac.setSkyV2MieV(ac.SkyRegion.All, 3.96)
ac.setSkyV2RayleighZenithLength(ac.SkyRegion.All, 8400)
ac.setSkyV2MieZenithLength(ac.SkyRegion.All, 1.25e3)
ac.setSkyV2SunIntensityFactor(ac.SkyRegion.All, 1000.0)
ac.setSkyV2SunIntensityFalloffSteepness(ac.SkyRegion.All, 1.5)

ac.setSkyV2BackgroundLight(ac.SkyRegion.All, 0.0)
ac.setSkyV2Luminance(ac.SkyRegion.All, 0.3)
ac.setSkyV2Gamma(ac.SkyRegion.All, 2.5)
ac.setSkyV2SunShapeMult(ac.SkyRegion.All, 10)
ac.setSkyV2SunSaturation(ac.SkyRegion.All, 0.9)
ac.setSkyV2Saturation(ac.SkyRegion.All, 1)
ac.setSkyBrightnessMult(1)
ac.setSkyV2YOffset(ac.SkyRegion.All, 0.1)
ac.setSkyV2YScale(ac.SkyRegion.All, 0.9)

if ac.getTrackID() == '../showroom/at_previews' then
  ac.setSkyV2Saturation(ac.SkyRegion.All, 0.5)
end

-- Disable fog
ac.setFogColor(rgb())
ac.setFogExponent(1)
ac.setFogDensity(0)
ac.setFogDistance(100)
ac.setFogHeight(0)
ac.setSkyFogMultiplier(0)
ac.setHorizonFogMultiplier(0, 1, 1)
ac.setFogBlend(0)
ac.setFogBacklitExponent(1)
ac.setFogBacklitMultiplier(0)

-- Ambient light
ac.setAmbientColor(rgb(10, 10, 10))
ac.setWeatherFakeShadowOpacity(1)
ac.setWeatherFakeShadowConcentration(0)
ac.adjustTrackVAO(0.6, 0, 1)
ac.adjustDynamicAOSamples(0.2, 0, 1)

-- Directional light
ac.setLightColor(rgb(10, 10, 10))
ac.setLightDirection(vec3(0, 1, 0))
ac.setSpecularColor(rgb(1, 1, 1))
ac.setSunSpecularMultiplier(1)
ac.setGodraysCustomColor(rgb(0, 0, 0))
ac.setGodraysCustomDirection(vec3(0, 1, 0))
ac.setShadows(ac.ShadowsState.On)

-- Extra tweaks
ac.setBrightnessMult(1)
ac.setOverallSkyBrightnessMult(1)
ac.setWeatherLightsMultiplier(1)
ac.setTrueEmissiveMultiplier(1)
ac.setGlowBrightness(1)
ac.setEmissiveMultiplier(1)
ac.setWeatherTrackLightsMultiplierThreshold(0)
ac.setReflectionEmissiveBoost(1)
ac.setReflectionsBrightness(1)

-- Optional override
local weather = ac.connect({
  ac.StructItem.key('showroomPreviewsWeather'),
  set = ac.StructItem.boolean(),
  ambientTopColor = ac.StructItem.rgb(),
  ambientBottomColor = ac.StructItem.rgb(),
  lightColor = ac.StructItem.rgb(),
  lightDirection = ac.StructItem.vec3(),
  useBackgroundColor = ac.StructItem.boolean(),
  backgroundColor = ac.StructItem.rgb(),
  specularColor = ac.StructItem.rgb(),
  sunSpecularMultiplier = ac.StructItem.float(),
  shadowsOpacity = ac.StructItem.float(),
  shadowsConcentration = ac.StructItem.float(),
  disableShadows = ac.StructItem.boolean(),
  customToneParams = ac.StructItem.boolean(),
  toneFunction = ac.StructItem.int32(),
  toneExposure = ac.StructItem.float(),
  toneGamma = ac.StructItem.float(),
  whiteReferencePoint = ac.StructItem.float(),
  saturation = ac.StructItem.float(),
  fakeReflection = ac.StructItem.boolean(),
  reflectionBrightness = ac.StructItem.float(),
  reflectionSaturation = ac.StructItem.float(),
})

local fakeSceneSet = false

local function syncOverride()
  if not weather.set then return end
  weather.set = false
  ac.setAmbientColor(weather.ambientTopColor)
  ac.setExtraAmbientColor(weather.ambientBottomColor - weather.ambientTopColor)
  ac.setExtraAmbientDirection(vec3(0, -1, 0))
  ac.setLightColor(weather.lightColor)
  ac.setLightDirection(weather.lightDirection)
  ac.setSpecularColor(weather.specularColor)
  ac.setSunSpecularMultiplier(weather.sunSpecularMultiplier)
  ac.setWeatherFakeShadowConcentrarion(weather.shadowsConcentration)
  ac.setWeatherFakeShadowOpacity(weather.shadowsOpacity)
  ac.setShadows(weather.disableShadows and ac.ShadowsState.Off or ac.ShadowsState.On)
  ac.setReflectionsBrightness(weather.reflectionBrightness)
  ac.setReflectionsSaturation(weather.reflectionSaturation)
  ac.setPpSaturation(weather.saturation)
  if weather.customToneParams then
    if weather.toneFunction ~= -1 then ac.setPpTonemapFunction(weather.toneFunction) end
    if weather.toneExposure ~= 0 then ac.setPpTonemapExposure(weather.toneExposure) end
    if weather.toneGamma ~= 0 then ac.setPpTonemapGamma(weather.toneGamma) end
    if weather.whiteReferencePoint ~= 0 then ac.setPpTonemapMappingFactor(weather.whiteReferencePoint) end
  end
  if weather.useBackgroundColor then
    ac.setSkyV2SunShapeMult(ac.SkyRegion.All, 0)
    ac.setSkyPlanetsBrightness(0)
    ac.setSkyMoonBrightness(0)

    local adjNone = ac.SkyExtraGradient({ color = rgb(), isAdditive = false, sizeFull = 3, sizeStart = 3, direction = vec3(0, 1, 0) })
    local adjColor = ac.SkyExtraGradient({ color = weather.backgroundColor, isAdditive = true, sizeFull = 3, sizeStart = 3, direction = vec3(0, 1, 0) })
    ac.addSkyExtraGradient(adjNone)
    ac.addSkyExtraGradient(adjColor)
  end

  if weather.fakeReflection and not fakeSceneSet then
    fakeSceneSet = true
    ac.enableRenderCallback(render.PassID.CubeMap)
  end
end

function script.renderSky()
  if weather.fakeReflection then
    render.fullscreenPass({
      blendMode = render.BlendMode.Opaque,
      values = { gBackgroundColor = weather.backgroundColor },
      shader = 'shaders/showroom_cubemap.fx'
    })
  end
end

syncOverride()
function script.update(dt)
  syncOverride()
end
