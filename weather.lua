--------
-- Basic WeatherFX implementation, this is the main file. Sets things up, includes a bunch of stuff and triggers updates.
--------

---Functions from this list will be called when resolution changes.
---@type fun()[]
OnResolutionChange = {}

---TODO: Remove once gamma becomes non-changing live.
---@type fun()[]
OnGammaFixChange = {}

ScriptSettings = ac.INIConfig.scriptSettings():mapConfig({
  LINEAR_COLOR_SPACE = {
    ENABLED = false,
    DIM_EMISSIVES = true,
    DEV_MODE = false
  },
  POSTPROCESSING = {
    LIGHTWEIGHT_REPLACEMENT = false,
    FILM_GRAIN = false,
    GLARE_CHROMATIC_ABERRATION = false,
  },
  EXTRA_EFFECTS = {
    UPPER_CLOUDS = true,
    AURORAS = true,
    FOG_ABOVE = true,
    RAIN_HAZE = true,
    LIGHTNING = true,
    ECLIPSE = true,
  }
})

-- Global weather values
NightK = 0 -- 1 at nights, 0 during the day
AuroraIntensity = 0
SunDir = vec3(0, 1, 0)
MoonDir = vec3(0, 1, 0)
GodraysColor = rgb()
CityHaze = 0
FinalFog = 0
SpaceLook = 0 -- turns from 0 to 1 as camera gets higher switching to space look of the Earth
CloudsMult = 0 -- turns to 0 at 4 km to hide clouds
EclipseFullK = 0 -- starts growing when moon covers sun fully blocking the light, 1 at total eclipse, used for heavy darkening of sky and sun light
ForceRapidUpdates = 0
BrightnessMultApplied = 0
StarsBrightness = 0
GroundYAveraged = math.nan
RecentlyJumped = 0
Sim = ac.getSim()

if Sim.isShowroomMode or Sim.isPreviewsGenerationMode then
  ScriptSettings.LINEAR_COLOR_SPACE.ENABLED = false
  require 'src/showroom_mode'
  require 'src/render_postprocessing'
  return
end

if Sim.isOnlineRace then
  ScriptSettings.LINEAR_COLOR_SPACE.DEV_MODE = false
elseif ScriptSettings.LINEAR_COLOR_SPACE.DEV_MODE then
  ui.onExclusiveHUD(function ()
    ui.drawText(UseGammaFix and '[ Linear color space ]' or '[ Gamma color space ]', vec2(8, 8))
  end)
end

