--------
-- Some general constant values, should not be changed real-time.
--------

SceneBrightnessMultNoPP = 1  -- without post-processing active: brightness multiplier for the whole scene
SceneBrightnessMultPP = 2.5  -- with post-processing active: brightness multiplier for the scene (in most cases, gets compensated by auto-exposure)
FilterBrightnessMultPP = 1.5 -- with post-processing active: brightness adjustment applied after auto-exposure

TimelapsyCloudSpeed = true -- change to false to stop clouds from moving all fast if time goes faster
SmoothTransition = true -- smooth transition between weather types (even if change was sudden)

SunIntensity = 30 -- how bright sun is in general
SunShapeIntensity = 100 -- brightness of sun circle, higher than usual for that massive post-processing glare
SunMieIntensity = 3 -- brightness of glow around sun on the sky 
AdaptationSpeed = 10
SunRaysIntensity = 0.02 -- some good PP-filters expode with sun rays at full strength for some reason
SunRaysCustom = true -- use fully custom sun ray parameters instead of SunRaysIntensity
SunColor = rgb(1, 0.95, 0.9)
MoonColor = rgb(0.6, 0.8, 1):scale(2)
MoonLightMult = 0.5 -- how bright is moon light
LightPollutionBrightness = 0.15

CloudUseAtlas = true
CloudSpawnScale = 0.8
CloudCellSize = 6000
CloudCellDistance = 5
CloudDistanceShiftStart = 2000
CloudDistanceShiftEnd = 20000
CloudFadeNearby = 4000

DynCloudsMinHeight = 3000
DynCloudsMaxHeight = 6000
DynCloudsDistantHeight = 0
HoveringMinHeight = 8000
HoveringMaxHeight = 12000

CloudFixedSpeed = 0.7
CloudShapeShiftingSpeed = 0.005
CloudShapeMovingSpeed = 0.2
