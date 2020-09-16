--------
-- Most of weather stuff happens here: it sets lighting, fog, scene brightness and prepares a few globally defined
-- cloud materials.
--------

-- Global weather values
nightK = 0

-- Various local variables, changing with each update, something easy to deal with things. There is 
-- no need to edit any of those values if you want to change anything, please proceed further to
-- actual functions setting that stuff
local zenithK = 1 -- for example, this parameter is an easy way to tell how high is the sun (I use postfix K for “coefficient”)
local sunsetK = 0
local horizonK = 0
local deepNightK = 0
local eclipseK = 0 -- starts growing when moon touches sun, 1 at total eclipse
local eclipseFullK = 0
local lightBrightness = 1
local initialSet = 3
local sunDir = vec3(0, 1, 0)
local moonDir = vec3(0, 1, 0)
local sunColor = rgb(1, 1, 1)
local ambientBaseColor = rgb(1, 1, 1)
local ambientAdjColor = rgb(1, 1, 1)
local skyTopColor = rgb(1, 1, 1)
local skySunColor = rgb(1, 1, 1)
local lightDir = vec3(0, 1, 0)
local lightColor = rgb(0, 0, 0)

local skyGeneralMult = nil
local skyGradient = nil

if UseSkyV2 then
else
  -- Sky gradient covering everything, for sky-wide color correction
  skyGeneralMult = ac.SkyExtraGradient()
  skyGeneralMult.isAdditive = false
  skyGeneralMult.sizeFull = 2
  skyGeneralMult.sizeStart = 2
  skyGeneralMult.direction = vec3(0, 1, 0)
  ac.addSkyExtraGradient(skyGeneralMult)

  -- Sky gradient facing up, for extra juicy sky color
  skyGradient = ac.SkyExtraGradient()
  skyGradient.isAdditive = false
  skyGradient.sizeFull = 0.5
  skyGradient.sizeStart = 1.5
  skyGradient.direction = vec3(0, 1, 0)
  ac.addSkyExtraGradient(skyGradient)
end

-- Custom post-processing brightness adjustment
local ppBrightnessCorrection = ac.ColorCorrectionBrightness()
local ppSaturationCorrection = ac.ColorCorrectionSaturation()
ac.addWeatherColorCorrection(ppBrightnessCorrection)
ac.addWeatherColorCorrection(ppSaturationCorrection)

-- There values are just so GC wouldn’t have to collect all these vectors
local moonAbsorption = rgb()
local fogColor = rgb()
local cloudLightColor = rgb()
local baseAmbientColor = rgb()
local vec3Up = vec3(0, 1, 0)

