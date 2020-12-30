--------
-- Most of weather stuff happens here: it sets lighting, fog, scene brightness and prepares a few globally defined
-- cloud materials.
--------

-- Global weather values
nightK = 0 -- 1 at nights, 0 during the day
sunDir = vec3(0, 1, 0)

-- Various local variables, changing with each update, something easy to deal with things. There is 
-- no need to edit any of those values if you want to change anything, please proceed further to
-- actual functions setting that stuff
local sunsetK = 0 -- grows when sun is at sunset stage
local horizonK = 0 -- grows when sun is near horizon
local eclipseK = 0 -- starts growing when moon touches sun, 1 at total eclipse
local eclipseFullK = 0 -- starts growing when moon covers sun at 95%, 1 at total eclipse, used for heavy darkening of sky and sun light
local lightBrightness = 1
local belowHorizonCorrection = 0
local initialSet = 3
local moonDir = vec3(0, 1, 0)
local sunColor = rgb(1, 1, 1)
local skyTopColor = rgb(1, 1, 1)
local skySunColor = rgb(1, 1, 1)
local lightDir = vec3(0, 1, 0)
local lightColor = rgb(0, 0, 0)

-- Sky gradient covering everything, for sky-wide color correction
local skyGeneralMult = nil
skyGeneralMult = ac.SkyExtraGradient()
skyGeneralMult.isAdditive = false
skyGeneralMult.sizeFull = 2
skyGeneralMult.sizeStart = 2
skyGeneralMult.direction = vec3(0, 1, 0)
ac.addSkyExtraGradient(skyGeneralMult)

-- Another sky gradient for cloudy and foggy look
local skyCoverAddition = nil
skyCoverAddition = ac.SkyExtraGradient()
skyCoverAddition.isAdditive = true
skyCoverAddition.sizeFull = 2
skyCoverAddition.sizeStart = 2
skyCoverAddition.direction = vec3(0, 1, 0)
ac.addSkyExtraGradient(skyCoverAddition)

-- Custom post-processing brightness adjustment
local ppBrightnessCorrection = ac.ColorCorrectionBrightness()
ac.addWeatherColorCorrection(ppBrightnessCorrection)

-- A bit of optimization to reduce garbage generated per frame
local vec3Up = vec3(0, 1, 0)

