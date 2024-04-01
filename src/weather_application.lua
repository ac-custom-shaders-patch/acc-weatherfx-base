--------
-- Most of weather stuff happens here: it sets lighting, fog, scene brightness and prepares a few globally defined
-- cloud materials.
--------

-- Various local variables, changing with each update, something easy to deal with things. There is 
-- no need to edit any of those values if you want to change anything, please proceed further to
-- actual functions setting that stuff
local sunsetK = 0 -- grows when sun is at sunset stage
local horizonK = 0 -- grows when sun is near horizon
local eclipseK = 0 -- starts growing when moon touches sun, 1 at total eclipse
local lightBrightness = 1
local belowHorizonCorrection = 0
local initialSet = 3
local cameraOcclusion = 1
local sunColor = rgb(1, 1, 1)
local skyTopColor = rgb(1, 1, 1)
local skySunColor = rgb(1, 1, 1)
local lightDir = vec3(0, 1, 0)
local lightColor = rgb(0, 0, 0)
local fogRangeMult = 1
local realNightK = 0

-- For smooth transition
local sceneBrightnessValue = 1
local sceneBrightnessDownDelay = 0

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

-- Gradient to boost brightness towards horizon
local skyHorizonAddition = nil
skyHorizonAddition = ac.SkyExtraGradient()
skyHorizonAddition.isAdditive = true
skyHorizonAddition.sizeFull = 0.8
skyHorizonAddition.sizeStart = 1.2
skyHorizonAddition.direction = vec3(0, -1, 0)
ac.addSkyExtraGradient(skyHorizonAddition)

-- Gradient to boost brightness towards horizon
local cityHaze = nil
cityHaze = ac.SkyExtraGradient()
cityHaze.isAdditive = false
cityHaze.sizeFull = 1
cityHaze.sizeStart = 1.2
cityHaze.exponent = 20
cityHaze.direction = vec3(0, -1, 0)

-- Gradient to darken zenith during solar eclipse
local eclipseCover = nil
eclipseCover = ac.SkyExtraGradient()
eclipseCover.isAdditive = false
eclipseCover.sizeFull = 0
eclipseCover.sizeStart = 2
eclipseCover.exponent = 0.1
eclipseCover.direction = vec3(0, 1, 0)
eclipseCover.color = rgb(0, 0, 0)

-- Custom post-processing brightness adjustment
-- TODO: Disable if gamma fix is active
local ppBrightnessCorrection = ac.ColorCorrectionBrightness()
ac.addWeatherColorCorrection(ppBrightnessCorrection)

-- A bit of optimization to reduce garbage generated per frame
local vec3Up = vec3(0, 1, 0)

-- Cheap thunder effect
local thunderActiveFor = 0
local thunderFlashAdded = false
local thunderFlash = ac.SkyExtraGradient()
thunderFlash.direction = vec3(0, 1, 0)
thunderFlash.sizeFull = 0
thunderFlash.sizeStart = 1
thunderFlash.exponent = 1
thunderFlash.isIncludedInCalculate = false

-- Strong wind blows estimated city pollution away (estimation is done based on light pollution, specific weather
-- types can boost pollution further)
local windSpeedSmoothed = -1
local baseCityPollution = 0
local totalPollution = 0
local prevEclipseK = -1

-- Temporary, for debugging
function OnGammaToggle()
  prevEclipseK = -1
  CityHaze = -1
end

