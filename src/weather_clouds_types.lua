-- How many textures of different types are available, with sizes and offsets in the atlas
local CloudTextures = {
  Blurry = { group = 'b', count = 16, start = vec2(0, 0/8), size = vec2(2/16, 1/8) },
  Hovering = { group = 'h', count = 16, start = vec2(0, 2/8), size = vec2(2/16, 1/8) },
  Spread = { group = 's', count = 6, start = vec2(0, 4/8), size = vec2(2/16, 1/8) },
  Flat = { group = 'f', count = 5, start = vec2(0, 6/8), size = vec2(2/16, 1/8) },
  Bottoms = { group = 'd', count = 5, start = vec2(0, 7/8), size = vec2(1/16, 1/8) },
}

-- Various helper functions for clouds
local cloudutils = {}
function cloudutils.setPos(cloud, params)
  params = params or {}
  local height = params.height or (100 + math.random() * 200)
  local sizeMult = params.size or 1
  local aspectRatio = params.aspectRatio or 0.5
  local distanceMult = params.distance or 10
  local pos = params.pos and params.pos:clone():normalize() or math.randomVec2():normalize()
  cloud.size = vec2(100, 100 * aspectRatio) * sizeMult * (1 + 0.5 * math.random()) * distanceMult
  cloud.position = vec3(400 * pos.x, height, 400 * pos.y) * distanceMult
  cloud.horizontal = params.horizontal or false
  cloud.customOrientation = params.customOrientation or false
  cloud.noTilt = params.noTilt or false
  cloud.procScale = vec2(1.0, (params.horizontal and 1 or 1.2) * aspectRatio) * (params.procScale or 1) * sizeMult
end

function cloudutils.setTexture(cloud, type)
  local index = math.floor(math.random() * type.count)
  if CloudUseAtlas then
    local start = type.start:clone()
    for i = 1, index do
      start.x = start.x + type.size.x
      if start.x >= 1 then
        start.x = start.x - 1
        start.y = start.y + type.size.y
      end
    end
    cloud.texStart:set(start)
    cloud.texSize:set(type.size)
    cloud:setTexture('clouds/atlas.dds')
  else
    cloud:setTexture('clouds/' .. type.group .. index .. '.png')
  end
  cloud.flipHorizontal = math.random() > 0.5
  return index
end
function cloudutils.setProcNormalShare(cloud, globalShare, totalIntensity)
  globalShare = globalShare or 0.5
  totalIntensity = totalIntensity or 1
  cloud.procNormalScale = vec2((1 - globalShare) * totalIntensity, globalShare * totalIntensity)
end

-- Different types of clouds
CloudTypes = {}
function CloudTypes.Basic(cloud, pos)
  cloudutils.setTexture(cloud, CloudTextures.Blurry)
  cloud.procMap = vec2(0.6, 0.85) + math.random() * 0.15
  cloud.procSharpnessMult = math.random()
  cloudutils.setProcNormalShare(cloud, 0.6)
  cloudutils.setPos(cloud, {
    pos = pos,
    size = (1 + math.random()) * 2,
    procScale = 0.45
  })
end
function CloudTypes.Dynamic(cloud, pos)
  local typeRandom = math.random()
  local fidelityRandom = math.random()
  local sizeRandom = math.random()

  if typeRandom > 0.95 then
    -- Let’s increase variety some more
    cloudutils.setTexture(cloud, CloudTextures.Hovering)
  elseif typeRandom > 0.9 then
    cloudutils.setTexture(cloud, CloudTextures.Spread)
  else
    cloudutils.setTexture(cloud, CloudTextures.Blurry)
  end
  cloud.occludeGodrays = true
  cloud.procMap = vec2(0.6, 0.9)
  cloud.procSharpnessMult = math.lerp(0, 0.5, fidelityRandom)
  cloud.extraFidelity = math.lerp(0.7, 0.3, fidelityRandom)
  cloud.receiveShadowsOpacityMult = 1
  cloudutils.setProcNormalShare(cloud, math.lerp(1, 0.7, fidelityRandom), 1.5)

  local cloudSize = math.lerp(2, 5, sizeRandom) * CloudSpawnScale
  cloudutils.setPos(cloud, { 
    pos = pos, 
    size = cloudSize, 
    procScale = math.lerp(0.8, 1.2, fidelityRandom) / cloudSize
  })

  cloud.extras.procMap = cloud.procMap:clone()
  cloud.extras.procScale = cloud.procScale:clone()
  cloud.extras.nearbyCutoffOffset = math.lerp(-0.3, 0.3, math.random())
  cloud.extras.extraFidelity = cloud.extraFidelity
  cloud.extras.lowerK = math.lerpInvSat(pos.y, DynCloudsMaxHeight, DynCloudsMinHeight)

  -- cloud.size:set(0.001, 0.001)