-- Updates sky color
function applySky()
  ac.getSunDirectionTo(sunDir)
  ac.getMoonDirectionTo(moonDir)

  zenithK = math.lerpInvSat(sunDir.y, 0, 0.4)
  nightK = math.lerpInvSat(sunDir.y, 0.115, -0.115)
  deepNightK = math.lerpInvSat(sunDir.y, -0.115, -0.4)
  deepNightK = 1 - math.pow(1 - deepNightK, 2)

  -- Eclipse coefficients. You can test full eclipse with Brasov track on 08/11/1999:
  -- https://www.racedepartment.com/downloads/brasov-romania.28239/
  eclipseK = math.lerpInvSat(math.dot(sunDir, moonDir), 0.99965, 0.999999)
  eclipseFullK = math.pow(math.lerpInvSat(eclipseK, 0.95, 1), 2)

  -- https://en.wikipedia.org/wiki/Midnight_sun#White_nights
  local dayK = math.lerpInvSat(math.max(0, sunDir.y), 0.1, 0.3)
  sunsetK = math.lerpInvSat(math.max(0, sunDir.y), 0.12, 0)
  horizonK = math.lerpInvSat(math.abs(sunDir.y), 0.4, 0.12)
  local twilightK = math.lerpInvSat(sunDir.y, 0.0, -0.115)
    * math.lerpInvSat(sunDir.y, -0.23, -0.115)

  ac.setSkyUseV2(UseSkyV2)
  if UseSkyV2 then    
    -- Generally the same:
    ac.setSkyV2MieKCoefficient(ac.SkyRegion.All, vec3(0.686, 0.678, 0.666))
    ac.setSkyV2NumMolecules(ac.SkyRegion.All, 2.542e25)
    ac.setSkyV2MieCoefficient(ac.SkyRegion.All, 0.005)

    -- Varying with presets:
    -- local purpleAdjustment = CurrentConditions.cold
    local purpleAdjustment = sunsetK
    ac.setSkyV2Primaries(ac.SkyRegion.All, vec3(math.lerp(6.8e-7, 7.5e-7, purpleAdjustment), 5.5e-7, math.lerp(4.5e-7, 5.1e-7, purpleAdjustment)))
    ac.setSkyV2Turbidity(ac.SkyRegion.All, 4.7)
    ac.setSkyV2Rayleigh(ac.SkyRegion.All, 2.28)
    ac.setSkyV2MieDirectionalG(ac.SkyRegion.All, 0.82)
    ac.setSkyV2RefractiveIndex(ac.SkyRegion.All, 1.00029)
    ac.setSkyV2DepolarizationFactor(ac.SkyRegion.All, 0.02)
    ac.setSkyV2MieV(ac.SkyRegion.All, 3.936)
    ac.setSkyV2RayleighZenithLength(ac.SkyRegion.All, 8400)
    ac.setSkyV2MieZenithLength(ac.SkyRegion.All, 34000)
    ac.setSkyV2SunIntensityFactor(ac.SkyRegion.All, 1000.0)
    ac.setSkyV2SunIntensityFalloffSteepness(ac.SkyRegion.All, 1.5)

    -- Brightness adjustments:
    local ccClear = CurrentConditions.clear
    local ccClearSqr = CurrentConditions.clear ^ 2
    ac.setSkyV2BackgroundLight(ac.SkyRegion.All, 0.0)
    ac.setSkyV2Luminance(ac.SkyRegion.All, math.lerp(0.25, 0, deepNightK))
    ac.setSkyV2Gamma(ac.SkyRegion.All, 2.2)
    ac.setSkyV2SunShapeMult(ac.SkyRegion.All, 10 * ccClearSqr)
    ac.setSkyV2Saturation(ac.SkyRegion.All, 1.2 * ccClear)

    ac.setSkyBrightnessMult(math.lerp(0.7, 1, ccClear))

    ac.setSkyV2YOffset(ac.SkyRegion.All, 0.05)
    ac.setSkyV2YScale(ac.SkyRegion.All, 0.95)

    local rainbowIntensity = math.lerpInvSat(sunDir.y, 0.05, 0.15)
    ac.setSkyV2Rainbow(rainbowIntensity)
    ac.setSkyV2RainbowSecondary(0.2)
    ac.setSkyV2RainbowDarkening(math.lerp(1, 0.8, rainbowIntensity))
  else
    local saturation = CurrentConditions.clear
    local ccClear = CurrentConditions.clear ^ 2
    local brightness = math.max(0.001, (1 - deepNightK) * math.lerp(1, 0.5, twilightK))
    local skyColorR = math.lerp(0.4, 0.2, saturation * sunsetK * (1 - deepNightK))
    local skyColorG = math.lerp(0.6, 0.9, horizonK * CurrentConditions.cold ^ 2)
    local saturationBoost = math.lerp(1, 1 / SkySaturationBoost, saturation)
    local skyColor = rgb(skyColorR * saturationBoost, skyColorG * math.lerp(saturationBoost, 1, 0.25), 1.0)

    skyGeneralMult.color:set(brightness)
      :scale(1 - eclipseFullK * 0.9)
    skyGradient.color:setLerp(rgb(1, 1, 1), skyColor, zenithK * saturation * 0.8)
      :adjustSaturation(CurrentConditions.saturation)
      :scale((1 - eclipseFullK * 0.7) * (1 - eclipseK * 0.5))

    local sunMieIntensity = SunMieIntensity * (2 - ccClear) / 2 * (1 - eclipseK * 0.8) * (1 - eclipseFullK * 0.99)
    ac.setSkyColor(skyColor)
    ac.setSkyAnisotropicIntensity(0)
    ac.setSkyMultiScatterPhase(math.lerp(1, 0.3 + twilightK * 0.4, ccClear ^ 0.5))
    ac.setSkyZenithOffset(0.0 * (1 - zenithK))
    ac.setSkyInputYOffset(0.05)
    ac.setSkyDensity(1)
    ac.setSkyBrightnessMult(math.lerp(0.5, 1.5, dayK))
    ac.setSkySunBaseColor(math.pow(1 - deepNightK, 2) * sunMieIntensity * ccClear * SunColor)
    ac.setSkySunBrightness(SunShapeIntensity * SunIntensity * (1 - eclipseK * 0.95) * (1 - eclipseFullK * 0.99) / sunMieIntensity)
    ac.setSkySunMieExp(10)
  end

  -- Getting a few colors from sky
  ac.calculateSkyColorTo(skyTopColor, vec3Up, false, false)
  ac.calculateSkyColorTo(skySunColor, vec3(sunDir.x, math.max(sunDir.y, 0.0), sunDir.z), false, false)