-- Updates sky color
function ApplySky(dt)
  ac.getSunDirectionTo(SunDir)
  ac.getMoonDirectionTo(MoonDir)

  windSpeedSmoothed = windSpeedSmoothed < 0 and CurrentConditions.windSpeed or math.applyLag(windSpeedSmoothed, CurrentConditions.windSpeed, 0.99, dt)
  baseCityPollution = LightPollutionValue * (1 - 0.3 * math.min(windSpeedSmoothed / 10, 1)) * math.saturateN(0.2 + ac.getSim().ambientTemperature / 60)
  totalPollution = math.lerp(baseCityPollution * 0.5, 1, CurrentConditions.pollution)

  SpaceLook = math.saturateN(ac.getAltitude() / 5e4 - 1)
  CloudsMult = math.saturateN(2 - ac.getAltitude() / 2e3)
  realNightK = math.lerpInvSat(SunDir.y, 0.05, -0.2)

  -- Eclipse coefficients. Full eclipse happens on Brasov track on 08/11/1999:
  -- https://www.racedepartment.com/downloads/brasov-romania.28239/
  local sunMoonAngle = ac.getSunMoonAngle()
  local hadAnyFullEclipse = EclipseFullK > 0
  eclipseK = math.lerpInvSat(sunMoonAngle, 0.0077, 0.0005) * (1 - realNightK)
  EclipseFullK = math.lerpInvSat(sunMoonAngle, 0.00032, 0.00021) * (1 - realNightK)
  if hadAnyFullEclipse ~= (EclipseFullK > 0) then
    if hadAnyFullEclipse then
      ForceRapidUpdates = ForceRapidUpdates - 1
    else
      ForceRapidUpdates = ForceRapidUpdates + 1
    end
    UpdateEclipseGlare(EclipseFullK > 0)
  end

  if SpaceLook > 0 then
    realNightK = math.lerp(realNightK, 0, SpaceLook)
    eclipseK = math.lerp(eclipseK, 0, SpaceLook)
    EclipseFullK = math.lerp(EclipseFullK, 0, SpaceLook)
  end

  NightK = realNightK
  FinalFog = math.pow(CurrentConditions.fog, 1 - 0.5 * NightK)
  
  sunsetK = math.lerpInvSat(math.max(0, SunDir.y), 0.12, 0)
  horizonK = math.lerpInvSat(math.abs(SunDir.y), 0.4, 0.12)

  if UseGammaFix and EclipseFullK then
    NightK = math.lerp(NightK, 1, EclipseFullK)
  end

  if SpaceLook > 0 then
    sunsetK = math.lerp(sunsetK, 0, SpaceLook)
    horizonK = math.lerp(horizonK, 0, SpaceLook)
    NightK = math.lerp(NightK, 0, SpaceLook)
    FinalFog = math.lerp(FinalFog, 0, SpaceLook)
  end

  -- Generally the same:
  ac.setSkyV2MieKCoefficient(ac.SkyRegion.All, vec3(0.686, 0.678, 0.666))
  ac.setSkyV2NumMolecules(ac.SkyRegion.All, 2.542e25)
  ac.setSkyV2MieDirectionalG(ac.SkyRegion.All, 0.8)
  ac.setSkyV2DepolarizationFactor(ac.SkyRegion.All, 0.035)
  ac.setSkyV2MieV(ac.SkyRegion.All, 3.96)
  ac.setSkyV2MieZenithLength(ac.SkyRegion.All, 1.25e3)
  ac.setSkyV2SunIntensityFactor(ac.SkyRegion.All, 1000.0)
  ac.setSkyV2SunIntensityFalloffSteepness(ac.SkyRegion.All, 1.5)

  -- Few sky adjustments
  local purpleAdjustment = sunsetK -- slightly alter color for sunsets
  local skyVisibility = (1 - FinalFog) * CurrentConditions.clear

  -- Brightness adjustments:
  if UseGammaFix then
    local refractiveIndex = math.lerp(1.000317, 1.00029, NightK) + 0.0001 * purpleAdjustment -- TODO: Tie to pollution, make purple value dynamic 
    ac.setSkyV2Primaries(ac.SkyRegion.All, vec3(6.8e-7, 5.5e-7, 4.5e-7))
    ac.setSkyV2Turbidity(ac.SkyRegion.All, 1.25 + sunsetK * (1 - NightK) * 3.45)
    ac.setSkyV2Rayleigh(ac.SkyRegion.Sun, 1 + sunsetK * 0.28)
    ac.setSkyV2RayleighZenithLength(ac.SkyRegion.All, (8400 - 2000 * sunsetK) * (1 - 0.99 * NightK) + baseCityPollution * math.lerp(8000, 4000, horizonK))

    ac.setSkyV2Luminance(ac.SkyRegion.All, 0.03)
    ac.setSkyV2Gamma(ac.SkyRegion.All, 1)

    ac.setSkyV2BackgroundLight(ac.SkyRegion.All, 0) -- what does this thing do?
    ac.setSkyV2SunShapeMult(ac.SkyRegion.All, 3e4 * ((CurrentConditions.clear * (1 - FinalFog)) ^ 5) * (1 - EclipseFullK) ^ 8)
    ac.setSkyV2SunSaturation(ac.SkyRegion.All, 1)
    -- ac.setSkyV2Saturation(ac.SkyRegion.All, 1.2 - Sim.weatherConditions.humidity * 0.4)
    ac.setSkyV2Saturation(ac.SkyRegion.All, 1)

    local mieC = math.lerp(0.0065, 0.0045, sunsetK) * (1 - EclipseFullK) * CurrentConditions.clear
    refractiveIndex = refractiveIndex * math.lerp(0.99997, 1.00003, Sim.weatherConditions.humidity)
    if SpaceLook > 0 then
      refractiveIndex = math.lerp(refractiveIndex, 1, SpaceLook)
      mieC = math.lerp(mieC, 0, SpaceLook)
    end

    ac.setSkyV2RefractiveIndex(ac.SkyRegion.All, refractiveIndex)
    ac.setSkyV2MieCoefficient(ac.SkyRegion.All, mieC)

    -- Shifting sky using Earth radius and current altitude
    local earthR = 6371e3
    local cameraR = earthR + math.max(1, ac.getAltitude())
    local n = cameraR * cameraR - earthR * earthR
    local x = n / cameraR
    local d = math.sqrt(n - x * x)
    fogRangeMult = 1 + x / d
    local shiftScale = 1 / fogRangeMult
    ac.setSkyV2YOffset(ac.SkyRegion.All, 1 - shiftScale)
    ac.setSkyV2YScale(ac.SkyRegion.All, shiftScale)
  else
    local brightDayAdjustment = math.lerpInvSat(math.max(0, SunDir.y), 0.2, 0.6) -- make sky clearer during the day
    ac.setSkyV2RefractiveIndex(ac.SkyRegion.All, 1.0003)
    ac.setSkyV2Primaries(ac.SkyRegion.All, vec3(6.8e-7, 5.5e-7, math.lerp(4.5e-7, 5.1e-7, purpleAdjustment)))
    ac.setSkyV2Turbidity(ac.SkyRegion.All, 2.0)
    ac.setSkyV2Rayleigh(ac.SkyRegion.All, math.lerp(3.0, 1.0, brightDayAdjustment))
    ac.setSkyV2RayleighZenithLength(ac.SkyRegion.All, 8400)
    ac.setSkyV2MieCoefficient(ac.SkyRegion.All, 0.005 * CurrentConditions.clear)

    local darkNightSky = math.max(NightK, EclipseFullK * 0.85) -- sky getting black
    ac.setSkyV2Luminance(ac.SkyRegion.All, math.lerp(0, 0.3, math.pow(1 - darkNightSky, 4)))
    ac.setSkyV2Gamma(ac.SkyRegion.All, 2.5)

    ac.setSkyV2BackgroundLight(ac.SkyRegion.All, 0) -- what does this thing do?
    ac.setSkyV2SunShapeMult(ac.SkyRegion.All, 10 * (CurrentConditions.clear ^ 2))
    ac.setSkyV2SunSaturation(ac.SkyRegion.All, 0.9)
    ac.setSkyV2Saturation(ac.SkyRegion.All, math.lerp(0.5, 1.2, CurrentConditions.clear))

    if SpaceLook > 0 then
      ac.setSkyV2RefractiveIndex(ac.SkyRegion.All, math.lerp(1.0003, 1, SpaceLook))
      ac.setSkyV2MieCoefficient(ac.SkyRegion.All, math.lerp(0.005 * CurrentConditions.clear, 0, SpaceLook))
    end
    
    -- Crappy old approach kept for compatibility
    ac.setSkyV2YOffset(ac.SkyRegion.All, 0.1)
    ac.setSkyV2YScale(ac.SkyRegion.All, 0.9)
  end

  ac.setSkyBrightnessMult(1)

  -- Boosting deep blue at nights
  local deepBlue = NightK ^ 2
  skyGeneralMult.color
    :set(math.lerp(1, 0.2, deepBlue), math.lerp(1, 0.8, math.max(horizonK * 0.5, deepBlue)), math.lerp(1, 1.6, deepBlue))
    :mul(CurrentConditions.tint)
    :scale(skyVisibility 
      * (1 - math.smoothstep(realNightK) * 0.99)) -- TODO: verify compatibility, add variance to 0.99

  -- Covering layer
  ac.calculateSkyColorNoGradientsTo(skyTopColor, vec3Up, false, false, false)
  skyCoverAddition.color
    :set(math.lerp(1, 0.2, deepBlue), math.lerp(1, 0.8, deepBlue) * 1.1, math.lerp(1, 2, deepBlue) * 1.2)
    :scale((1 - NightK * 0.99) * (1 - CurrentConditions.cloudsDensity * 0.5))
    :mul(CurrentConditions.tint)
  if UseGammaFix then
    skyHorizonAddition.exponent = 2
    skyCoverAddition.color:pow(2.2):scale(skyTopColor.b * 0.3 --[[ actually defines how dark nonclear weathers are ]] * (1 - skyVisibility))
  else
    skyHorizonAddition.exponent = 1
    skyCoverAddition.color:scale(skyTopColor.g * (1 - skyVisibility))
  end
  skyHorizonAddition.color:set(skyCoverAddition.color)
  skyHorizonAddition.direction.x = SunDir.x * 0.2
  skyHorizonAddition.direction.z = SunDir.z * 0.2

  -- Haze alteration (with gamma fixed, sky parameters are tweaked instead for a dirtier atmosphere look)
  local newCityHaze = UseGammaFix and 0 or (1 - sunsetK) * (1 - CurrentConditions.clouds) * CurrentConditions.clear 
    * math.pow(math.saturateN(LightPollutionValue), 2) * math.saturateN(0.2 + ac.getSim().ambientTemperature / 60)
  if math.abs(newCityHaze - CityHaze) > 0.01 then
    if (newCityHaze ~= 0) ~= (CityHaze ~= 0) then
      if newCityHaze ~= 0 then
        ac.addSkyExtraGradient(cityHaze)
      else
        ac.skyExtraGradients:erase(cityHaze)
      end
    end
    CityHaze = newCityHaze
    cityHaze.color.r = math.lerp(1, 1.8, newCityHaze)
    cityHaze.color.g = math.lerp(1, 0.9, newCityHaze)
    cityHaze.color.b = math.lerp(1, 0.5, newCityHaze)
  end

  if UseGammaFix and prevEclipseK ~= eclipseK then
    if (prevEclipseK > 0) ~= (eclipseK > 0) then
      if eclipseK > 0 then
        ac.addSkyExtraGradient(eclipseCover)
      else
        ac.skyExtraGradients:erase(eclipseCover)
      end
    end
    eclipseCover.color:set(1 - eclipseK * 0.9 - EclipseFullK * 0.1)
    eclipseCover.direction:set(SunDir)
    prevEclipseK = eclipseK
  end

  local rainbowIntensity = Overrides.rainbowIntensity or 
    math.saturateN(CurrentConditions.rain * 50) * CurrentConditions.clear * math.lerpInvSat(SunDir.y, 0.02, 0.06)
  ac.setSkyV2Rainbow(rainbowIntensity)
  ac.setSkyV2RainbowSecondary(0.2 * rainbowIntensity)
  ac.setSkyV2RainbowDarkening(math.lerp(1, UseGammaFix and 0.4 or 0.8, rainbowIntensity))

  -- Getting a few colors from sky
  ac.calculateSkyColorTo(skyTopColor, vec3Up, false, false, false)
  ac.calculateSkyColorTo(skySunColor, vec3(SunDir.x, math.max(SunDir.y, 0.0), SunDir.z), false, false, true)

  -- Small adjustment for balancing
  if UseGammaFix then
    skySunColor:scale(0.5)
    skyTopColor:scale(0.5)
  else
    skySunColor:scale(0.25)
    skyTopColor:scale(0.25)
  end

  if SpaceLook > 0 then
    ac.setSkyV2Rainbow(rainbowIntensity * (1 - SpaceLook))
    skySunColor:setLerp(skySunColor, rgb.colors.white, SpaceLook)
    skyTopColor:setLerp(skyTopColor, rgb.colors.black, SpaceLook)
  end