end
function CloudTypes.Bottom(cloud, mainCloud)
  cloudutils.setTexture(cloud, CloudTextures.Bottoms)
  cloud.occludeGodrays = true
  cloud.horizontal = true
  cloud.horizontalHeading = math.random() * 360
  cloud.procScale:set(0.8, 0.8)
  cloud.procMap = mainCloud.procMap * vec2(0.8, 1)
  cloud.procSharpnessMult = mainCloud.procSharpnessMult
  cloud.extraFidelity = mainCloud.extraFidelity
  local size = (mainCloud.size.x + mainCloud.size.y) / 2
  cloud.size:set(size, size)
  cloudutils.setProcNormalShare(cloud, 0.2, 1.8)
  cloud.material = CloudMaterials.Bottom
  cloud.receiveShadowsOpacityMult = mainCloud.receiveShadowsOpacityMult

  -- cloud.size:set(0.001, 0.001)
end
function CloudTypes.Hovering(cloud, pos)
  cloudutils.setTexture(cloud, CloudTextures.Hovering)
  cloud.procMap = vec2(0.8, 0.9) + math.random() * 0.15
  cloud.procSharpnessMult = 0
  cloud.extraFidelity = 0.6
  cloudutils.setProcNormalShare(cloud, 0.2, 2)
  cloudutils.setPos(cloud, { 
    pos = pos, 
    horizontal = true,
    size = math.lerp(8, 12, math.random()) * CloudSpawnScale, 
    procScale = 0.2 / CloudSpawnScale
  })
  cloud.horizontalHeading = -1
  cloud.material = CloudMaterials.Hovering
  cloud.extras.extraFidelity = cloud.extraFidelity

  -- cloud.size:set(0.001, 0.001)
end
function CloudTypes.Spread(cloud, pos)
  cloudutils.setTexture(cloud, CloudTextures.Spread)
  cloud.procMap = vec2(0.4, 1)
  cloud.procSharpnessMult = 0
  cloud.extraFidelity = 1
  cloudutils.setProcNormalShare(cloud, 0.2)
  local isSpread = math.random() > 0.5
  cloudutils.setPos(cloud, { 
    pos = pos, 
    horizontal = true,
    size = math.lerp(4, 6, math.random()) * CloudSpawnScale, 
    procScale = 0.1 / CloudSpawnScale,
    aspectRatio = 0.33
  })
  cloud.horizontalHeading = -1
  cloud.material = CloudMaterials.Spread
  cloud.procScale:mul(vec2(1, 4))
  cloud.opacity = math.lerp(0.15, 0.35, math.random())
  cloud.extras.extraFidelity = cloud.extraFidelity

  -- cloud.size:set(0.001, 0.001)
end
function CloudTypes.Low(cloud, pos, distance)
  local index = cloudutils.setTexture(cloud, CloudTextures.Flat)
  local heightFixes = { 0, 4, -10 }
  cloud.occludeGodrays = true
  cloud.procMap = vec2(0.65, 0.95)
  cloud.procSharpnessMult = math.random() * 0.5
  cloud.extraFidelity = 1.2
  cloud.color = rgb(1, 1, 1)
  cloud.opacity = 0.8
  -- cloud.fogMultiplier = 5
  cloud.orderBy = 1e12 + distance * 1e10
  cloud.extras.opacity = cloud.opacity
  cloud.extras.extraFidelity = cloud.extraFidelity
  cloud.extras.procMap = cloud.procMap:clone()
  cloudutils.setProcNormalShare(cloud, 0.2, 2)
  cloudutils.setPos(cloud, { 
    pos = pos, 
    height = CalculateHorizonCloudYCoordinate(pos:clone():normalize()) - 5 * distance + (heightFixes[index + 1] or 0), 
    distance = 50 + distance, 
    size = 1.3, 
    aspectRatio = 0.3
  })
  cloud.receiveShadowsOpacityMult = 0
  
  -- cloud.size:set(0.001, 0.001)
end
function CloudTypes.Test(cloud, pos, distance)
  local index = cloudutils.setTexture(cloud, CloudTextures.Bottoms)
  cloud.occludeGodrays = true
  cloud.procMap = vec2(0.65, 0.85)
  cloud.procSharpnessMult = 0
  cloud.extraFidelity = 0
  cloud.color = rgb(1, 1, 1)
  cloud.opacity = 1
  cloud.orderBy = 0
  cloud.cutoff = 0
  cloudutils.setProcNormalShare(cloud, 0, 2)
  cloudutils.setPos(cloud, { 
    pos = pos, 
    size = 7, 
    procScale = 1
  })
  cloud.receiveShadowsOpacityMult = 0
end