-- Updates sky color
function applySky()
  ac.getSunDirectionTo(sunDir)
  ac.getMoonDirectionTo(moonDir)

  nightK = math.lerpInvSat(sunDir.y, 0.05, -0.2)

  -- Eclipse coefficients. You can test full eclipse with Brasov track on 08/11/1999:
  -- https://www.racedepartment.com/downloads/brasov-romania.28239/
  -- For some unknown reason, eclipseK is somewhat unstable with time moving regularly,
  -- a bit of smoothing helps to fix the problem:
  local eclipseNewK = math.lerpInvSat(math.dot(sunDir, moonDir), 0.99965, 0.999999)
  eclipseK = math.lerp(eclipseK, eclipseNewK, math.abs(eclipseNewK - eclipseK) < 0.01 and 0.15 or 1)
  eclipseFullK = math.pow(math.lerpInvSat(eclipseK, 0.95, 1), 2)
  
  sunsetK = math.lerpInvSat(math.max(0, sunDir.y), 0.12, 0)
  horizonK = math.lerpInvSat(math.abs(sunDir.y), 0.4, 0.12)

  -- Generally the same:
  ac.setSkyV2MieKCoefficient(ac.SkyRegion.All, vec3(0.686, 0.678, 0.666))
  ac.setSkyV2NumMolecules(ac.SkyRegion.All, 2.542e25)
  ac.setSkyV2MieCoefficient(ac.SkyRegion.All, 0.005 * CurrentConditions.clear)

  -- Few sky adjustments
  local darkNightSky = math.max(nightK, eclipseFullK * 0.7) -- sky getting black
  local purpleAdjustment = sunsetK -- slightly alter color for sunsets
  local brightDayAdjustment = math.lerpInvSat(math.max(0, sunDir.y), 0.2, 0.6) -- make sky clearer during the day
  local skyVisibility = math.sqrt((1 - CurrentConditions.fog) * CurrentConditions.clear)

  -- Varying with presets:
  ac.setSkyV2Primaries(ac.SkyRegion.All, vec3(6.8e-7, 5.5e-7, math.lerp(4.5e-7, 5.1e-7, purpleAdjustment)))
  ac.setSkyV2Turbidity(ac.SkyRegion.All, 2.0)
  ac.setSkyV2Rayleigh(ac.SkyRegion.All, math.lerp(3.0, 1.0, brightDayAdjustment))
  ac.setSkyV2MieDirectionalG(ac.SkyRegion.All, 0.8)
  ac.setSkyV2RefractiveIndex(ac.SkyRegion.All, 1.0003)
  ac.setSkyV2DepolarizationFactor(ac.SkyRegion.All, 0.035)
  ac.setSkyV2MieV(ac.SkyRegion.All, 4.0)
  ac.setSkyV2RayleighZenithLength(ac.SkyRegion.All, 8400)
  ac.setSkyV2MieZenithLength(ac.SkyRegion.All, 1.25e3)
  ac.setSkyV2SunIntensityFactor(ac.SkyRegion.All, 1000.0)
  ac.setSkyV2SunIntensityFalloffSteepness(ac.SkyRegion.All, 1.5)

  -- Boosting deep blue at nights
  local deepBlue = nightK ^ 2
  skyGeneralMult.color
    :set(math.lerp(1, 0.2, deepBlue), math.lerp(1, 0.8, deepBlue), math.lerp(1, 2, deepBlue))
    :mul(CurrentConditions.tint)
    :scale(skyVisibility)

  -- Covering layer
  ac.calculateSkyColorNoGradientsTo(skyTopColor, vec3Up, false, false)
  skyCoverAddition.color
    :set(math.lerp(1, 0.2, deepBlue), math.lerp(1, 0.8, deepBlue) * 1.1, math.lerp(1, 2, deepBlue) * 1.2)
    :mul(CurrentConditions.tint)
    :scale(skyTopColor.g * (1 - skyVisibility))

  -- Brightness adjustments:
  ac.setSkyV2BackgroundLight(ac.SkyRegion.All, 0.0)
  ac.setSkyV2Luminance(ac.SkyRegion.All, math.lerp(0, 0.3, math.pow(1 - darkNightSky, 4)))
  ac.setSkyV2Gamma(ac.SkyRegion.All, 2.5)
  ac.setSkyV2SunShapeMult(ac.SkyRegion.All, 10 * (CurrentConditions.clear ^ 2))
  ac.setSkyV2Saturation(ac.SkyRegion.All, math.lerp(0.5, 1.2, CurrentConditions.clear))

  ac.setSkyBrightnessMult(1)
  ac.setSkyV2YOffset(ac.SkyRegion.All, 0.1)
  ac.setSkyV2YScale(ac.SkyRegion.All, 0.9)

  local rainbowIntensity = math.saturateN(CurrentConditions.rain * CurrentConditions.clear * 10) * math.lerpInvSat(sunDir.y, 0.02, 0.06)
  ac.setSkyV2Rainbow(rainbowIntensity)
  ac.setSkyV2RainbowSecondary(0.2)
  ac.setSkyV2RainbowDarkening(math.lerp(1, 0.8, rainbowIntensity))

  -- Getting a few colors from sky
  ac.calculateSkyColorTo(skyTopColor, vec3Up, false, false)
  ac.calculateSkyColorTo(skySunColor, vec3(sunDir.x, math.max(sunDir.y, 0.0), sunDir.z), false, false)

  -- Small adjustment for balancing
  skyTopColor:scale(0.25)
  skySunColor:scale(0.25)
end