end

-- Updates main scene light: could be either sun or moon light, dims down with eclipses
function applyLight()
  local eclipseLightMult = (1 - eclipseK * 0.8) -- up to 80% general occlusion
    * (1 - eclipseFullK * 0.99) -- up to 99% occlusion for real full eclipse

  -- Calculating sun color based on sky absorption (boosted at horizon)
  ac.getSkyAbsorptionTo(sunColor, sunDir)
  sunColor:pow(1 + horizonK):scale(SunIntensity * eclipseLightMult)
  sunColor.r = sunColor.r * math.lerp(1, 1.6, CurrentConditions.cold * horizonK)

  -- Initially, it starts as a sun light
  lightColor:set(sunColor)
    :scale(math.lerpInvSat(sunDir.y, -0.01, 0.04))
    :adjustSaturation(math.lerp(1, 0.4, CurrentConditions.cold * (1 - horizonK)))

  -- If it’s deep night and moon is high enough, change it to moon light
  ac.getSkyAbsorptionTo(moonAbsorption, moonDir)
  local sunThreshold = math.lerpInvSat(deepNightK, 0.7, 0.5)
  local moonThreshold = math.lerpInvSat(deepNightK, 0.7, 0.95)
  local moonLight = moonThreshold * math.lerpInvSat(moonDir.y, 0, 0.12)

  -- Calculate light direction, similar rules
  if moonLight > 0 then
    lightDir:set(moonDir)
    lightColor:set(moonAbsorption):mul(MoonColor)
      :scale(MoonLightMult * LightPollutionSkyFeaturesMult * ac.getMoonFraction() * moonLight * CurrentConditions.clear)
  else
    lightDir:set(sunDir)
  end

  -- Adjust light color
  lightColor:scale(CurrentConditions.clear)
    :mul(CurrentConditions.lightTint)
    :adjustSaturation(CurrentConditions.saturation)

  -- Clouds have their own lighting, so sun would work even if it’s below the horizon
  local cloudSunLight = math.lerpInvSat(sunDir.y, -0.23, -0.115)
  cloudLightColor:set(sunColor):scale(cloudSunLight * sunThreshold)
  cloudLightColor:setLerp(cloudLightColor, lightColor, moonLight)
  cloudLightColor:scale(CurrentConditions.clear)
  cloudLightColor:mul(CurrentConditions.lightTint)
  cloudLightColor:adjustSaturation(CurrentConditions.saturation)
  ac.setCloudsLight(lightDir, cloudLightColor, 6371e3 / 20)

  -- And godrays!
  if SunRaysCustom then
    ac.setGodraysCustomColor(lightColor)
    ac.setGodraysCustomDirection(lightDir)
    ac.setGodraysLength(0.3)
    ac.setGodraysGlareRatio(0)
    ac.setGodraysAngleAttenuation(1)
  else
    ac.setGodraysCustomColor(lightColor * SunRaysIntensity)
    ac.setGodraysCustomDirection(lightDir)
  end

  -- Dim light if light source is very low
  lightColor:scale(math.lerpInvSat(lightDir.y, 0.03, 0.06))

  -- Here is an interesting trick for sunsets: if light source is dimmed to 0 (in previous line),
  -- add some light simulating smooth lighting from sunset sky. That would allow for it to cast 
  -- smooth shadows as well.
  local extraLightNightDimming = math.lerpInvSat(deepNightK, 0.9, 0.7)
  local sunsetLightBase = math.lerpInvSat(lightDir.y, 0.03, 0.00)
  sunsetLight = sunsetLightBase * extraLightNightDimming
  if sunsetLight > 0 then
    lightDir:set(vec3(sunDir.x, 0.2, sunDir.z)):normalize()
  end
  local extraSkyLightColor = (skySunColor + sunColor * 0.05):scale(CurrentConditions.clear)
  lightColor:add(extraSkyLightColor * sunsetLight)

  -- Set extra directional ambient to point to area of the sky with the sun, but dim it down
  -- based on sunsetLight value, so this extra ambient can be replaced with main light, thus gaining shadows
  ac.setExtraAmbientColor(extraSkyLightColor * (1 - sunsetLightBase) * extraLightNightDimming)
  ac.setExtraAmbientDirection(vec3(sunDir.x, math.max(sunDir.y, 0.2), sunDir.z))

  -- Applying everything
  ac.setLightDirection(lightDir)
  ac.setLightColor(lightColor)
  if sunsetLight > 0 then
    ac.setSpecularColor(rgb())
  else
    ac.setSpecularColor(lightColor)
  end

  local heatFactor = math.lerpInvSat(lightDir.y, 0.7, 0.8) 
    * math.lerpInvSat(CurrentConditions.clear, 0.8, 1) 
    * math.lerpInvSat(CurrentConditions.clouds, 0.5, 0.2)
    * math.lerpInvSat(CurrentConditions.windSpeed, 7, 3)
  ac.setTrackHeatFactor(heatFactor)
  -- ac.debug('heatFactor', heatFactor)
  -- ac.debug('windSpeed', CurrentConditions.windSpeed)
  -- ac.debug('windDir', CurrentConditions.windDir)