end

-- Updates main scene light: could be either sun or moon light, dims down with eclipses
local moonAbsorption = rgb()
local cloudLightColor = rgb()

function ApplyLight()
  local eclipseLightMult = (1 - eclipseK * (UseGammaFix and 0.98 or 0.8)) -- up to 80% general occlusion
    * (1 - EclipseFullK * (UseGammaFix and 1 or 0.98)) -- up to 98% occlusion for real full eclipse
  
  -- Calculating sun color based on sky absorption (boosted at horizon)
  ac.getSkyAbsorptionTo(sunColor, SunDir)
  if UseGammaFix then
    sunColor:scale(SunIntensity * eclipseLightMult)
  else
    sunColor:pow(1 + horizonK):mul(SunColor):scale(SunIntensity * eclipseLightMult * math.lerp(1, 2, horizonK))
  end

  -- Initially, it starts as a sun light
  lightColor:set(sunColor)

  -- If it’s deep night and moon is high enough, change it to moon light
  ac.getSkyAbsorptionTo(moonAbsorption, MoonDir)
  local sunThreshold = math.lerpInvSat(realNightK, 0.7, 0.5)
  local moonThreshold = math.lerpInvSat(realNightK, 0.7, 0.95)
  local moonLight = moonThreshold * math.lerpInvSat(MoonDir.y, 0, 0.12) * (1 - SpaceLook)

  -- Calculate light direction, similar rules
  if moonLight > 0 then
    local moonPartialEclipseK = math.lerpInvSat(math.dot(SunDir, MoonDir), -0.99964, -0.99984)
    local moonEclipseK = math.lerpInvSat(math.dot(SunDir, MoonDir), -0.99996, -0.99985)
    local finalMoonEclipseMult = moonEclipseK * (0.8 + 0.2 * moonPartialEclipseK)
    if UseGammaFix then
      finalMoonEclipseMult = finalMoonEclipseMult ^ 2
    end
    moonLight = moonLight * finalMoonEclipseMult

    lightDir:set(MoonDir)
    lightColor:set(moonAbsorption):mul(MoonColor)
      :scale(MoonLightMult * LightPollutionSkyFeaturesMult * ac.getMoonFraction() * moonLight * CurrentConditions.clear)
  else
    lightDir:set(SunDir)
  end

  -- Adjust light color
  lightColor:scale(UseGammaFix and CurrentConditions.clear ^ 2 or CurrentConditions.clear)
    :adjustSaturation(CurrentConditions.saturation * (UseGammaFix and 1 or 0.8) * (1.1 - Sim.weatherConditions.humidity * 0.2))
    :mul(CurrentConditions.tint)

  -- Clouds have their own lighting, so sun would work even if it’s below the horizon
  local cloudSunLight = math.lerpInvSat(SunDir.y, -0.23, -0.115)
  cloudLightColor:set(sunColor):scale(cloudSunLight * sunThreshold)
  cloudLightColor:setLerp(cloudLightColor, lightColor, moonLight)
  cloudLightColor:scale(CurrentConditions.clear)
  cloudLightColor:adjustSaturation(CurrentConditions.saturation)
  cloudLightColor:mul(CurrentConditions.tint)
  ac.setCloudsLight(lightDir, cloudLightColor, 6371e3 / 20)

  -- Dim light if light source is very low
  lightColor:scale(math.lerpInvSat(lightDir.y, -0.03, 0) * SunLightIntensity)

  -- Dim godrays even more
  GodraysColor:set(lightColor):scale(math.lerpInvSat(lightDir.y, 0.01, 0.02) * (1 - FinalFog ^ 2))

  if SpaceLook > 0 then
    GodraysColor:scale(1 - SpaceLook)
  end

  -- And godrays!
  if SunRaysCustom then
    ac.setGodraysCustomColor(GodraysColor)
    ac.setGodraysCustomDirection(lightDir)
    ac.setGodraysLength(0.3)
    ac.setGodraysGlareRatio(0)
    ac.setGodraysAngleAttenuation(1)
  else
    ac.setGodraysCustomColor(GodraysColor:scale(SunRaysIntensity))
    ac.setGodraysCustomDirection(lightDir)
  end

  -- Adjust light dir for case where sun is below horizon, but a bit is still visible
  belowHorizonCorrection = math.lerpInvSat(lightDir.y, 0.04, 0.01)
  if belowHorizonCorrection > 0 then
    lightColor:scale(math.lerpInvSat(lightDir.y, -0.01, 0.01))
    lightDir.y = math.lerp(lightDir.y, 0.02, belowHorizonCorrection ^ 2)
  end

  if SpaceLook > 0 then
    lightDir:setLerp(lightDir, SunDir, SpaceLook)
    lightColor:setLerp(lightColor, rgb.colors.white, SpaceLook)
  elseif thunderFlashAdded and SunDir.y < 0 then
    lightDir:set(thunderFlash.direction)
    lightColor:setScaled(thunderFlash.color, 10)
  end

  -- Applying everything
  ac.setLightDirection(lightDir)
  ac.setLightColor(lightColor)
  ac.setSpecularColor(lightColor)
  ac.setSunSpecularMultiplier(CurrentConditions.clear ^ 2)

  ac.setCloudsLight(lightDir, lightColor, 6371e3)