Overrides = {gamma = ScriptSettings.LINEAR_COLOR_SPACE.ENABLED}
if ScriptSettings.LINEAR_COLOR_SPACE.DEV_MODE then
  ui.addSettings({icon = ui.Icons.WeatherFewClouds, name = 'WeatherFX style', onOpen = function ()
    Overrides = stringify.tryParse(ac.storage.overrides) or {}
    ForceRapidUpdates = ForceRapidUpdates + 1
  end, onClose = function ()
    Overrides = {gamma = ScriptSettings.LINEAR_COLOR_SPACE.ENABLED}
    ForceRapidUpdates = ForceRapidUpdates - 1
  end}, function ()
    if not Overrides.tint then
      Overrides.tint = rgb.colors.white
    end

    ui.beginGroup(-0.1)
    ui.pushItemWidth(-0.1)
    ui.pushFont(ui.Font.Small)
    if ui.checkbox('Linear color space', Overrides.gamma) then
      Overrides.gamma = not Overrides.gamma
      BrightnessMultApplied = -1
    end

    if ScriptSettings.POSTPROCESSING.LIGHTWEIGHT_REPLACEMENT then
      if ui.checkbox('Original YEBIS post-processing', Overrides.originalPostProcessing) then
        Overrides.originalPostProcessing = not Overrides.originalPostProcessing
      end
    end

    GammaFixBrightnessOffset = ui.slider('##gfbo', GammaFixBrightnessOffset, 1e-6, 10, 'Brightness offset: %.6f', 10)
    GammaFixLightsDivisor = ui.slider('##gfld', GammaFixLightsDivisor, 1e-3, 1e4, 'Lights divisor: %.6f', 10)
    if ui.itemEdited() and UseGammaFix then
      ac.useLinearColorSpace(true, GammaFixLightsDivisor)
    end

    ui.offsetCursorY(12)
    ui.header('Conditions override')
    Overrides.clear = ui.slider('##clear', Overrides.clear or 1, 0, 1, 'Clear: %.3f')
    Overrides.fog = ui.slider('##fog', Overrides.fog or 0, 0, 1, 'Fog: %.3f')
    Overrides.clouds = ui.slider('##clouds', Overrides.clouds or 0, 0, 1, 'Clouds: %.3f')
    Overrides.cloudsDensity = ui.slider('##cloudsDensity', Overrides.cloudsDensity or 0, 0, 1, 'Clouds density: %.3f')
    Overrides.thunder = ui.slider('##thunder', Overrides.thunder or 0, 0, 1, 'Thunder %.3f')
    Overrides.pollution = ui.slider('##pollution', Overrides.pollution or 0, 0, 1, 'Pollution: %.3f')
    Overrides.aurora = ui.slider('##aurora', Overrides.aurora or 0, 0, 1, 'Aurora: %.3f')

    ui.offsetCursorY(12)
    ui.header('Rain')
    Overrides.rain = ui.slider('##rain', Overrides.rain or 0, 0, 1, 'Rain: %.3f')
    Overrides.wetness = ui.slider('##wetness', Overrides.wetness or 0, 0, 1, 'Wetness: %.3f')
    Overrides.water = ui.slider('##water', Overrides.water or 0, 0, 1, 'Water: %.3f')
    Overrides.rainbowIntensity = ui.slider('##rainbowIntensity', Overrides.rainbowIntensity or 0, 0, 1, 'Rainbow: %.3f')

    ui.offsetCursorY(12)
    ui.header('Mood')
    Overrides.saturation = ui.slider('##saturation', Overrides.saturation or 1, 0, 2, 'Saturation: %.3f')

    ui.alignTextToFramePadding()
    ui.text('Tint:')
    ui.sameLine(80)
    ui.colorButton('##tint', Overrides.tint, ui.ColorPickerFlags.PickerHueWheel)

    ui.offsetCursorY(12)
    ui.header('Light pollution')
    Overrides.lightPollution = ui.slider('##lightPollution', Overrides.lightPollution or 0, 0, 3, 'Density: %.3f', 2)
    ui.popItemWidth()
    ui.endGroup()
    ui.popFont()
    if ui.itemEdited() then
      ac.storage.overrides = stringify(Overrides, true)
      BrightnessMultApplied = -1
    end
  end)
end

require 'src/consts'                -- some general constant values
require 'src/utils'                 -- helpful functions
require 'src/conditions_converter'  -- thing to turn conditions (esp. weather type) info something usable: a few easy to use numbers
require 'src/weather_application'   -- most of weather stuff happens here
require 'src/light_pollution'       -- adds a sky gradient for light pollution and a few global variables like light pollution intensity
require 'src/weather_clouds'        -- clouds operating in chunks
require 'src/audio'                 -- audio
require 'src/render'                -- render core

require 'src/render_aurora'         -- auroras
require 'src/render_rain'           -- rain haze
require 'src/render_fog'            -- fog covering tops of high buildings in foggy conditions
require 'src/render_eclipse'        -- glare around sun during eclipse
require 'src/render_lightning'      -- simple bolt-like visual for lightnings
require 'src/render_clouds'         -- upper clouds layer
require 'src/render_meteor'         -- falling stars

-- Use asyncronous textures loading for faster loading
ac.setAsyncTextureLoading(true)

-- Since we’re going to use v2 of clouds, here we can set cloud map parameters
local cloudMap = ac.SkyCloudMapParams.new()
cloudMap.perlinFrequency = 4.0
cloudMap.perlinOctaves = 7
cloudMap.worleyFrequency = 3.0
cloudMap.shapeMult = 20.0
cloudMap.shapeExp = 0.5
cloudMap.shape0Mip = 0
cloudMap.shape0Contribution = 0.2
cloudMap.shape1Mip = 2.2
cloudMap.shape1Contribution = 0.5
cloudMap.shape2Mip = 3.5
cloudMap.shape2Contribution = 1.0
ac.generateCloudMap(cloudMap)