end

-- Updates ambient lighting based on sky color without taking sun or moon into account
function applyAmbient()
  local ambientMult = 3 - zenithK

  ambientBaseColor
    :set(LightPollutionExtraAmbient):scale(math.lerp(1, 0.4, CurrentConditions.clear))
    :add(skyTopColor)
    :adjustSaturation(CurrentConditions.saturation)

  ambientAdjColor:set(ambientBaseColor):scale(ambientMult)
  if not ac.isBouncedLightActive() then
    ambientAdjColor:add(lightColor * (0.05 * math.saturate(lightDir.y * 2)))
  end
  ambientAdjColor:mul((CurrentConditions.lightTint + 1) / 2):adjustSaturation(CurrentConditions.saturation)
  ambientAdjColor:scale(1 + CurrentConditions.clouds * 0.6)
  ac.setAmbientColor(ambientAdjColor)

  -- Turning on headlights when it’s too dark outside
  ac.setAiHeadlights(ambientAdjColor:value() < 1)

  -- Adjusting fake shadows under cars
  ac.setWeatherFakeShadowOpacity(1)
  ac.setWeatherFakeShadowConcentrarion(math.lerp(0.3, 1, math.max(deepNightK, 0.3 * zenithK * CurrentConditions.clear)))
end

-- For smooth transition
local sceneBrightnessValue = 1
local sceneBrightnessDownDelay = 0