end

-- Updates ambient lighting based on sky color without taking sun or moon into account
local ambientBaseColor = rgb(1, 1, 1)
local ambientAdjColor = rgb(1, 1, 1)
local ambientDistantColor = rgb()
local ambientExtraColor = rgb()
local ambientExtraDirection = vec3()
local ambientLuminance = 1

function ApplyAmbient()
  if UseGammaFix then
    -- Computing sky color on horizon 90° off sun direction 
    local d = math.sqrt(SunDir.x ^ 2 + SunDir.z ^ 2)
    ambientExtraDirection.x = SunDir.z / d
    ambientExtraDirection.z = -SunDir.x / d
    ambientExtraDirection.y = 0.15 - 0.05 * sunsetK
    ac.calculateSkyColorV2To(ambientBaseColor, ambientExtraDirection, false, false, false)
    ambientBaseColor:scale(0.5 + 0.5 * CurrentConditions.clear)

    -- Syncing luminance with top sky point for more even lighting
    ambientLuminance = ambientBaseColor:luminance()
    local targetLuminance = skyTopColor:luminance()
    ambientBaseColor:scale(targetLuminance / math.max(1e-9, ambientLuminance))
    ambientLuminance = math.max(ambientLuminance, targetLuminance)
    ambientLuminance = ambientLuminance * (1 + sunsetK)

    -- If there are a lot of clouds around, desaturating ambient light and shifting it a bit closer to sun color
    local ambientDesaturate = math.lerp(Sim.weatherConditions.humidity ^ 2 * 0.25, 1, CurrentConditions.clouds)
    local ambientSaturate = (1 - ambientDesaturate) * CurrentConditions.saturation
    local sunColorSynced = ambientAdjColor:set(sunColor):scale(targetLuminance / math.max(1e-9, sunColor:luminance()))
    ambientBaseColor:adjustSaturation(ambientSaturate):mul(CurrentConditions.tint)

    local basicSunColorContribution = ac.isBouncedLightActive() and 0.1 or 0.2
    ambientBaseColor:setLerp(ambientBaseColor, sunColorSynced, (basicSunColorContribution + ambientDesaturate * 0.4) * (CurrentConditions.clear ^ 2))
    
    -- Ambient light is ready
    ac.setAmbientColor(ambientBaseColor)

    -- Distant ambient lighting is a tiny bit more bluish because why not
    ac.setDistantAmbientColor(ambientDistantColor:set(0.95, 1, 1.05):mul(ambientBaseColor), 20e3)
    ambientExtraColor:set(skyTopColor):adjustSaturation(ambientSaturate):mul(CurrentConditions.tint)
    ambientExtraColor:setLerp(ambientExtraColor, sunColorSynced, (0.1 + ambientDesaturate * 0.4) * (CurrentConditions.clear ^ 2)):sub(ambientBaseColor)
    ac.setExtraAmbientColor(ambientExtraColor)
    ac.setExtraAmbientDirection(vec3Up)
  
    -- Adjusting fake shadows under cars
    ac.setWeatherFakeShadowOpacity(1 - SpaceLook)
    ac.setWeatherFakeShadowConcentration(0)
  
    -- Adjusting vertex AO
    ac.adjustTrackVAO(1, 0, 1)
    ac.adjustDynamicAOSamples(1, 0, 1)
  else
    -- Base ambient color: uses sky color at zenith with extra addition of light pollution, adjusted for conditions
    ambientBaseColor
      :set(skyTopColor)
      :adjustSaturation(CurrentConditions.saturation)
  
    local rain = math.min(CurrentConditions.wetness * 50, 1)
    ambientBaseColor.r = ambientBaseColor.r * math.lerp(1, 0.8, rain)
  
    -- Actual scene ambient color
    ambientAdjColor:set(ambientBaseColor)
    if not ac.isBouncedLightActive() then
      -- If bounced light from Extra FX is disabled, let’s mix in a bit of sun light
      ambientAdjColor:add(lightColor * (0.01 * math.saturate(lightDir.y * 2)))
    end
    ambientAdjColor:scale(AmbientLightIntensity):adjustSaturation(math.lerp(0.25, 0.5, horizonK))
    ac.setAmbientColor(ambientAdjColor)
  
    ac.setDistantAmbientColor(ambientDistantColor:set(0.7 - rain * 0.2, 1, 1.3):mul(ambientAdjColor), 4000)
  
    -- Extra ambient for sunsets, to take into account sky glow even when sun is below horizon
    local extraAmbientMult = sunsetK * (1 - NightK) * math.lerpInvSat(CurrentConditions.clear, 0.3, 1)
    if extraAmbientMult > 0 then
      ambientExtraColor
        :set(skySunColor)
        :adjustSaturation(CurrentConditions.saturation)
        :mul(rgb.tmp():set(CurrentConditions.tint):add(1):scale(0.5))
        :scale((1 + CurrentConditions.clouds * 0.6) * extraAmbientMult * 2)
      ac.setExtraAmbientColor(ambientExtraColor)
      ac.setExtraAmbientDirection(ambientExtraDirection:set(SunDir.x, math.max(SunDir.y, 0.1), SunDir.z))
    else
      local directedAmbient = math.lerpInvSat(CurrentConditions.clear, 0.3, 0) * math.lerp(0.3, 0.6, CurrentConditions.cloudsDensity) 
        * (1 - NightK) * (1 - FinalFog)
      if directedAmbient > 0 then
        ambientExtraColor:set(ambientAdjColor):scale(1 - directedAmbient)
        ac.setAmbientColor(ambientExtraColor)
        ambientExtraColor:set(ambientAdjColor):scale(directedAmbient)
        ac.setExtraAmbientColor(ambientExtraColor)
        ac.setExtraAmbientDirection(ambientExtraDirection:set(0, 0.3 / (0.1 + directedAmbient), 0):add(SunDir))
      else
        ambientExtraColor:set(0)
        ac.setExtraAmbientColor(ambientExtraColor)
      end
    end

    -- ac.debug('lightBrightness', lightBrightness)
    -- ac.debug('horizonK', horizonK)
    -- ac.debug('headlights', lightBrightness < 8 or horizonK > 0.5)
    -- ac.debug('sugg', math.max(math.lerpInvSat(lightBrightness, 8, 6), math.lerpInvSat(horizonK, 0.8, 0.9)))
  
    -- Turning on headlights when it’s too dark outside
    -- ac.setAiHeadlights(lightBrightness < 8 or horizonK > 0.5)
    ac.setAiHeadlightsSuggestion(math.max(math.lerpInvSat(lightBrightness, 6, 4), 
      math.max(math.lerpInvSat(horizonK, 0.8, 0.9), math.lerpInvSat(CurrentConditions.rain, 0.003, 0.01))))
  
    -- Adjusting fake shadows under cars
    ac.setWeatherFakeShadowOpacity(1)
    ac.setWeatherFakeShadowConcentration(math.lerp(0.15, 1, NightK))
  
    -- Adjusting vertex AO
    ac.adjustTrackVAO(math.lerp(0.55, 0.65, CurrentConditions.clear), 0, 1)
    ac.adjustDynamicAOSamples(math.lerp(0.2, 0.25, CurrentConditions.clear), 0, 1)
  end