-- Updates main scene light: could be either sun or moon light, dims down with eclipses
local moonAbsorption = rgb()
local cloudLightColor = rgb()
local godraysColor = rgb()
function applyLight()
  local eclipseLightMult = (1 - eclipseK * 0.8) -- up to 80% general occlusion
    * (1 - eclipseFullK * 0.98) -- up to 98% occlusion for real full eclipse

  -- Calculating sun color based on sky absorption (boosted at horizon)
  ac.getSkyAbsorptionTo(sunColor, sunDir)
  sunColor:pow(1 + horizonK):mul(SunColor):scale(SunIntensity * eclipseLightMult * math.lerp(1, 2, horizonK))

  -- Initially, it starts as a sun light
  lightColor:set(sunColor)

  -- If it’s deep night and moon is high enough, change it to moon light
  ac.getSkyAbsorptionTo(moonAbsorption, moonDir)
  local sunThreshold = math.lerpInvSat(nightK, 0.7, 0.5)
  local moonThreshold = math.lerpInvSat(nightK, 0.7, 0.95)
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
    :adjustSaturation(CurrentConditions.saturation)
    :mul(CurrentConditions.tint)

  -- Clouds have their own lighting, so sun would work even if it’s below the horizon
  local cloudSunLight = math.lerpInvSat(sunDir.y, -0.23, -0.115)
  cloudLightColor:set(sunColor):scale(cloudSunLight * sunThreshold)
  cloudLightColor:setLerp(cloudLightColor, lightColor, moonLight)
  cloudLightColor:scale(CurrentConditions.clear)
  cloudLightColor:adjustSaturation(CurrentConditions.saturation)
  cloudLightColor:mul(CurrentConditions.tint)
  ac.setCloudsLight(lightDir, cloudLightColor, 6371e3 / 20)

  -- Dim light if light source is very low
  lightColor:scale(math.lerpInvSat(lightDir.y, -0.03, 0) * SunLightIntensity)

  -- Dim godrays even more
  godraysColor:set(lightColor):scale(math.lerpInvSat(lightDir.y, 0.01, 0.02))

  -- And godrays!
  if SunRaysCustom then
    ac.setGodraysCustomColor(godraysColor)
    ac.setGodraysCustomDirection(lightDir)
    ac.setGodraysLength(0.3)
    ac.setGodraysGlareRatio(0)
    ac.setGodraysAngleAttenuation(1)
  else
    ac.setGodraysCustomColor(godraysColor:scale(SunRaysIntensity))
    ac.setGodraysCustomDirection(lightDir)
  end

  -- Adjust light dir for case where sun is below horizon, but a bit is still visible
  belowHorizonCorrection = math.lerpInvSat(lightDir.y, 0.02, 0.0)
  lightDir.y = math.lerp(lightDir.y, 0.01, belowHorizonCorrection ^ 2)

  -- Applying everything
  ac.setLightDirection(lightDir)
  ac.setLightColor(lightColor)
  ac.setSpecularColor(lightColor)
end

-- Updates ambient lighting based on sky color without taking sun or moon into account
local ambientBaseColor = rgb(1, 1, 1)
local ambientAdjColor = rgb(1, 1, 1)
local ambientExtraColor = rgb()
function applyAmbient()
  -- Base ambient color: uses sky color at zenith with extra addition of light pollution, adjusted for conditions
  ambientBaseColor
    :set(LightPollutionExtraAmbient):scale(math.lerp(1, 0.4, CurrentConditions.clear))
    :add(skyTopColor)
    :adjustSaturation(CurrentConditions.saturation)

  -- Actual scene ambient color
  ambientAdjColor:set(ambientBaseColor)
  if not ac.isBouncedLightActive() then
    -- If bounced light from Extra FX is disabled, let’s mix in a bit of sun light
    ambientAdjColor:add(lightColor * (0.01 * math.saturate(lightDir.y * 2)))
  end
  ambientAdjColor:scale(AmbientLightIntensity):adjustSaturation(math.lerp(0.25, 1.5, horizonK))
  ac.setAmbientColor(ambientAdjColor)

  -- Extra ambient for sunsets, to take into account sky glow even when sun is below horizon
  local extraAmbientMult = sunsetK * (1 - nightK) * CurrentConditions.clear
  if extraAmbientMult > 0 then
    ambientExtraColor
      :set(skySunColor)
      :adjustSaturation(CurrentConditions.saturation)
      :mul(rgb.tmp():set(CurrentConditions.tint):add(1):scale(0.5))
      :scale((1 + CurrentConditions.clouds * 0.6) * extraAmbientMult * 2)
    ac.setExtraAmbientColor(ambientExtraColor)
    ac.setExtraAmbientDirection(vec3(sunDir.x, math.max(sunDir.y, 0.1), sunDir.z))
  else
    ambientExtraColor:set(0)
    ac.setExtraAmbientColor(ambientExtraColor)
  end

  -- Turning on headlights when it’s too dark outside
  ac.setAiHeadlights(ambientAdjColor:value() < 1)

  -- Adjusting fake shadows under cars
  ac.setWeatherFakeShadowOpacity(1)
  ac.setWeatherFakeShadowConcentration(math.lerp(0.3, 1, math.max(nightK, 0.3 * CurrentConditions.clear)))