-- The idea here is to use scene brightness for adapting camera to darkness in tunnels
-- unlike auto-exposure approach, it would be smoother and wouldn’t jump as much if camera
-- simply rotates and, for example, looks down in car interior
local function getSceneBrightness(dt)
  local aoNow = ac.sampleCameraAO()  -- at the moment, using those extra VAO samples to estimate
    -- scene brightness. TODO: add something better like making a shot upwards?
  if aoNow < sceneBrightnessValue then
    if sceneBrightnessDownDelay < 0 then
      sceneBrightnessValue = math.max(aoNow, sceneBrightnessValue - dt * 0.5)
    else
      sceneBrightnessDownDelay = sceneBrightnessDownDelay - 4 * dt * (sceneBrightnessValue - aoNow)
    end
  else
    sceneBrightnessValue = math.min(aoNow, sceneBrightnessValue + dt)
    sceneBrightnessDownDelay = 1
  end
  return sceneBrightnessValue
end

-- There are two problems fake exposure solves:
-- 1. We need days to be much brighter than nights, to such an extend that lights wouldn’t be visible in sunny days.
--    That also hugely helps with performance.
-- 2. In dark tunnels, brightness should go up, revealing those lights and overexposing everything outside.
-- Ideally, HDR should’ve solved that task, but it introduces some other problems: for example, emissives go too dark,
-- or too bright during the day. That’s why instead this thing uses fake exposure, adjusting brightness a bit, but 
-- also, adjusting intensity of all dynamic lights and emissives to make it seem like the difference is bigger.
function applyFakeExposure(dt)
  local lightBrightnessRaw = ambientAdjColor:value() * 1.5 + lightColor:value() * math.saturate(lightDir.y * 1.4) * 0.5

  local aoK = math.lerpInvSat(getSceneBrightness(dt), 0.1, 0.5)
  lightBrightnessRaw = lightBrightnessRaw * aoK

  if initialSet > 0 then
    lightBrightness = lightBrightnessRaw
    initialSet = initialSet - 1
  elseif lightBrightness < lightBrightnessRaw then
    lightBrightness = math.min(lightBrightness + dt * AdaptationSpeed, lightBrightnessRaw)
  elseif lightBrightness > lightBrightnessRaw then
    lightBrightness = math.max(lightBrightness - dt * AdaptationSpeed, lightBrightnessRaw)
  end

  local sceneBrightness = 5 / (lightBrightness + 5)
  local lightsMult = math.sqrt(math.max(sceneBrightness - 0.2, 0))

  -- ac.debug('sceneBrightness', sceneBrightness)
  -- ac.debug('lightsMult', lightsMult)

  if ac.isPpActive() then
    -- with post-processing, adjusting scene brightness and post-processing brightness
    ac.setBrightnessMult(sceneBrightness * SceneBrightnessMultPP)
    ac.setOverallSkyBrightnessMult(1)
    ppBrightnessCorrection.value = FilterBrightnessMultPP
  else
    -- without post-processing, we can only adjust scene brightness, but that’s enough
    ac.setBrightnessMult(sceneBrightness * SceneBrightnessMultNoPP)
    ac.setOverallSkyBrightnessMult(1)
  end

  ac.setWeatherLightsMultiplier(lightsMult) -- how bright are lights
  ac.setGlowBrightness(lightsMult * 0.18) -- how bright are those distant emissive glows
  ac.setEmissiveMultiplier(0.9 + lightsMult * 0.3) -- how bright are emissives
  ac.setWeatherTrackLightsMultiplierThreshold(0.01) -- let make lights switch on early for smoothness

  local baseAmbient = 0.04 * lightsMult -- base ambient adds a bit of extra ambient lighting not
    -- affected by ambient occlusion, so even pitch black tunnels become a tiny bit lit after “eye” adapts.
  baseAmbientColor:set(baseAmbient, baseAmbient, baseAmbient)
  ac.setBaseAmbientColor(baseAmbientColor)
end