end

-- Updates fog, fog color is based on ambient color, so sometimes this fog can get red with sunsets
local skyHorizonColor = rgb(1, 1, 1)
local secondaryFogColor = rgb(1, 1, 1)
local skyHorizonLuminance = 1
local fogNoise = LowFrequency2DNoise:new{ frequency = 0.003 }
function ApplyFog(dt)
  ac.calculateSkyColorTo(skyHorizonColor, vec3(SunDir.z, 0, -SunDir.x), false, false)
  skyHorizonLuminance = skyHorizonColor:luminance()

  local ccFog = FinalFog
  if UseGammaFix then
    ac.setFogColor(skyHorizonColor:scale(SkyBrightness * math.lerpInvSat(cameraOcclusion, 0.05, 1) * 0.5))

    local pressureMult = 101325 / Sim.weatherConditions.pressure
    local fogBlend = math.lerpInvSat(ac.getAltitude(), 10e3, 5e3)
    local fogDistance = math.lerp(28.58e3 * pressureMult * (1 - Sim.weatherConditions.humidity * 0.6), 1e3, totalPollution) * math.lerp(1, 0.1, math.lerp((1 - CurrentConditions.clear) * 0.5, 1, ccFog))
    ac.setFogDistance(fogDistance)
    ac.setFogExponent(1 - CurrentConditions.pollution * 0.5)
    ac.setFogBlend(fogBlend)

    local atmosphereFade = math.lerp(ccFog, 1, math.max(CurrentConditions.clouds, 1 - CurrentConditions.clear))
    ac.setFogAtmosphere(fogDistance * (1 - atmosphereFade * 0.5) / (22.5e3 * pressureMult) * (0.65 + Sim.weatherConditions.humidity * 0.7))

    local distanceBoost = math.max(0, Sim.cameraPosition.y - GroundYAveraged) * math.lerp(4, 0.4, NightK)
    ac.setNearbyFog(secondaryFogColor:set(ambientDistantColor)
        :addScaled(lightColor, lightDir.y):scale(1 - NightK):addScaled(skyHorizonColor, NightK):scale(2),
      math.lerp(math.lerp(5e3, 1e3, NightK), math.lerp(50, 30, NightK), ccFog) + distanceBoost, math.lerp(-20, -10, ccFog),
      fogBlend * math.min(1, 1.2 * ccFog / (0.1 + ccFog)),
      math.lerp(0.9, 1.1, fogNoise:get(Sim.cameraPosition)) * (1 + ccFog ^ 2))

    local horizonFog = math.min(1, 1.5 * ccFog / (0.5 + ccFog))
    ac.setSkyFogMultiplier(horizonFog * 0.8)
    ac.setHorizonFogMultiplier(1, math.lerp(math.lerp(10, 4, horizonK), 0.5, horizonFog), fogRangeMult)
  
    ac.setFogBacklitExponent(8)
    ac.setFogBacklitMultiplier(1 - CurrentConditions.clouds * 0.9)
  else
    ccFog = math.lerp(ccFog, 1, CityHaze * 0.5)
    ac.setFogColor(skyHorizonColor:scale(SkyBrightness))

    local fogDistance = math.lerp(1500, 35, ccFog)
    local fogHorizon = math.min(1, math.lerp(0.3, 1.1, ccFog ^ 0.5))
    local fogDensity = math.lerp(0.01, 1, ccFog ^ 2)
    local fogExponent = math.lerp(0.3, 0.5, fogNoise:get(Sim.cameraPosition))
  
    ac.setFogExponent(fogExponent)
    ac.setFogDensity(fogDensity)
    ac.setFogDistance(fogDistance)
    ac.setFogHeight(GroundYAveraged - fogDistance - math.lerp(100, 20, ccFog))
    ac.setFogAtmosphere(0)
    ac.setSkyFogMultiplier(ccFog ^ 2)
    ac.setHorizonFogMultiplier(fogHorizon, math.lerp(8, 1, ccFog), math.lerp(0.95, 0.75, ccFog ^ 2))
  
    ac.setFogBlend(fogHorizon)
    ac.setFogBacklitExponent(12)
    ac.setFogBacklitMultiplier(math.lerp(0.2, 1, ccFog * horizonK) * FogBacklitIntensity)
  end
