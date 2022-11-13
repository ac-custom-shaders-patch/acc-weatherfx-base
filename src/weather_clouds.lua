--------
-- Clouds: spawning dynamically in chunks, moving with the wind and what not. It’s a bit of a mess as I was trying to get it
-- working as fast as possible and produce as little garbage as possible. TODO: move algorithm to C++ side allowing to use 
-- several layers of clouds at once cheaper?
--------

-- Local state (will be updated with values from `conditions_converter.lua`)
local windDir = vec2(1, 0)
local windSpeed = 0
local windAngle = 0

-- Calculates base Y coordinate of a cloud from a circle of clouds near horizon
require 'src/weather_clouds_pertrack'

-- Different types of clouds
require 'src/weather_clouds_types'

-- Creates a new cloud and sets it using `fn`, which would be one of `CloudTypes` functions
---@return ac.SkyCloudV2
local function createCloud(fn, arg1, arg2)
  local cloud = ac.SkyCloudV2()
  cloud.color = rgb(1, 1, 1)
  cloud.procMap = vec2(0.6, 0.65 + math.random() * 0.05) + math.random() * 0.1
  cloud.procNormalScale = vec2(0.9, 0.3)
  cloud.procShapeShifting = math.random()
  cloud.opacity = 0.9
  cloud.shadowOpacity = 1.0
  cloud.cutoff = 0
  cloud.occludeGodrays = false
  cloud.useNoise = true
  cloud.material = CloudMaterials.Main
  cloud.up = vec3(0, -1, 0)
  cloud.side = math.cross(-cloud.position, cloud.up):normalize()
  cloud.up = math.cross(cloud.side, -cloud.position):normalize()
  cloud.noiseOffset:set(math.random(), math.random()) 
  fn(cloud, arg1, arg2)
  return cloud
end

local function transitionHeadingAngle(current, target, dt)
  if current == -1 then return target end
  local delta = target - current
  if delta > 180 then
    delta = 360 - delta
  elseif delta < -180 then
    delta = 360 + delta
  end
  return current + (target - current) * math.min(dt, 0.1) * math.lerpInvSat(windSpeed, 0.002, 0.009)
end

local nightEarlyK = 0
local nightEarlySmoothK = -1

local CloudsCell = {}
function CloudsCell:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  o.initialized = false
  o.clouds = {}
  o.cloudsCount = 0
  o.hoveringClouds = {}
  o.hoveringCloudsCount = 0
  o.lastActive = 0
  o.updateDelay = 10
  o:reuse(o.index)
  return o
end
function CloudsCell:reuse(index)
  self.index = index
  self.pointA = CloudsCell.getCellCenter(self.index)
  self.pointB = self.pointA + vec3(CloudCellSize, 0, CloudCellSize)
  self.center = (self.pointA + self.pointB) / 2
  if self.initialized then
    for i = 1, self.cloudsCount do
      self.clouds[i].pos = self:getPos()
    end
  end
  self.updateDelay = 10
end
function CloudsCell:addCloud(cloudInfo)
  if cloudInfo.hovering then
    self.hoveringCloudsCount = self.hoveringCloudsCount + 1
    self.hoveringClouds[self.hoveringCloudsCount] = cloudInfo
  else
    self.cloudsCount = self.cloudsCount + 1
    self.clouds[self.cloudsCount] = cloudInfo
  end
end
function CloudsCell:getPos(hovering)
  return vec3(
    math.lerp(self.pointA.x, self.pointB.x, math.random()), 
    hovering 
      and math.lerp(HoveringMinHeight, HoveringMaxHeight, math.random())
      or math.lerp(DynCloudsMinHeight, DynCloudsMaxHeight, math.random()),
    math.lerp(self.pointA.z, self.pointB.z, math.random()))