-- Loading textures for sky stuff
ac.setSkyStarsMap('textures/weather_fx/starmap.dds')
ac.setSkyMoonTexture('textures/weather_fx/moon.dds')
ac.setEarthTexture('textures/weather_fx/earth.dds')
ac.setSkyMoonGradient(0)

-- Have to use original size for moon eclipse to look properly:
ac.setSkySunMoonSizeMultiplier(1)
ac.setMoonEclipse(true)

-- Use cloud shadow maps: in this mode, mirrors and reflections will use “ac.getCloudsShadow()” as light multiplier automatically
ac.setCloudShadowMaps(true)

-- Do not update cloud maps (like cloud shadows) without manual invalidation
ac.setManualCloudsInvalidation(true)

-- Set cloud shadow map parameters
ac.setCloudShadowDistance(6e3)
ac.setCloudShadowScalingFactor(1)

-- Use v2 sky shader
ac.setSkyUseV2(true)
ac.setSkyMoonClipThreshold(0.9)
ac.setCloudArcMultiplier(1)

-- Use new fog formula (instead of original AC one)
ac.setFogAlgorithm(ac.FogAlgorithm.New)

-- As time goes on, some bugs on C++ side are found, in some cases to keep things compatible, fixes need to be enabled manually
ac.fixSkyColorCalculateResult(true)
ac.fixSkyColorCalculateOrder(true)
ac.fixSkyV2Fog(true)
ac.fixCloudsV2Fog(true)
ac.useMinDepthResolution(true)

-- A tweak for lambert diffuse model making lighting of regular materials more correct and PBR-like
ac.setLambertGamma(UseLambertGammaFix and 1 / 2.2 or 1)

CloudsDT = 0

-- Called each 3rd frame or if sun moved
local function rareUpdate1(dt)
  ReadConditions(dt)
  ApplySky(dt)
  ApplyLight() 
  ApplyAmbient()
  ApplyFog(dt)
  ApplySkyFeatures()
  ApplyAdaptiveShadows()
end

-- Called each 3rd frame, but with an offset, to spread the load
local function rareUpdate2(dt)
  ApplyHeatFactor()
  UpdateLightPollution()
  UpdateCloudMaterials()
  UpdateAurora(dt)
  UpdateAboveFog(dt)
  UpdateCloudLayers(dt)
end

local lastSunDir = vec3()
local currentSunDir = vec3()
local lastGameTime = 0
local ruBase = RareUpdate:new{ callback = rareUpdate1 }
local ruCloudMaterials = RareUpdate:new{ callback = rareUpdate2, phase = 1 }
local ruClouds = RareUpdate:new{ callback = UpdateClouds, phase = 2 }

local function getCloudsDeltaT(dt, gameDT)
  local gameTime = ac.getCurrentTime()
  local cloudsDeltaTime = gameTime - lastGameTime
  lastGameTime = gameTime
  local ratio = math.clamp(math.abs(cloudsDeltaTime) / dt - 150, 1, 200)
  return dt * math.sign(cloudsDeltaTime) * math.lerp(1, ratio, 0.4)
end

local forceUpdateShadingNext = false
local keepForceUpdates = 1