-- Updates fog, fog color is based on ambient color, so sometimes this fog can get red with sunsets
function applyFog()
  local ccFog = CurrentConditions.fog
  local fogSqrt = ccFog ^ 0.5
  local fog2 = math.saturate(ccFog * 2)
  fogColor:setLerp(ambientBaseColor * CurrentConditions.fogTint, skySunColor, (1 - ccFog) * 0.5)
  ac.setFogAlgorithm(ac.FogAlgorithm.New)
  ac.setFogBacklitExponent(12)
  ac.setFogBacklitMultiplier((1 - ccFog * 0.8) ^ 2)
  ac.setFogExponent(math.lerp(1, 0.5, fogSqrt))
  ac.setFogHeight(0)
  ac.setFogDensity(math.lerp(0.15 * (1 - deepNightK), 1, ccFog))
  ac.setFogColor(fogColor)
  ac.setFogBlend(1)
  ac.setFogDistance(math.lerp(5000, 150, fogSqrt))
  ac.setSkyFogMultiplier(fogSqrt)
  ac.setHorizonFogMultiplier(
    math.lerp(0.5, 1, fog2), 
    math.lerp(10, 2, ccFog), 
    math.lerp(1, 0.95, fog2))
end

-- Updates stuff like moon, stars and planets
function applySkyFeatures()
  local mult = ((0.25 / math.max(lightBrightness, 0.05)) ^ 2) * LightPollutionSkyFeaturesMult 
    * (CurrentConditions.clear ^ 4)

  ac.setSkyMoonMieMultiplier(0.05 * (1 - CurrentConditions.clear))
  ac.setSkyMoonBaseColor(MoonColor * (0.2 + deepNightK))
  ac.setSkyMoonBrightness(math.lerp(50, 10 - CurrentConditions.clear * 9, deepNightK ^ 0.1))
  ac.setSkyMoonOpacity(math.lerp(0.1, 1, deepNightK) * CurrentConditions.clear * LightPollutionSkyFeaturesMult)
  ac.setSkyMoonMieExp(120)
  ac.setSkyMoonDepthSkip(true)

  ac.setSkyStarsColor(MoonColor)
  ac.setSkyStarsBrightness(mult)
  ac.setSkyStarsSaturation(0.2 * CurrentConditions.saturation)
  ac.setSkyStarsExponent(3 + lightBrightness + 10 * LightPollutionValue) -- easiest way to take light pollution into account is
    -- to raise stars map in power: with stars map storing values from 0 to 1, it gets rid of dimmer stars only leaving
    -- brightest ones

  ac.setSkyPlanetsBrightness(20)
  ac.setSkyPlanetsOpacity(mult)
  ac.setSkyPlanetsSizeBase(0.01)
  ac.setSkyPlanetsSizeVariance(0.7)
  ac.setSkyPlanetsSizeMultiplier(10)
end

-- Thing thing disables shadows if it’s too cloudy or light is not bright enough, or downsizes shadow map resolution
-- making shadows look blurry
function applyAdaptiveShadows()
  if lightColor.g < 0.1 then -- it’s a common approach to use green component to estimate color brightness, not as accurate, but we don’t
      -- need accuracy here
    ac.setShadows(ac.ShadowsState.Off)
  else
    if CurrentConditions.clear > 0.2 and sunsetLight == 0 then
      ac.resetShadowsResolution()
      ac.setShadows(ac.ShadowsState.On)
    elseif CurrentConditions.clear > 0.01 then
      ac.setShadowsResolution(256)
      ac.setShadows(ac.ShadowsState.On)
    else
      ac.setShadows(ac.ShadowsState.Off)
    end
  end
end

-- Creates generic cloud material
function createGenericCloudMaterial()
  local ret = ac.SkyCloudMaterial()
  ret.baseColor = rgb(0.15, 0.15, 0.15)
  ret.useSceneAmbient = false
  ret.ambientConcentration = 0.35
  ret.frontlitMultiplier = 1
  ret.frontlitDiffuseConcentration = 0.45
  ret.backlitMultiplier = 0
  ret.backlitExponent = 30
  ret.backlitOpacityMultiplier = 0.6
  ret.backlitOpacityExponent = 1.7
  ret.specularPower = 1
  ret.specularExponent = 5
  return ret
end

