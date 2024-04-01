--------
-- Some general constant values, should not be changed real-time.
--------

TimelapsyCloudSpeed = true -- change to false to stop clouds from moving all fast if time goes faster
SmoothTransition = true -- smooth transition between weather types (even if change was sudden)
BlurShadowsWhenSunIsLow = false -- reduce shadows resolution for when sun is low
BlurShadowsWithFog = true -- reduce shadows resolution with thick fog
UseLambertGammaFix = true -- fixes darker surfaces when sun is low

SunRaysCustom = false -- use fully custom sun ray parameters instead of SunRaysIntensity
SunRaysIntensity = 0.02 -- some good PP-filters expode with sun rays at full strength for some reason

UseGammaFix = false
GammaFixBrightnessOffset = 0.01
GammaFixLightsDivisor = 100

SceneBrightnessMultNoPP = 2  -- without post-processing active: brightness multiplier for the whole scene
SceneBrightnessMultPP = 3  -- with post-processing active: brightness multiplier for the scene (in most cases, gets compensated by auto-exposure)
FilterBrightnessMultPP = 1.0 -- with post-processing active: brightness adjustment applied after auto-exposure

function InitializeConsts(useGammaFix)
  ac.broadcastSharedEvent('_dev.WeatherFX.GammaToggle')
  ac.useLinearColorSpace(useGammaFix, GammaFixLightsDivisor)
  ac.setWeatherLightsMultiplier(1)
  ac.setWeatherLightsMultiplier2(1)
  UseGammaFix = useGammaFix

  for _, v in ipairs(OnGammaFixChange) do v() end
  collectgarbage('collect')
  
  if useGammaFix then    
    SunIntensity = 12
    SunLightIntensity = 1
    AmbientLightIntensity = 5
    FogBacklitIntensity = 1
    MoonLightMult = 0.0007
    SkyBrightness = 1
    
    AdaptationSpeed = 2
    SunColor = rgb(1, 1, 1)
    MoonColor = rgb(1, 1.5, 2)
    LightPollutionBrightness = 0.002
  else    
    SunIntensity = 12 -- how bright sun is in general
    SunLightIntensity = UseLambertGammaFix and 0.7 or 1 -- brightness of sun light cast on the scene
    AmbientLightIntensity = 10 -- brightness of ambient light on the scene
    FogBacklitIntensity = 2 -- brightness of fog backlit
    MoonLightMult = 0.5 -- how bright is moon light
    SkyBrightness = 0.5 -- sky brightness multiplier
    
    AdaptationSpeed = 10
    SunColor = rgb(1, 0.95, 0.9)
    MoonColor = rgb(0.6, 1.2, 2):scale(1.5)
    LightPollutionBrightness = 0.1
  end
end

InitializeConsts(ScriptSettings.LINEAR_COLOR_SPACE.ENABLED)

CloudUseAtlas = true
CloudSpawnScale = 0.5
CloudCellSize = 2000
CloudCellDistance = 6
CloudDistanceShiftStart = 4000
CloudDistanceShiftEnd = 10000
CloudFadeNearby = 1000
DynCloudsMinHeight = 400
DynCloudsMaxHeight = 1200
DynCloudsDistantHeight = 250
HoveringMinHeight = 1200
HoveringMaxHeight = 1600

CloudShapeShiftingSpeed = 0.003
CloudShapeMovingSpeed = 0.05