end

-- Updates fog, fog color is based on ambient color, so sometimes this fog can get red with sunsets
local cameraPos = vec3(0, 0, 0)
local cameraPosPrev = vec3(0, 0, 0)
local skyHorizonColor = rgb(1, 1, 1)
local groundYAveraged = math.NaN 
local fogNoise = LowFrequency2DNoise:new{ frequency = 0.003 }
function applyFog(dt)
  ac.calculateSkyColorTo(skyHorizonColor, vec3(sunDir.z, 0, -sunDir.x), false, false)
  ac.setFogColor(skyHorizonColor)

  local ccFog = CurrentConditions.fog
  local fogDistance = math.lerp(2000, 90, ccFog)
  local fogHorizon = math.saturate(math.lerp(0.5, 2, ccFog))
  local fogDensity = math.lerp(0.1, 0.7, ccFog)
  local fogExponent = math.lerp(0.6, 0.8, fogNoise:get(cameraPos))

  local groundY = ac.getGroundYApproximation()
  ac.getCameraPositionTo(cameraPos)
  if math.isNaN(groundYAveraged) or not cameraPos:closerToThan(cameraPosPrev, 100) then
    groundYAveraged = groundY
  else
    groundYAveraged = math.applyLag(groundYAveraged, groundY, 0.995, dt)
  end
  cameraPosPrev:set(cameraPos)

  ac.setFogExponent(fogExponent)
  ac.setFogDensity(fogDensity)
  ac.setFogDistance(fogDistance)
  ac.setFogHeight(groundYAveraged - fogDistance)
  ac.setSkyFogMultiplier(0.5 * ccFog)
  ac.setHorizonFogMultiplier(fogHorizon, math.lerp(8, 4, ccFog), 0.95)

  ac.setFogBlend(1)
  ac.setFogBacklitExponent(12)
  ac.setFogBacklitMultiplier(math.lerp(0.2, 1, ccFog * horizonK) * FogBacklitIntensity)
end

-- Calculates heat factor for wobbling air above heated track and that wet road/mirage effect
function applyHeatFactor()
  local heatFactor = math.lerpInvSat(sunDir.y, 0.7, 0.8) 
    * math.lerpInvSat(CurrentConditions.clear, 0.8, 1) 
    * math.lerpInvSat(CurrentConditions.clouds, 0.5, 0.2)
    * math.lerpInvSat(CurrentConditions.windSpeed, 7, 3)
  ac.setTrackHeatFactor(heatFactor)
end

-- Updates stuff like moon, stars and planets
function applySkyFeatures()
  local brightness = ((0.25 / math.max(lightBrightness, 0.05)) ^ 2) * LightPollutionSkyFeaturesMult 
    * (CurrentConditions.clear ^ 4) * 0.1

  ac.setSkyMoonMieMultiplier(0.05 * (1 - CurrentConditions.clear))
  ac.setSkyMoonBaseColor(MoonColor * (0.2 + nightK))
  ac.setSkyMoonBrightness(math.lerp(50, 10 - CurrentConditions.clear * 9, nightK ^ 0.1))
  ac.setSkyMoonOpacity(math.lerp(0.1, 1, nightK) * CurrentConditions.clear * LightPollutionSkyFeaturesMult)
  ac.setSkyMoonMieExp(120)
  ac.setSkyMoonDepthSkip(true)

  ac.setSkyStarsColor(MoonColor)
  ac.setSkyStarsBrightness(brightness)
  ac.setSkyStarsSaturation(0.2 * CurrentConditions.saturation)
  ac.setSkyStarsExponent(3 + lightBrightness + 10 * LightPollutionValue) -- easiest way to take light pollution into account is
    -- to raise stars map in power: with stars map storing values from 0 to 1, it gets rid of dimmer stars only leaving
    -- brightest ones

  ac.setSkyPlanetsBrightness(20)
  ac.setSkyPlanetsOpacity(brightness)
  ac.setSkyPlanetsSizeBase(0.01)
  ac.setSkyPlanetsSizeVariance(0.7)
  ac.setSkyPlanetsSizeMultiplier(10)