end

-- Calculates heat factor for wobbling air above heated track and that wet road/mirage effect
function ApplyHeatFactor()
  local heatFactor = math.lerpInvSat(SunDir.y, 0.6, 0.7) 
    * math.lerpInvSat(CurrentConditions.clear, 0.7, 0.9) 
    * math.lerpInvSat(CurrentConditions.clouds, 0.6, 0.3)
    * math.lerpInvSat(CurrentConditions.windSpeed, 7, 3)
  ac.setTrackHeatFactor(heatFactor)
end

-- Updates stuff like moon, stars and planets
local moonBaseColor = rgb()
function ApplySkyFeatures()
  -- local brightness = ((0.25 / math.max(lightBrightness, 0.05)) ^ 2) * LightPollutionSkyFeaturesMult 
  --   * (CurrentConditions.clear ^ 4) * 0.1

  local moonBrightness = math.lerp(50, 10 - CurrentConditions.clear * 9, NightK ^ 0.1)
  local moonOpacity = math.lerp(0.1, 1, NightK) * CurrentConditions.clear * LightPollutionSkyFeaturesMult
  local starsBrightness = 2

  if UseGammaFix then
    local starsMult = CurrentConditions.clear * (1 - FinalFog) * (1 - LightPollutionValue) ^ 3
    if UseGammaFix then
      starsMult = starsMult * (1 - AuroraIntensity * 0.3)
    end
    moonOpacity = 0.005
    moonBrightness = 50 * starsMult
    starsBrightness = (1 + 9 * NightK) * starsMult
    ac.setSkyMoonBaseColor(MoonColor)

    ac.setSkyPlanetsBrightness(1)
    ac.setSkyPlanetsOpacity(NightK)
  else
    moonBrightness = math.lerp(50, 10 - CurrentConditions.clear * 9, NightK ^ 0.1)
    moonOpacity = math.lerp(0.1, 1, NightK) * CurrentConditions.clear * LightPollutionSkyFeaturesMult
    starsBrightness = 2 * NightK * moonBrightness * math.max(0, 1 - lightBrightness)
    ac.setSkyMoonBaseColor(moonBaseColor:setScaled(MoonColor, 0.2 + NightK))

    ac.setSkyPlanetsBrightness(moonBrightness)
    ac.setSkyPlanetsOpacity(moonOpacity)
  end

  if SpaceLook > 0 then
    moonBrightness = math.lerp(moonBrightness, 1, SpaceLook)
    starsBrightness = math.lerp(starsBrightness, 1, SpaceLook)
    moonOpacity = math.lerp(moonOpacity, 1, SpaceLook)
  end

  ac.setSkyMoonMieMultiplier(0.00003 * (1 - CurrentConditions.clear) * (1 - FinalFog))
  ac.setSkyMoonBrightness(moonBrightness)
  ac.setSkyMoonOpacity(moonOpacity)
  ac.setSkyMoonMieExp(120)
  ac.setSkyMoonDepthSkip(true)

  ac.setSkyStarsColor(MoonColor)
  ac.setSkyStarsBrightness(starsBrightness * moonOpacity)

  -- easiest way to take light pollution into account is
  -- to raise stars map in power: with stars map storing values from 0 to 1, it gets rid of dimmer stars only leaving
  -- brightest ones    

  local augustK = math.lerpInvSat(math.abs(1 - ac.getDayOfTheYear() / 200), 0.2, 0.1)
  if UseGammaFix then
    local pollutionK = LightPollutionValue
    pollutionK = math.lerp(pollutionK, 1, 1 - NightK)
    pollutionK = math.lerp(pollutionK, 1, math.lerpInvSat(MoonDir.y, -0.1, 0.1) * 0.5)

    ac.setSkyStarsSaturation(math.lerp(0.3, 0.1, pollutionK) * CurrentConditions.saturation)
    ac.setSkyStarsExponent(math.lerp(4 - augustK, 12, pollutionK))
  else
    local pollutionK = math.sqrt(LightPollutionValue)
    pollutionK = math.max(pollutionK, 1 - NightK ^ 4)
    pollutionK = math.max(pollutionK, math.lerpInvSat(MoonDir.y, -0.3, -0.1))
  
    pollutionK = math.max(pollutionK, (1 - augustK) / 4)
    
    ac.setSkyStarsSaturation(math.lerp(0.3, 0.1, pollutionK) * CurrentConditions.saturation)
    ac.setSkyStarsExponent(math.lerp(1.3, 4, pollutionK ^ 2))
  end

  ac.setSkyPlanetsSizeBase(1)
  ac.setSkyPlanetsSizeVariance(1)
  ac.setSkyPlanetsSizeMultiplier(1)
end

-- local function sunBehindHorizon(sunDir, distanceToCenter, earthRadius)
--   return (sunDir.y * distanceToCenter) ^ 2 + earthRadius ^ 2 > distanceToCenter ^ 2
-- end

-- Thing thing disables shadows if it’s too cloudy or light is not bright enough, or downsizes shadow map resolution
-- making shadows look blurry
function ApplyAdaptiveShadows()
  if lightColor:value() < (UseGammaFix and 1e-5 or 0.001) then
    ac.setShadows(ac.ShadowsState.Off)
  elseif SpaceLook > 0 then
    ac.resetShadowsResolution()
    ac.setShadows(ac.ShadowsState.On)
    -- if SunDir.y > 0 then
    --   ac.setShadows(ac.ShadowsState.On)
    -- elseif sunBehindHorizon(SunDir, ac.getAltitude() + 6400e3, 6400e3) then
    --   ac.setShadows(ac.ShadowsState.EverythingShadowed)
    -- else
    --   ac.setShadows(ac.ShadowsState.On)
    -- end
  elseif belowHorizonCorrection > 0 and BlurShadowsWhenSunIsLow then
    if belowHorizonCorrection > 0.8 then ac.setShadowsResolution(256)
    elseif belowHorizonCorrection > 0.6 then ac.setShadowsResolution(384)
    elseif belowHorizonCorrection > 0.4 then ac.setShadowsResolution(512)
    elseif belowHorizonCorrection > 0.2 then ac.setShadowsResolution(768)
    else ac.setShadowsResolution(1024) end
    ac.setShadows(ac.ShadowsState.On)
  elseif BlurShadowsWithFog then
    if FinalFog > 0.96 then ac.setShadowsResolution(256)
    elseif FinalFog > 0.92 then ac.setShadowsResolution(384)
    elseif FinalFog > 0.88 then ac.setShadowsResolution(512)
    elseif FinalFog > 0.84 then ac.setShadowsResolution(768)
    elseif FinalFog > 0.8 then ac.setShadowsResolution(1024)
    else ac.resetShadowsResolution() end
    ac.setShadows(ac.ShadowsState.On)
  else
    ac.resetShadowsResolution()
    ac.setShadows(ac.ShadowsState.On)
  end