-- Global cloud materials
CloudMaterials = {
  Main = createGenericCloudMaterial(),
  Bottom = createGenericCloudMaterial(),
  Hovering = createGenericCloudMaterial(),
}

-- Initialization for some static values
CloudMaterials.Main.contourExponent = 8
CloudMaterials.Main.contourIntensity = 0.1
CloudMaterials.Main.ambientConcentration = 0.2
CloudMaterials.Bottom.specularPower = 0
CloudMaterials.Bottom.specularExponent = 1
CloudMaterials.Bottom.ambientConcentration = 0.25
CloudMaterials.Hovering.frontlitMultiplier = 0.2
CloudMaterials.Hovering.frontlitDiffuseConcentration = 0.4
CloudMaterials.Hovering.ambientConcentration = 0.1
CloudMaterials.Hovering.backlitMultiplier = 0.2
CloudMaterials.Hovering.backlitOpacityMultiplier = 0
CloudMaterials.Hovering.backlitOpacityExponent = 1
CloudMaterials.Hovering.backlitExponent = 5
CloudMaterials.Hovering.specularPower = 0
CloudMaterials.Hovering.specularExponent = 1

-- Update cloud materials for chanding lighting conditions
function updateCloudMaterials()
  ac.setLightShadowOpacity((0.6 + 0.3 * CurrentConditions.clouds) * (sunsetLight > 0 and 0.3 or 1))

  local main = CloudMaterials.Main
  local deepNightAdjK = math.lerpInvSat(deepNightK, 0.5, 0.9)
  main.ambientColor:set(skySunColor):scale(math.lerp(0, 0.2, sunsetK))
    :add(lightColor:clone():scale(0.1 * zenithK * math.lerp(0.4, 0.2, sunsetK)))
    :add(skyTopColor:clone():adjustSaturation(0.5) * math.lerp(UseSkyV2 and 4 or 2, 0.6, deepNightK))
    :add(LightPollutionExtraAmbient)
  main.ambientConcentration = math.lerp(0.3, 0, deepNightK)
  main.extraDownlit
    :set(skySunColor):scale(math.min(sunsetK, 0.2) * CurrentConditions.clear)
  main.frontlitMultiplier = math.lerp(0.4, 0.5, deepNightAdjK)
  main.frontlitDiffuseConcentration = math.lerp(math.lerp(0.67, 1, horizonK), 0.5, deepNightAdjK)
  main.backlitMultiplier = math.lerp(math.lerp(0.5, 2, deepNightAdjK), 1, horizonK)
  main.backlitOpacityMultiplier = math.lerp(0.93, 0.8, horizonK)
  main.backlitOpacityExponent = math.lerp(2, 3, horizonK)
  main.backlitExponent = math.lerp(5, 10, horizonK)
  main.specularPower = math.lerp(1, 0.3, deepNightAdjK)
  main.specularExponent = math.lerp(10, 4, math.max(deepNightAdjK, horizonK))
  main.fogMultiplier = math.lerp(0.1, 1, math.saturate(CurrentConditions.fog * 2))

  local bottom = CloudMaterials.Bottom
  bottom.ambientColor:set(main.ambientColor)
  bottom.ambientConcentration = main.ambientConcentration
  bottom.extraDownlit:set(main.extraDownlit)
  bottom.frontlitMultiplier = main.frontlitMultiplier
  bottom.frontlitDiffuseConcentration = main.frontlitDiffuseConcentration
  bottom.backlitMultiplier = math.min(1, main.backlitMultiplier * 1.6)
  bottom.backlitOpacityMultiplier = main.backlitOpacityMultiplier * 0.9
  bottom.backlitOpacityExponent = main.backlitOpacityExponent
  bottom.backlitExponent = main.backlitExponent
  bottom.fogMultiplier = main.fogMultiplier
  
  local hovering = CloudMaterials.Hovering
  hovering.ambientColor:set(main.ambientColor)
  hovering.ambientConcentration = main.ambientConcentration
  hovering.fogMultiplier = math.lerp(0.5, 1, CurrentConditions.fog)
end