function script.update(dt)
  local curGammaFix = Overrides.gamma ~= false
  if Sim.currentVAOMode == ac.VAODebugMode.VAOOnly or Sim.currentVAOMode == ac.VAODebugMode.ShowNormals then
    curGammaFix = false
  end
  if UseGammaFix ~= curGammaFix then
    InitializeConsts(curGammaFix)
    OnGammaToggle()
    ForceRapidUpdates = ForceRapidUpdates + 1
    setTimeout(function ()
      ForceRapidUpdates = ForceRapidUpdates - 1
    end, 0.1)
  end

  -- This value is time passed in seconds (as dt), but taking into account pause, slow
  -- motion or fast forward, but not time scale in conditions
  local gameDT = Sim.dt

  -- Clouds operate on actual passed time
  CloudsDT = TimelapsyCloudSpeed and getCloudsDeltaT(dt, gameDT) or gameDT

  -- If sun moved too much, have to force update
  ac.getSunDirectionTo(currentSunDir)
  if Sim.cameraJumped then
    RecentlyJumped = 5
  elseif RecentlyJumped > 0 then
    RecentlyJumped = RecentlyJumped - 1
  end
  if math.dot(lastSunDir, currentSunDir) < 0.999995 or Sim.cameraJumped then
    keepForceUpdates = 1
  end
  local forceUpdate = ForceRapidUpdates > 0
  if keepForceUpdates > 0 then
    forceUpdate = true
    keepForceUpdates = keepForceUpdates - dt
  end
  if forceUpdate then
    lastSunDir:set(currentSunDir)
    ForceRapidUpdates = ForceRapidUpdates + 1
  end

  local groundY = ac.getGroundYApproximation()
  if math.isnan(GroundYAveraged) or Sim.cameraJumped then
    GroundYAveraged = groundY
  else
    GroundYAveraged = math.applyLag(GroundYAveraged, groundY, 0.995, dt)
  end

  local forceUpdateShading = forceUpdate
  if forceUpdateShadingNext then
    forceUpdateShading = true
    forceUpdateShadingNext = false
  end

  -- Thunder effect: a small extra gradient glowing in sky
  if ApplyThunder(gameDT) then
    forceUpdateShading = true
  end

  -- Actual update will happen only once in three frames, or if forceUpdate is true
  ruBase:update(gameDT, forceUpdateShading)
  ruCloudMaterials:update(CloudsDT, forceUpdateShading)

  -- Increasing refresh rate for faster moving clouds
  if math.abs(CloudsDT) > 0.5 then 
    ruClouds.skip = 0 
    ac.invalidateCloudReflections()
  elseif math.abs(CloudsDT) > 0.05 then 
    ruClouds.skip = 1
    if Sim.frame % 4 == 0 then      
      ac.invalidateCloudReflections()
    end
  elseif math.abs(CloudsDT) < 0.03 then 
    ruClouds.skip = 2
  end

  ruClouds:update(CloudsDT, forceUpdate)

  -- Fake exposure aka eye adaptation needs to update each frame, with speed independant 
  -- from pause, slow motion and what not
  ApplyFakeExposure(dt)
  if ApplyFakeExposure_postponed() then
    forceUpdateShadingNext = true
  end

  -- Rain haze: some sort of volumetric-like effect for distant rain
  UpdateRainHaze(gameDT)

  -- Uncomment to check how much garbage is generated each frame (slows things down)
  -- RunGC()

  if CurrentConditions.windDir.x == 0 and CurrentConditions.windDir.y == 0 then
    CurrentConditions.windDir:set(CurrentConditions.windDirInstant)
    CurrentConditions.windSpeed = CurrentConditions.windSpeedInstant
  else
    local mix = math.lagMult(0.995, dt)
    CurrentConditions.windDir:scale(1 - mix):addScaled(CurrentConditions.windDirInstant, mix)
    CurrentConditions.windSpeed = math.lerp(CurrentConditions.windSpeed, CurrentConditions.windSpeedInstant, mix)
  end
end

if ScriptSettings.POSTPROCESSING.LIGHTWEIGHT_REPLACEMENT then
  require 'src/render_postprocessing'
elseif ScriptSettings.LINEAR_COLOR_SPACE.ENABLED or ScriptSettings.LINEAR_COLOR_SPACE.DEV_MODE then
  -- WeatherFX can convert linear to sRGB automatically, but it wouldn’t take our GammaFixBrightnessOffset into
  -- account, and will just use the basic `pow(X, 1/2.2)` conversion too.
  require 'src/render_linear'
end

function script.frameBegin(dt)
  -- Update audio (for now, just rain)
  ApplyAudio(dt)
end

-- To stop script from reloading with resolution changes, adding a subscription to the event
ac.onResolutionChange(function (newSize, makingScreenshot)
  ac.log('Resolution change', newSize, makingScreenshot)

  -- Instead of manually disposing all created textures, the idea is to clear out all the tables
  -- containing those and then run garbage collector and let CSP clean things up automatically
  for _, v in ipairs(OnResolutionChange) do v() end
  collectgarbage('collect')
end)