end

-- The idea here is to use scene brightness for adapting camera to darkness in tunnels
-- unlike auto-exposure approach, it would be smoother and wouldn’t jump as much if camera
-- simply rotates and, for example, looks down in car interior
ac.setCameraOcclusionDepthBoost(2.5)
local dirUp = vec3(0, 1, 0)
local function getSceneBrightness(dt)
  local aoNow = ac.getCameraOcclusion(dirUp)
  cameraOcclusion = aoNow

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

local brightnessMult = 1
function ApplyFakeExposure_postponed()
  if not UseGammaFix or math.abs(brightnessMult - BrightnessMultApplied) < 1e-20 then return false end

  BrightnessMultApplied = brightnessMult
  ac.setBrightnessMult(GammaFixBrightnessOffset * brightnessMult)
  ac.setHDRToLDRConversionHints(1 / GammaFixBrightnessOffset, 0.4545)
  ac.setOverallSkyBrightnessMult(1)
  ac.setSkyV2DitherScale(0)

  if ac.isPpActive() then
    ppBrightnessCorrection.value = 1.6
  end

  -- Lights can be pretty dark now
  local lightsMult = 0.003

  -- A funny trick: split multiplier into v1 and v2 since v1 is the one that can turn the lights
  -- off, so there could be a bit of extra optimization in a sunny day
  local v1LightsMult = math.lerp(1, 0.001, math.lerpInvSat(brightnessMult, 600, 4.5))
  ac.setWeatherLightsMultiplier(math.pow(v1LightsMult, 1 / 2.2))
  ac.setWeatherLightsMultiplier2((lightsMult / v1LightsMult * GammaFixBrightnessOffset) * brightnessMult)
  ac.setBaseAmbientColor(rgb.tmp():set(0.00002))
  ac.setEmissiveMultiplier(ScriptSettings.LINEAR_COLOR_SPACE.DIM_EMISSIVES and 0.2 or 30 / brightnessMult) -- how bright are emissives
  ac.setTrueEmissiveMultiplier(10) -- how bright are extrafx emissives
  ac.setGlowBrightness(1) -- how bright are those distant emissive glows
  ac.setWeatherTrackLightsMultiplierThreshold(0.01)

  local dayBrightness = math.lerpInvSat(brightnessMult, 80, 10)
  ac.setWhiteReferencePoint((2 + dayBrightness * 8) / brightnessMult) -- white ref point is always bright

  -- No need to boost reflections here (and fresnel gamma wouldn’t even work anyway)
  ac.setFresnelGamma(1)
  ac.setReflectionEmissiveBoost(1)

  local aiHeadlights = math.lerp(math.lerpInvSat(brightnessMult, 13, 20), 1, math.max(FinalFog, math.min(CurrentConditions.rain * 10, 1)))
  ac.setAiHeadlightsSuggestion(aiHeadlights)
  return true
end

-- There are two problems fake exposure solves:
-- 1. We need days to be much brighter than nights, to such an extend that lights wouldn’t be visible in sunny days.
--    That also hugely helps with performance.
-- 2. In dark tunnels, brightness should go up, revealing those lights and overexposing everything outside.
-- Ideally, HDR should’ve solved that task, but it introduces some other problems: for example, emissives go too dark,
-- or too bright during the day. That’s why instead this thing uses fake exposure, adjusting brightness a bit, but 
-- also, adjusting intensity of all dynamic lights and emissives to make it seem like the difference is bigger.
function ApplyFakeExposure(dt)
  if UseGammaFix then
    local lightBrightnessRaw = ambientLuminance 
      + math.max(skyHorizonLuminance * (1 - CurrentConditions.clear), lightColor:luminance() * math.saturate(lightDir.y * 20))
    lightBrightnessRaw = math.max(lightBrightnessRaw, 1)
    local sceneBrightness = getSceneBrightness(dt)
    local aoK = math.lerpInvSat(sceneBrightness, 0.1, 0.4)

    lightBrightnessRaw = lightBrightnessRaw * aoK
    if SpaceLook > 0 then
      lightBrightnessRaw = math.lerp(lightBrightnessRaw, 0.5, SpaceLook)
    end
  
    if initialSet > 0 then
      lightBrightness = lightBrightnessRaw
      initialSet = initialSet - 1
    elseif lightBrightness < lightBrightnessRaw then
      lightBrightness = math.min(lightBrightness + dt * AdaptationSpeed, lightBrightnessRaw)
    elseif lightBrightness > lightBrightnessRaw then
      lightBrightness = math.max(lightBrightness - dt * AdaptationSpeed, lightBrightnessRaw)
    end

    brightnessMult = 100 / math.lerp(lightBrightness, 15, 0.01)
  else  
    ac.setHDRToLDRConversionHints(1, 1)

    local lightBrightnessRaw = ambientAdjColor:value() * 1.5 + lightColor:value() * math.saturate(lightDir.y * 1.4) * 0.5
    local aoK = math.lerpInvSat(getSceneBrightness(dt), 0.1, 0.4)
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
      ac.setOverallSkyBrightnessMult(SkyBrightness)
      ppBrightnessCorrection.value = math.lerp(2, 1, sceneBrightness) * FilterBrightnessMultPP
    else
      -- without post-processing, we can only adjust scene brightness, but that’s enough
      ac.setBrightnessMult(sceneBrightness * SceneBrightnessMultNoPP)
      ac.setOverallSkyBrightnessMult(SkyBrightness)
    end
  
    -- ac.debug('lightsMult', lightsMult)
  
    ac.setWeatherLightsMultiplier(math.max(lightsMult * 1.25 - 0.25, 0) * 2) -- how bright are lights
    ac.setTrueEmissiveMultiplier(lightsMult) -- how bright are extrafx emissives
    ac.setGlowBrightness(lightsMult * 0.15) -- how bright are those distant emissive glows
    ac.setEmissiveMultiplier(0.9 + lightsMult * 0.3) -- how bright are emissives
    ac.setWeatherTrackLightsMultiplierThreshold(0.01) -- let make lights switch on early for smoothness
    ac.setWhiteReferencePoint(0) 
  
    ac.setBaseAmbientColor(rgb.tmp():set((UseGammaFix and 0.004 or 0.04) * lightsMult)) -- base ambient adds a bit of extra ambient lighting not
      -- affected by ambient occlusion, so even pitch black tunnels become a tiny bit lit after “eye” adapts.
  
    -- Trying to get reflections to work better
    ac.setFresnelGamma(math.lerp(1, 0.8, NightK))
    ac.setReflectionEmissiveBoost(1 + 2 * NightK)
  end
