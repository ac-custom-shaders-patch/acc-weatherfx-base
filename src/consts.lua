--------
-- Some general constant values, should not be changed real-time.
--------

SceneBrightnessMultNoPP = 1  -- without post-processing active: brightness multiplier for the whole scene
SceneBrightnessMultPP = 3  -- with post-processing active: brightness multiplier for the scene (in most cases, gets compensated by auto-exposure)
FilterBrightnessMultPP = 1.0 -- with post-processing active: brightness adjustment applied after auto-exposure

TimelapsyCloudSpeed = true -- change to false to stop clouds from moving all fast if time goes faster
SmoothTransition = true -- smooth transition between weather types (even if change was sudden)

SunIntensity = 20 -- how bright sun is in general
SunMieIntensity = 3 -- brightness of glow around sun on the sky 
SunLightIntensity = 1 -- brightness of sun light cast on the scene
AmbientLightIntensity = 10 -- brightness of ambient light on the scene
FogBacklitIntensity = 2 -- brightness of fog backlit
MoonLightMult = 0.5 -- how bright is moon light

AdaptationSpeed = 10
SunRaysIntensity = 0.02 -- some good PP-filters expode with sun rays at full strength for some reason
SunRaysCustom = false -- use fully custom sun ray parameters instead of SunRaysIntensity
SunColor = rgb(1, 0.95, 0.9)
MoonColor = rgb(0.6, 0.8, 1):scale(2)
LightPollutionBrightness = 0.15

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

CloudFixedSpeed = 0.0
CloudShapeShiftingSpeed = 0.001
CloudShapeMovingSpeed = 0.05