end
local cloudNoise = LowFrequency2DNoise:new{ frequency = 0.001 }
function CloudsCell:initialize()
  self.initialized = true
  local DynamicClouds = 8
  local HoveringClouds = 2
  for i = 1, DynamicClouds + HoveringClouds do
    local hovering = i > DynamicClouds
    local pos = self:getPos(hovering)
    local cloud = createCloud(hovering 
      and (math.random() > 0.3 and CloudTypes.Spread or CloudTypes.Hovering) 
      or CloudTypes.Dynamic, pos)
    local weatherThreshold = cloudNoise:get(pos) * (hovering and 0.4 or 0.95)
    self:addCloud({
      cloud = cloud,
      pos = pos,
      size = cloud.size:clone(),
      procMap = cloud.procMap:clone(),
      procScale = cloud.procScale:clone(),
      opacity = cloud.opacity,
      flatCloud = nil,
      visibilityOffset = 1 + (hovering and 0.5 or math.random()),
      weatherThreshold0 = weatherThreshold,
      weatherThreshold1 = 0.05 + weatherThreshold,
      hovering = hovering,
      cloudAdded = false,
      flatCloudAdded = false
    })
  end
end
function CloudsCell:updateHovering(cameraPos, cellDistance, dt)
  for i = 1, self.hoveringCloudsCount do
    local e = self.hoveringClouds[i]
    local c = e.cloud
    c.position:set(e.pos):sub(cameraPos)

    local d = math.horizontalLength(c.position)
    c.opacity = e.opacity * (1 - math.saturateN(e.visibilityOffset * d * 5 / (cellDistance * CloudCellSize) - 4)) * (1 - 0.2 * CurrentConditions.clouds)

    if c.opacity > 0.001 then
      local weatherCutoff = 1 - math.lerpInvSat(CurrentConditions.clouds, e.weatherThreshold0, e.weatherThreshold1)
      if not c.passedFrustumTest then 
        c.orderBy = math.dot(c.position, c.position) + 1e9
      end
      c.opacity = c.opacity * (0.5 + 0.5 * CurrentConditions.clouds) * (1 - weatherCutoff)
      c.extraFidelity = math.lerp(c.extras.extraFidelity, -2, nightEarlyK)
      c.horizontalHeading = transitionHeadingAngle(c.horizontalHeading, windAngle, dt)

      local up = windDir.x * c.up.x + windDir.y * c.up.z
      local side = windDir.x * c.side.x + windDir.y * c.side.z
      local windDeltaC = (0.15 * windSpeed * dt * CloudShapeMovingSpeed) / c.size.x
      c.noiseOffset.x = c.noiseOffset.x - windDeltaC * side
      c.noiseOffset.y = c.noiseOffset.y - windDeltaC * up
      if not e.cloudAdded then 
        e.cloudAdded = true
        ac.weatherClouds[#ac.weatherClouds + 1] = c
      end
    elseif e.cloudAdded then
      e.cloudAdded = false
      ac.weatherClouds:erase(c)
    end
  end
end
function CloudsCell:updateDynamic(cameraPos, cellDistance, dt)
  local distance = math.horizontalDistance(self.center, cameraPos)
  local distanceK = math.smoothstep(math.lerpInvSat(distance, CloudDistanceShiftEnd, CloudDistanceShiftStart) ^ 0.8)

  local windDelta = windSpeed * dt * CloudShapeMovingSpeed
  local shapeShiftingDelta = dt * CloudShapeShiftingSpeed
  -- local maxDistanceInv = 5 / (cellDistance * CloudCellSize)
  local fadeNearbyInv = 500 / CloudFadeNearby
  local ccClouds = CurrentConditions.clouds
  -- local opacityMult = 1 - 0.2 * ccClouds
  local opacityMult = 1
  local extraThick = math.lerpInvSat(CurrentConditions.clear, 1, 0.5)
  local cloudDark = math.max((1 - CurrentConditions.clear) * 0.5, CurrentConditions.cloudsDensity)
  local cloudsHeight = math.lerp(1, 0.5, CurrentConditions.cloudsDensity)
  local mapYMult = math.lerp(1, 1.2, nightEarlyK)
  local procScaleMult = math.lerp(1, 0.8, nightEarlySmoothK)

  for i = 1, self.cloudsCount do
    local e = self.clouds[i]
    local c = e.cloud
    c.position.x = e.pos.x - cameraPos.x
    c.position.y = e.pos.y * cloudsHeight - cameraPos.y
    c.position.z = e.pos.z - cameraPos.z
    -- c.position:set(e.pos):sub(cameraPos)

    local horDist = math.horizontalLength(c.position)
    local fullDist = math.sqrt(horDist ^ 2 + c.position.y ^ 2)
    local weatherCutoff = 0
    local nearbyCutoff = 0
    local windDeltaC = 0

    c.opacity = math.lerpInvSat(horDist, (CloudCellDistance + 0.5) * CloudCellSize, (CloudCellDistance - 0.5) * CloudCellSize) * e.opacity * opacityMult
      * math.saturateN(1 - fullDist / (4 * CloudCellDistance * CloudCellSize))
      * math.saturateN(fullDist / 200 - 1)
    c.shadowOpacity = c.opacity

    local lookingFromBelow = math.saturateN(c.position.y / fullDist)
    c.normalYExponent = 1 + 2 * lookingFromBelow
    c.topFogBoost = 0.2 * lookingFromBelow

    if c.opacity > 0.001 then
      if not c.passedFrustumTest then 
        c.orderBy = fullDist
      end

      windDeltaC = windDelta / c.size.x
      nearbyCutoff = 2 + c.extras.nearbyCutoffOffset - horDist / math.max(1, c.position.y) * fadeNearbyInv
      weatherCutoff = 1 - math.lerpInvSat(ccClouds, e.weatherThreshold0, e.weatherThreshold1)
      c.cutoff = math.max(math.saturateN(nearbyCutoff), weatherCutoff)
      c.position.y = math.lerp(DynCloudsDistantHeight + c.size.y * 0.4, c.position.y + c.size.y * 0.8, distanceK)
      -- c.position.y = 1000 - ac.getCameraPosition().y
    end

    if c.cutoff < 0.999 and c.opacity > 0.001 then
      SetLightPollution(c)

      c.extraFidelity = math.lerp(c.extras.extraFidelity, -2, nightEarlyK)
      c.procMap.x = math.lerp(c.extras.procMap.x, c.extras.procMap.x * 0.5, extraThick) / mapYMult
      c.procScale:set(c.extras.procScale):scale(procScaleMult)

      local fwd = windDir.x * c.position.x / horDist + windDir.y * c.position.z / horDist
      local side = windDir.x * c.position.z / horDist + windDir.y * -c.position.x / horDist
      c.noiseOffset.x = c.noiseOffset.x + windDeltaC * side * c.procScale.x
      c.procShapeShifting = c.procShapeShifting + (shapeShiftingDelta + windDeltaC * fwd * 0.5) * c.procScale.x
      if not e.cloudAdded then 
        e.cloudAdded = true
        ac.weatherClouds[#ac.weatherClouds + 1] = c
      end

      c.color:set(math.lerp(1, 0.5, cloudDark * c.extras.lowerK))
    elseif e.cloudAdded then
      e.cloudAdded = false
      ac.weatherClouds:erase(c)
    end

    local flatCutoff = math.max(1 - math.saturateN(0.5 + nearbyCutoff), weatherCutoff)
    if flatCutoff < 0.999 and c.opacity > 0.001 then
      local f = e.flatCloud
      if f == nil then
        f = createCloud(CloudTypes.Bottom, c)
        e.flatCloud = f
      end
      f.cutoff = flatCutoff
      f.opacity = c.opacity
      if f.cutoff < 0.999 then
        f.position:set(c.position)
        f.extraDownlit:set(c.extraDownlit)
        f.procMap:set(c.procMap)

        local up = windDir.x * f.up.x + windDir.y * f.up.z
        local side = windDir.x * f.side.x + windDir.y * f.side.z
        f.noiseOffset.x = f.noiseOffset.x - windDeltaC * side
        f.noiseOffset.y = f.noiseOffset.y - windDeltaC * up
        f.procShapeShifting = f.procShapeShifting + (shapeShiftingDelta + windDeltaC * 0.5) * 0.5

        if not f.passedFrustumTest then 
          f.orderBy = fullDist + 10
        end

        if not e.flatCloudAdded then 
          e.flatCloudAdded = true
          ac.weatherClouds[#ac.weatherClouds + 1] = f
        end
      end
    elseif e.flatCloudAdded then
      e.flatCloudAdded = false
      ac.weatherClouds:erase(e.flatCloud)
    end
  end
end
local cloudCellRadius = #vec2.new(CloudCellSize)
function CloudsCell:update(cameraPos, cellDistance, dt)
  local isVisible = ac.testFrustumIntersection(vec3.tmp():set(self.center):sub(cameraPos), cloudCellRadius)
  local updateRate = not isVisible and 10 or 0
  if self.updateDelay >= updateRate then
    if not self.initialized then
      self:initialize()
    end

    if self.updateDelay > 5 then
      self.updateDelay = self.updateDelay - 1
    else
      self.updateDelay = 0
    end
    
    self:updateHovering(cameraPos, cellDistance, dt)
    self:updateDynamic(cameraPos, cellDistance, dt)
  else
    self.updateDelay = self.updateDelay + 1
  end
end
function CloudsCell:deactivate() 
  for i = 1, self.cloudsCount do
    local e = self.clouds[i]
    if e.cloudAdded then 
      ac.weatherClouds:erase(e.cloud) 
      e.cloudAdded = false
    end
    if e.flatCloudAdded then 
      ac.weatherClouds:erase(e.flatCloud) 
      e.flatCloudAdded = false
    end
  end
end
function CloudsCell:destroy()
  for i = 1, self.cloudsCount do
    local e = self.clouds[i]
    ac.weatherClouds:erase(e.cloud)
    ac.weatherClouds:erase(e.flatCloud)
  end
end
function CloudsCell.getCellOrigin(pos)
  return vec3(math.floor(pos.x / CloudCellSize) * CloudCellSize, 0, math.floor(pos.z / CloudCellSize) * CloudCellSize)
end
function CloudsCell.getCellCenter(cellIndex)
  local x = math.floor(cellIndex / 1e5 - 100) * CloudCellSize
  local y = (math.fmod(cellIndex, 1e5) - 100) * CloudCellSize
  return vec3(x, 0, y)
end
function CloudsCell.getCellIndex(pos)
  return math.floor(100 + pos.x / CloudCellSize) * 1e5 + math.floor(100 + pos.z / CloudCellSize)
end
function CloudsCell.getCellNeighbour(cell, x, y)
  return cell + x + y * 1e5
end

local cloudCells = {}
local cloudCellsList = {}
local cellsTotal = 0
local activeIndex = 0
local windOffset = vec2()
local cellsPool = {}
local cellsPoolTotal = 0

local function createCloudCell(cellIndex)
  local c = nil
  if cellsPoolTotal > 0 then 
    c = cellsPool[cellsPoolTotal]
    table.remove(cellsPool, cellsPoolTotal)
    cellsPoolTotal = cellsPoolTotal - 1
    c:reuse(cellIndex)
  else
    c = CloudsCell:new{ index = cellIndex }
  end
  cloudCells[cellIndex] = c
  cloudCellsList[cellsTotal + 1] = c
  cellsTotal = cellsTotal + 1
  return c
end

local cameraPos = vec3()
local cleanUp = 0

local function updateCloudCells(dt)
  if CurrentConditions.clouds <= 0.0001 and (cellsPoolTotal > 1 or cellsTotal > 1) then 
    if activeIndex >= 0 then
      activeIndex = -1

      for i = cellsTotal, 1, -1 do
        local cell = cloudCellsList[i]
        cellsPoolTotal = cellsPoolTotal + 1
        cellsPool[cellsPoolTotal] = cell
        cell:deactivate()
      end
      cloudCellsList = {}
      cloudCells = {}
      cellsTotal = 0
    end
    return
  end

  activeIndex = activeIndex + 1
  if activeIndex > 1e6 then activeIndex = 0 end

  ac.getCameraPositionTo(cameraPos)
  ac.fixHeadingInvSelf(cameraPos)
  cameraPos.x = cameraPos.x + windOffset.x
  cameraPos.z = cameraPos.z + windOffset.y
  windOffset:add(windDir * (windSpeed * dt))

  local cellIndex = CloudsCell.getCellIndex(cameraPos)
  local cellDistance = math.ceil(CloudCellDistance * (1 - CurrentConditions.fog * 0.3))
  for x = -cellDistance, cellDistance do
    for y = -cellDistance, cellDistance do
      local n = CloudsCell.getCellNeighbour(cellIndex, x, y)
      local c = cloudCells[n]
      if c == nil then 
        c = createCloudCell(n)
      end
      if c then 
        c:update(cameraPos, cellDistance, dt) 
        c.lastActive = activeIndex
      end
    end
  end

  if cleanUp > 0 then
    cleanUp = cleanUp - 1
  else
    for i = cellsTotal, 1, -1 do
      local cell = cloudCellsList[i]
      if cell.lastActive ~= activeIndex then
        table.remove(cloudCellsList, i)
        cloudCells[cell.index] = nil
        cellsTotal = cellsTotal - 1
        cellsPoolTotal = cellsPoolTotal + 1
        cellsPool[cellsPoolTotal] = cell
        cell:deactivate()
      end
    end
    cleanUp = 20
  end
end

-- Static clouds
local staticClouds = {}
local staticCloudsCount = 0
local function addStaticCloud(cloud)
  staticCloudsCount = staticCloudsCount + 1
  staticClouds[staticCloudsCount] = cloud
  ac.weatherClouds[#ac.weatherClouds + 1] = cloud
end
local function updateStaticClouds(dt)
  local cutoff = math.saturate(1.1 - CurrentConditions.clouds * 1.5) ^ 2
  local lightPollution = GetRemoteLightPollution()
  local dtLocal = math.min(dt, 0.05)
  local procMapLerp = math.max(0, CurrentConditions.clouds - 0.5)
  for i = 1, staticCloudsCount do
    local c = staticClouds[i]
    local withWind = math.dot(vec2(c.side.x, c.side.z), windDir)
    c.noiseOffset.x = c.noiseOffset.x + (0.2 + math.saturate(windSpeed / 100)) * 0.002 * dtLocal * withWind
    c.procShapeShifting = c.procShapeShifting + (1 + math.saturate(windSpeed / 100) * (1 - withWind)) * 0.002 * dtLocal
    c.extraDownlit:set(lightPollution)
    c.cutoff = cutoff
    c.opacity = c.extras.opacity
    c.procMap.y = math.lerp(c.extras.procMap.y, c.extras.procMap.x, procMapLerp)
  end
end
for j = 1, 35 do
  local angle = math.pi * 2 * (j + math.random()) / 35
  local lowRow = vec2(math.sin(angle), math.cos(angle))
  local count = math.floor(math.random() * 2.5 + 1)
  for i = 1, count do
    addStaticCloud(createCloud(CloudTypes.Low, lowRow, 1 - i / count))
    lowRow = (lowRow + math.randomVec2():normalize() * 0.2):normalize()
  end
end

-- local testCloud = createCloud(CloudTypes.Dynamic, vec3(0, 1, 2), 0)
-- ac.weatherClouds[#ac.weatherClouds + 1] = testCloud

function UpdateClouds(dt)
  windDir = CurrentConditions.windDir
  windSpeed = CurrentConditions.windSpeed * 4 -- clouds move faster up there
  windAngle = math.atan2(windDir.y, -windDir.x) * 180 / math.pi

  nightEarlyK = math.smoothstep(math.lerpInvSat(SunDir.y, 0.3, -0.05))
  nightEarlySmoothK = nightEarlySmoothK == -1 and nightEarlyK or math.applyLag(nightEarlySmoothK, nightEarlyK, 0.99, ac.getSim().dt)

  updateCloudCells(dt)
  updateStaticClouds(dt)
  ac.sortClouds()
  ac.invalidateCloudMaps()
end

-- local dome = ac.SkyCloudsCover()
-- dome.colorMultiplier = rgb(3, 3, 3):scale(0.1)
-- dome.opacityMultiplier = 0.5
-- dome.shadowOpacityMultiplier = 0
-- dome.ignoreTextureAlpha = false
-- dome:setFogParams(1, 3)
-- dome:setTexture(__dirname..'/../_0/cloudy_day_4k.dds')
-- dome:setMaskTexture(__dirname..'/../_0/mask.dds')
-- dome.maskOpacityMultiplier = 0.5
-- ac.weatherCloudsCovers:push(dome)