end

-- Creates generic cloud material
---@return ac.SkyCloudMaterial
local function createGenericCloudMaterial(props)
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
  ret.alphaSmoothTransition = 1
  ret.normalFacingExponent = 2

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
  contourExponent = 2,
  contourIntensity = 0.2,
  ambientConcentration = 0.1, 
  frontlitDiffuseConcentration = 0.8,
  backlitMultiplier = 4,
  backlitOpacityMultiplier = 0.5,
  backlitOpacityExponent = 1,
  backlitExponent = 20,
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

local cloudMateralsList = {CloudMaterials.Main, CloudMaterials.Bottom, CloudMaterials.Hovering, CloudMaterials.Spread}
local prevSunsetK = -1
local prevCloudDensityK = -1

-- Update cloud materials for chanding lighting conditions
function UpdateCloudMaterials()
  ac.setLightShadowOpacity(math.lerp(0, 0.6 + 0.3 * CurrentConditions.clouds, CurrentConditions.clear))

  local main = CloudMaterials.Main
  local ccCloudsDensity = CurrentConditions.cloudsDensity

  if UseGammaFix then
    local densityMult = 1 - ccCloudsDensity * 0.8
    main.ambientColor:setScaled(skyTopColor, 3 * densityMult)
    main.extraDownlit:setScaled(lightColor, 0.03 * lightDir.y * densityMult)
      :addScaled(LightPollutionColor, 0.5 * densityMult)
    main.extraDownlit.r, main.extraDownlit.b = main.extraDownlit.r * 0.9, main.extraDownlit.b * 0.8

    if math.abs(prevCloudDensityK - ccCloudsDensity) > 0.001
      or math.abs(prevSunsetK - SunDir.y) > 0.001 then
      prevSunsetK = SunDir.y
      prevCloudDensityK = ccCloudsDensity
      for _, v in ipairs(cloudMateralsList) do
        v.baseColor:set(0.3 * densityMult)
        v.ambientConcentration = math.lerp(0.25, 0.45, ccCloudsDensity)
        v.frontlitMultiplier = math.lerp(2.5, 1, horizonK) * densityMult
        v.frontlitDiffuseConcentration = math.lerp(0.5, 0.75, sunsetK)
        v.receiveShadowsOpacity = 0.9
        v.specularPower = math.lerp(1, 8, sunsetK)
        v.specularExponent = 4
        v.backlitMultiplier = 4 * densityMult
        v.backlitExponent = 10
        v.backlitOpacityMultiplier = 0.5
        v.backlitOpacityExponent = 1
        v.contourIntensity = 0.2 * densityMult
        v.contourExponent = 1
        v.fogMultiplier = 1
        v.alphaSmoothTransition = 1
      end
      CloudMaterials.Bottom.contourExponent = 2
    end
    
    CloudMaterials.Bottom.ambientColor:set(main.ambientColor)
    CloudMaterials.Bottom.extraDownlit:set(main.extraDownlit)
    CloudMaterials.Hovering.ambientColor:set(main.ambientColor)
    CloudMaterials.Hovering.extraDownlit:set(main.extraDownlit)
    CloudMaterials.Spread.ambientColor:set(main.ambientColor)
    CloudMaterials.Spread.extraDownlit:set(main.extraDownlit)
  else
    local ccClear = CurrentConditions.clear
    local ccClouds = CurrentConditions.clouds
    local clearSunset = sunsetK * ccClear

    prevSunsetK = -1
    main.ambientColor
      :set(skyTopColor):adjustSaturation(math.lerp(0.8, 1.4, clearSunset)):scale(math.lerp(3.2, 2, clearSunset) * math.lerp(1.5, 1, ccCloudsDensity))
      -- :add(lightColor:clone():scale(0.1 * math.lerp(0.4, 0.2, sunsetK)))
      -- :add(LightPollutionExtraAmbient)
    main.ambientConcentration = math.lerp(0.2, 0, NightK) * (0.3 + ccCloudsDensity) * (1 - ccClouds * 0.5)
    main.extraDownlit:set(skySunColor):scale(math.lerp(0.2, 0.1, sunsetK) * ccClear)
    main.frontlitMultiplier = math.lerp(1 + ccClear, 0.5 + ccClear * 0.8, NightK)
    main.specularPower = math.lerp(1, 0.1, NightK)
    main.frontlitDiffuseConcentration = math.lerp(0.3, 0.8, sunsetK)
    main.backlitMultiplier = math.lerp(0, 6, ccClear)
    
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
end

function ApplyThunder(dt)
  if dt == 0 then
    return false
  end

  local cc = CurrentConditions
  local chance = cc.thunder * cc.clouds
  if math.random() > math.lerp(1.03, 0.97, chance) and SpaceLook == 0 then
    thunderActiveFor = 0.1 + math.random() * 0.3
  end

  local showFlash = false
  if thunderActiveFor > 0 then
    thunderActiveFor = thunderActiveFor - dt
    showFlash = math.random() > 0.95
  end

  if showFlash then
    if not thunderFlashAdded then
      thunderFlash.direction = vec3(
        math.random() - 0.5 - 0.1 * CurrentConditions.windDir.x, math.random() ^ 2,
        math.random() - 0.5 - 0.1 * CurrentConditions.windDir.y):normalize()

      local drawBolt = thunderFlash.direction.y < 0.4
      if drawBolt then
        AddVisualLightning(thunderFlash.direction:clone())
      end

      thunderFlash.exponent = UseGammaFix and 1 or 1
      thunderFlash.color = rgb(0.3, 0.3, 0.5):scale(1 + math.random()):scale(UseGammaFix and 0.001 or 1)
      thunderFlashAdded = true
      ac.skyExtraGradients:push(thunderFlash)
      ac.pauseCubemapUpdates(true)
      return true
    end
  elseif thunderFlashAdded then
    thunderFlashAdded = false
    ac.skyExtraGradients:erase(thunderFlash)
    setTimeout(function ()
      ac.pauseCubemapUpdates(false)
    end)
    return true
  end
end