end

-- Thing thing disables shadows if it’s too cloudy or light is not bright enough, or downsizes shadow map resolution
-- making shadows look blurry
function applyAdaptiveShadows()
  if lightColor.g < 0.01 then -- it’s a common approach to use green component to estimate color brightness, not as accurate, but we don’t
      -- need accuracy here
    ac.setShadows(ac.ShadowsState.Off)
  elseif belowHorizonCorrection > 0 then
    if belowHorizonCorrection > 0.8 then
      ac.setShadowsResolution(256)
    elseif belowHorizonCorrection > 0.6 then
      ac.setShadowsResolution(384)
    elseif belowHorizonCorrection > 0.4 then
      ac.setShadowsResolution(512)
    elseif belowHorizonCorrection > 0.2 then
      ac.setShadowsResolution(768)
    else
      ac.setShadowsResolution(1024)
    end
    ac.setShadows(ac.ShadowsState.On)
  else 
    ac.resetShadowsResolution()
    ac.setShadows(ac.ShadowsState.On)
  end
end

-- For smooth transition
local sceneBrightnessValue = 1
local sceneBrightnessDownDelay = 0

-- The idea here is to use scene brightness for adapting camera to darkness in tunnels
-- unlike auto-exposure approach, it would be smoother and wouldn’t jump as much if camera
-- simply rotates and, for example, looks down in car interior
local function getSceneBrightness(dt)
  local aoNow = ac.getCameraLookOcclusion()  -- at the moment, using those extra VAO samples to estimate
    -- scene brightness. TODO: add something better like making a shot upwards?

  if aoNow < sceneBrightnessValue then
    if sceneBrightnessDownDelay < 0 then
      sceneBrightnessValue = math.max(aoNow, sceneBrightnessValue - dt * 2)
    else
      sceneBrightnessDownDelay = sceneBrightnessDownDelay - 10 * dt * (sceneBrightnessValue - aoNow)
    end
  else
    sceneBrightnessValue = math.min(aoNow, sceneBrightnessValue + 4 * dt)
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

  if ac.isPpActive() then
    -- with post-processing, adjusting scene brightness and post-processing brightness
    ac.setBrightnessMult(sceneBrightness * SceneBrightnessMultPP)
    ac.setOverallSkyBrightnessMult(1)
    ppBrightnessCorrection.value = math.lerp(2, 1, sceneBrightness) * FilterBrightnessMultPP
  else
    -- without post-processing, we can only adjust scene brightness, but that’s enough
    ac.setBrightnessMult(sceneBrightness * SceneBrightnessMultNoPP)
    ac.setOverallSkyBrightnessMult(1)
  end

  ac.setWeatherLightsMultiplier(lightsMult) -- how bright are lights
  ac.setGlowBrightness(lightsMult * 0.18) -- how bright are those distant emissive glows
  ac.setEmissiveMultiplier(0.9 + lightsMult * 0.3) -- how bright are emissives
  ac.setWeatherTrackLightsMultiplierThreshold(0.01) -- let make lights switch on early for smoothness

  ac.setBaseAmbientColor(vec3.tmp():set(0.04 * lightsMult)) -- base ambient adds a bit of extra ambient lighting not
    -- affected by ambient occlusion, so even pitch black tunnels become a tiny bit lit after “eye” adapts.
end

-- Creates generic cloud material
function createGenericCloudMaterial(props)
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

  if props ~= nil then
    for k, v in pairs(props) do
      ret[k] = v
    end
  end

  return ret
end

-- Global cloud materials
CloudMaterials = {}

