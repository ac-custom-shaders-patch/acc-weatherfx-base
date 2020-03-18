--------
-- Basic WeatherFX implementation, this is the main file. Sets things up, includes a bunch of stuff and triggers updates.
--------

require 'src/consts'                -- some general constant values
require 'src/utils'                 -- helpful functions
require 'src/conditions_converter'  -- thing to turn conditions (esp. weather type) info something usable: a few easy to use numbers
require 'src/weather_application'   -- most of weather stuff happens here
require 'src/light_pollution'       -- adds a sky gradient for light pollution and a few global variables like light pollution intensity
require 'src/weather_clouds'        -- clouds operating in chunks

-- We’re so sure everything is correct we’ll be skipping sane checks to speed things up
-- (do not do that if your code can divide by zero)
ac.skipSaneChecks()

-- Since we’re going to use v2 of clouds, here we can set cloud map parameters
local cloudMap = ac.SkyCloudMapParams.new()
cloudMap.perlinFrequency = 4.0
cloudMap.perlinOctaves = 7
cloudMap.worleyFrequency = 4.0
cloudMap.shapeMult = 20.0
cloudMap.shapeExp = 0.5
cloudMap.shape0Mip = 0
cloudMap.shape0Contribution = 0.1
cloudMap.shape1Mip = 3.2
cloudMap.shape1Contribution = 1.0
cloudMap.shape2Mip = 4.5
cloudMap.shape2Contribution = 1.0
ac.generateCloudMap(cloudMap)

-- Loading textures for sky stuff
ac.setSkyStarsMap('textures/weather_fx/starmap.dds')
ac.setSkyMoonTexture('textures/weather_fx/moon.dds')

-- Sun, moon and the planets look too tiny without an extra size boost. If you’re changing it, don’t forget to readjust stuff 
-- related to eclipses in `weather_application.lua`
ac.setSkySunMoonSizeMultiplier(3)

-- Use new version applying gradients before sun
ac.calculateSkyColor = ac.calculateSkyColorV2

-- Use cloud shadow maps: in this mode, mirrors and reflections will use “ac.getCloudsShadow()” as light multiplier automatically
ac.setCloudShadowMaps(true)

-- Do not update cloud maps (like cloud shadows) without manual invalidation
ac.setManualCloudsInvalidation(true)

-- Called each 3rd frame or if sun moved
function rareUpdate1(dt)
  readConditions(dt)
  applySky()
  applyLight() 
  applyAmbient()
  applyFog()
  applySkyFeatures()
  applyAdaptiveShadows()
end

-- Called each 3rd frame, but with an offset, to spread the load
function rareUpdate2(dt)
  updateLightPollution(dt)
  updateCloudMaterials(dt)
end

local lastSunDir = vec3()
local lastCameraPos = vec3()
local lastGameTime = 0
local cloudsDtSmooth = 0
local ruBase = RareUpdate:new{ callback = rareUpdate1 }
local ruCloudMaterials = RareUpdate:new{ callback = rareUpdate2, phase = 1 }
local ruClouds = RareUpdate:new{ callback = updateClouds, phase = 2 }

function getCloudsDeltaT(dt, gameDT)
  local gameTime = ac.getCurrentTime()
  local cloudsDeltaTime = gameTime - lastGameTime
  local cloudsDeltaTimeAdj = math.sign(cloudsDeltaTime) * math.abs(cloudsDeltaTime) / (1 + math.abs(cloudsDeltaTime))
  lastGameTime = gameTime
  cloudsDtSmooth = math.applyLag(cloudsDtSmooth, 
    math.lerp(math.clamp(cloudsDeltaTimeAdj, -1, 1), gameDT, CloudFixedSpeed),
    0.9, dt)
  return cloudsDtSmooth
end

-- Called every frame
function update(dt)
  -- This value is time passed in seconds (as dt), but taking into account pause, slow 
  -- motion or fast forward, but not time scale in conditions
  local gameDT = ac.getGameDeltaT()

  -- Clouds operate on actual passed time
  local cloudsDT = TimelapsyCloudSpeed and getCloudsDeltaT(dt, gameDT) or gameDT

  -- If sun moved too much, have to force update
  local currentSunDir = ac.getSunDirection()
  local currentCameraPos = ac.getCameraPosition()
  local forceUpdate = math.dot(lastSunDir, currentSunDir) < 0.999995 or math.squaredDistance(currentCameraPos, lastCameraPos) > 10
  if forceUpdate then
    lastSunDir:set(currentSunDir)
  end

  lastCameraPos:set(currentCameraPos)

  -- Actual update will happen only once in three frames, or if forceUpdate is true
  ruBase:update(gameDT, forceUpdate)
  ruCloudMaterials:update(gameDT, forceUpdate)

  -- Increasing refresh rate for faster moving clouds
  if math.abs(cloudsDT) > 0.05 then 
    ruClouds.skip = 1
  elseif math.abs(cloudsDT) < 0.03 then 
    ruClouds.skip = 2
  end

  ruClouds:update(cloudsDT, forceUpdate)

  -- Fake exposure aka eye adaptation needs to update each frame, with speed independant 
  -- from pause, slow motion and what not
  applyFakeExposure(dt)

  -- Uncomment to check how much garbage is generated each frame (slows things down)
  -- runGC()
end