-- Initialization for some static values
CloudMaterials.Main = createGenericCloudMaterial({ 
  contourExponent = 4,
  contourIntensity = 0.2,
  ambientConcentration = 0.1,  
  frontlitDiffuseConcentration = 0.8,
  backlitMultiplier = 4,
  backlitOpacityMultiplier = 0.8,
  backlitOpacityExponent = 3,
  backlitExponent = 15,
  specularExponent = 2,
  receiveShadowsOpacity = 0.9,
  fogMultiplier = 1
})

CloudMaterials.Bottom = createGenericCloudMaterial({
  contourExponent = 4,
  contourIntensity = 0.1,
  ambientConcentration = 0.1,  
  frontlitDiffuseConcentration = 0.5,
  backlitMultiplier = 4,
  backlitOpacityMultiplier = 0.8,
  backlitOpacityExponent = 3,
  backlitExponent = 15,
  specularPower = 0,
  specularExponent = 1,
  receiveShadowsOpacity = 0.9,
  fogMultiplier = 1
})

CloudMaterials.Hovering = createGenericCloudMaterial({
  frontlitMultiplier = 1,
  frontlitDiffuseConcentration = 0.3,
  ambientConcentration = 0.1,
  backlitMultiplier = 2,
  backlitOpacityMultiplier = 0.8,
  backlitOpacityExponent = 3,
  backlitExponent = 20,
  specularPower = 0,
  specularExponent = 1,
  fogMultiplier = 1
})

CloudMaterials.Spread = createGenericCloudMaterial({
  frontlitMultiplier = 1,
  frontlitDiffuseConcentration = 0,
  ambientConcentration = 0,
  backlitMultiplier = 4,
  backlitOpacityMultiplier = 0,
  backlitOpacityExponent = 1,
  backlitExponent = 20,
  specularPower = 0,
  specularExponent = 1,
  fogMultiplier = 1
})

-- Update cloud materials for chanding lighting conditions
function updateCloudMaterials()
  ac.setLightShadowOpacity(0.6 + 0.3 * CurrentConditions.clouds)

  local ccClear = CurrentConditions.clear
  local ccCloudsDensity = CurrentConditions.cloudsDensity
  local clearSunset = sunsetK * ccClear
  local main = CloudMaterials.Main
  main.ambientColor
    :set(skyTopColor):adjustSaturation(math.lerp(0.8, 2, clearSunset)):scale(math.lerp(3.2, 1.6, clearSunset))
    -- :add(lightColor:clone():scale(0.1 * math.lerp(0.4, 0.2, sunsetK)))
    -- :add(LightPollutionExtraAmbient)
  main.ambientConcentration = math.lerp(0.2, 0, nightK)
  main.extraDownlit:set(skySunColor):scale(math.min(sunsetK, 0.2) * ccClear)
  main.frontlitMultiplier = math.lerp(1, 0.5, nightK)
  main.specularPower = math.lerp(1, 0.1, nightK)
  main.frontlitDiffuseConcentration = math.lerp(0.3, 0.8, sunsetK)

  -- Wet look
  local colorValue = math.lerp(0.15, 0.05, ccCloudsDensity)
  main.baseColor:set(colorValue, colorValue, colorValue)
  main.ambientConcentration = math.lerp(main.ambientConcentration, 0.5, ccCloudsDensity)
  main.frontlitDiffuseConcentration = math.lerp(main.frontlitDiffuseConcentration, 1.0, ccCloudsDensity)
  main.specularPower = math.lerp(main.frontlitDiffuseConcentration, 0, ccCloudsDensity)

  local bottom = CloudMaterials.Bottom
  bottom.baseColor:set(main.baseColor)
  bottom.ambientColor:set(main.ambientColor)
  bottom.ambientConcentration = main.ambientConcentration * 0.5
  bottom.extraDownlit:set(main.extraDownlit)
  bottom.frontlitMultiplier = main.frontlitMultiplier
  bottom.frontlitDiffuseConcentration = main.frontlitDiffuseConcentration
  bottom.frontlitDiffuseConcentration = main.frontlitDiffuseConcentration
  bottom.specularPower = main.specularPower
  bottom.contourIntensity = main.contourIntensity
  
  local hovering = CloudMaterials.Hovering
  hovering.ambientColor:set(main.ambientColor)
  
  local spread = CloudMaterials.Spread
  spread.ambientColor:set(main.ambientColor)
end

