-- Experimental RainFX audio implementation. Might be moved to C++ side later once everything is sorted out.

local sim = nil ---@type ac.StateSim
local rainAmbientAudio = nil ---@type ac.AudioEvent
local rainAmbientThunderAudio = nil ---@type ac.AudioEvent
local rainCarInterior = nil ---@type ac.AudioEvent
local rainCarExterior = nil ---@type ac.AudioEvent
local rainGrass = nil ---@type ac.AudioEvent
local rainGravel = nil ---@type ac.AudioEvent
local rainSkidsInterior = nil ---@type ac.AudioEvent[]
local rainSkidsExterior = nil ---@type ac.AudioEvent[]

local rainActive = false
local thunderActive = false
local rainGrassActive = false
local rainGravelActive = false

local function startRainAudio()
  if not rainAmbientAudio then
    sim = ac.getSim()
    rainAmbientAudio = ac.AudioEvent('event:/extension_common/rain_amb', true)
    rainAmbientThunderAudio = ac.AudioEvent('event:/extension_common/rain_amb_thunder', true)
    rainCarInterior = ac.AudioEvent('event:/extension_common/rain_car_int', false)
    rainCarExterior = ac.AudioEvent('event:/extension_common/rain_car_ext', true)
    rainGrass = ac.AudioEvent('event:/extension_common/rain_grass', true)
    rainGravel = ac.AudioEvent('event:/extension_common/rain_gravel', true)
    rainSkidsInterior = table.range(4, function () return ac.AudioEvent('event:/extension_common/rain_skid_int', false) end)
    rainSkidsExterior = table.range(4, function () return ac.AudioEvent('event:/extension_common/rain_skid_ext', true) end)

    rainAmbientAudio.cameraInteriorMultiplier = 0.5
    rainAmbientThunderAudio.cameraInteriorMultiplier = 0.5
    rainCarInterior.cameraInteriorMultiplier = 1
    rainGrass.cameraInteriorMultiplier = 1
    rainGravel.cameraInteriorMultiplier = 1
    for i = 1, 4 do
      rainSkidsInterior[i].cameraInteriorMultiplier = 1
      rainSkidsExterior[i].cameraInteriorMultiplier = 0.5
    end

    rainGrass:setDistanceMin(4)
    rainGrass:setDistanceMax(10)
    rainGrass:setConeSettings(360, 360, 1)
  end

  rainAmbientAudio:start()
end

local cameraPos = vec3()
local cameraDir = vec3()
local groundPos = vec3()
local dirUp = vec3(0, 1, 0)
local dirDown = vec3(0, -1, 0)
local dirFwd = vec3(0, 0, 1)
local dirBack = vec3(0, 0, -1)
local carAudioPlaying = false
local grassPos = vec3()
local gravelPos = vec3()

---@return ac.StateCar?
local function nearestCar()
  if sim.focusedCar == -1 then return nil end
  local car = ac.getCar(sim.focusedCar)
  return car and car.position:closerToThan(cameraPos, 10) and car or nil
end

local appliedWet = 0
local puddleHitSmooth = 0
local wheelGrassSmooth = {0,0,0,0}
local wheelDirtSmooth = {0,0,0,0}
local resetSet = false

local function setWetMultiplier(mult)
  ac.setAudioEventMultiplier('event:/surfaces/grass', mult)
  ac.setAudioEventMultiplier('event:/surfaces/sand', mult)
  ac.setAudioEventMultiplier('event:/cars/?/skid_ext', mult)
  ac.setAudioEventMultiplier('event:/cars/?/skid_int', mult)

  if not resetSet then
    resetSet = true
    ac.onRelease(function()
      setWetMultiplier(1)
    end)
  end
end

local function tonemap(x)
  if x < 0 then return 0 end
  return x / (1 + x)
end

local function updateRainAudio(rainAmount, rainWetness, rainWater, dt)
  ac.getCameraPositionTo(cameraPos)
  ac.getCameraForwardTo(cameraDir)
  groundPos:set(cameraPos.x, ac.getGroundYApproximation(), cameraPos.z)

  local localOcclusion = ac.sampleCameraAO()
  if localOcclusion == 1 then
    localOcclusion = ac.getCameraOcclusion(dirUp)
  end

  -- local volume = ac.getAudioVolume(ac.AudioChannel.Rain)
  local volume = 1
  local wetTrack = localOcclusion * math.lerpInvSat(rainWetness, 0.002, 0.01)
  local wetVolume = wetTrack * volume
  local thunderMix = CurrentConditions.thunder
  local cloudsDensity = CurrentConditions.cloudsDensity
  local localRain = rainAmount * localOcclusion

  if math.abs(wetVolume - appliedWet) > 0.01 then
    appliedWet = wetVolume
    setWetMultiplier(1 - wetVolume)
  end

  if thunderMix > 0 and not thunderActive then
    thunderActive = true
    rainAmbientThunderAudio:start()
  end
  
  local localRainVolume = volume * (math.lerpInvSat(localRain, 0, 0.1) + localRain)
  local localRainIntensity = math.lerp(0.15, 1, localRain ^ 0.5)
  rainAmbientAudio.volume = localRainVolume * (1 - thunderMix)
  rainAmbientThunderAudio.volume = localRainVolume * thunderMix

  local car = nearestCar()
  rainAmbientAudio:setPosition(groundPos, dirUp, dirFwd, car and car.velocity or nil)
  rainAmbientAudio:setParam('intensity\n' --[[ yup, that’s a bug with that FMOD soundbank I use ]], localRainIntensity)

  if thunderActive then
    rainAmbientThunderAudio:setPosition(cameraPos, dirUp, dirFwd, car and car.velocity or nil)
    rainAmbientThunderAudio:setParam('intensity\n', localRainIntensity)
  end

  local speed = 400 * cloudsDensity + (car and car.speedKmh or 0)
  if thunderActive then
    rainAmbientThunderAudio:setParam('speed', speed)
  end

  if carAudioPlaying ~= (car ~= nil) then
    carAudioPlaying = car ~= nil
    rainCarExterior:resumeIf(carAudioPlaying)

    if not car then
      rainCarInterior:stop()
      for i = 1, 4 do
        rainSkidsExterior[i]:stop()
        rainSkidsInterior[i]:stop()
      end
    end
  end

  if not car then
    if rainGrassActive then
      rainGrassActive = false
      rainGrass:stop()
    end
    if rainGravelActive then
      rainGravelActive = false
      rainGravel:stop()
    end
    return
  end

  rainCarExterior.volume = volume * (1 + thunderMix) * (1 + cloudsDensity) * math.lerpInvSat(car.position:distance(cameraPos), 10, 0) * (0.2 + math.saturateN(car.speedKmh / 200))
  rainCarExterior:setPosition(car.position, dirDown, dirBack, car and car.velocity or nil)
  rainCarExterior:setParam('intensity', localRain)
  rainCarExterior:setParam('speed', car.speedKmh)
  
  rainCarInterior.volume = volume * (1 + thunderMix) * (1 + cloudsDensity)
  rainCarInterior:resumeIf(car.focusedOnInterior)
  rainCarInterior:setPosition(car.position, dirDown, dirBack, car and car.velocity or nil)
  rainCarInterior:setParam('intensity', localRain)
  rainCarInterior:setParam('speed', car.speedKmh)

  local surfaceGrass = 0
  local surfaceGravel = 0
  local puddleHit = false
  grassPos:set(0, 0, 0)
  gravelPos:set(0, 0, 0)
  for i = 0, 3 do
    local wheel = car.wheels[i]
    local surfaceType = wheel.surfaceType

    local puddleHitWheel = wheel.waterThickness > 0.003
    local newWaterGrassSmooth = math.applyLag(wheelGrassSmooth[i + 1], surfaceType == ac.SurfaceType.Grass and 0.25 * wheel.loadK * wetTrack
      or (math.lerpInvSat(wheel.waterThickness, 0.0002, 0.001) * 0.1 + math.lerpInvSat(wheel.waterThickness, 0.003, 0.005)) * wheel.loadK, puddleHitWheel and 0.6 or 0.8, dt)
    wheelGrassSmooth[i + 1] = newWaterGrassSmooth
    if newWaterGrassSmooth > 0.001 then
      surfaceGrass = surfaceGrass + newWaterGrassSmooth
      grassPos:addScaled(wheel.contactPoint, newWaterGrassSmooth)
      if puddleHitWheel then puddleHit = true end
    end
    
    local newWaterDirtSmooth = math.applyLag(wheelDirtSmooth[i + 1], surfaceType == ac.SurfaceType.Dirt and 0.25 * wheel.loadK or 0, 0.6, dt)
    wheelDirtSmooth[i + 1] = newWaterDirtSmooth
    if newWaterDirtSmooth > 0.001 then
      surfaceGravel = surfaceGravel + newWaterDirtSmooth
      gravelPos:addScaled(wheel.contactPoint, newWaterDirtSmooth)
    end

    local slipAdjusted = wheel.ndSlip - wheel.waterThickness * 800
    local targetVolume = wheel.surfaceGrip > 0.9 and not wheel.isBlown
      and tonemap(slipAdjusted - 1) * math.lerpInvSat(car.speedKmh, 4, 40) * 0.4 or 0
    local newVolume = math.applyLag(rainSkidsExterior[i + 1].volume, targetVolume, 0.6, dt)
    rainSkidsExterior[i + 1].volume = newVolume
    rainSkidsExterior[i + 1].pitch = 1 + tonemap(wheel.angularSpeed / 50)
    rainSkidsExterior[i + 1]:resumeIf(newVolume > 0.01)
    rainSkidsExterior[i + 1]:setPosition(wheel.position, dirUp, dirFwd, wheel.velocity)
    if car.focusedOnInterior then
      rainSkidsInterior[i + 1].volume = newVolume
      rainSkidsInterior[i + 1].pitch = 1 + tonemap(wheel.angularSpeed / 50)
      rainSkidsInterior[i + 1]:resumeIf(newVolume > 0.01)
      rainSkidsInterior[i + 1]:setPosition(wheel.position, dirUp, dirFwd, wheel.velocity)
    else
      rainSkidsInterior[i + 1]:resumeIf(false)
    end
  end

  puddleHitSmooth = math.applyLag(puddleHitSmooth, puddleHit and 1 or 0, puddleHit and 0.6 or 0.8, dt)

  if rainGrassActive ~= (surfaceGrass > 0) then
    rainGrassActive = not rainGrassActive
    rainGrass:resumeIf(rainGrassActive)
  end

  if rainGrassActive then
    rainGrass.volume = 2.4 * surfaceGrass
    rainGrass.pitch = car.focusedOnInterior and math.lerp(1, 0.5, puddleHitSmooth) or 1
    grassPos:scale(1 / surfaceGrass)
    if car.focusedOnInterior then
      grassPos:addScaled(cameraPos, 4):scale(0.2):addScaled(cameraDir, 1)
    end
    rainGrass:setPosition(grassPos, dirUp, dirFwd, car and car.velocity or nil)
    rainGrass:setParam('speed', car.speedKmh * (1 + puddleHitSmooth))
  end

  if rainGravelActive ~= (surfaceGravel > 0 and wetVolume > 0.01) then
    rainGravelActive = not rainGravelActive
    rainGravel:resumeIf(rainGravelActive)
  end

  if rainGravelActive then
    rainGravel.volume = 4 * wetVolume * math.sqrt(surfaceGravel)
    rainGravel:setPosition(gravelPos:scale(1 / surfaceGravel), dirUp, dirFwd, car and car.velocity or nil)
    rainGravel:setParam('speed', car.speedKmh)
  end
end

local function stopRainAudio()
  rainActive = false
  rainAmbientAudio:stop()
  rainAmbientThunderAudio:stop()
  rainCarInterior:stop()
  rainCarExterior:stop()
  rainGrass:stop()
  rainGravel:stop()
  
  if appliedWet ~= 0 then
    appliedWet = 0
    setWetMultiplier(1)
  end
end

function ApplyAudio(dt)
  local rain = 1.1 * CurrentConditions.rain / (0.1 + CurrentConditions.rain)
  local wetness = CurrentConditions.wetness
  local water = CurrentConditions.water
  if rain > 0 or wetness > 0 or water > 0 then
    if not rainActive then
      rainActive = true
      startRainAudio()
    end
    updateRainAudio(rain, wetness, water, dt)
  elseif rainActive then
    stopRainAudio()
  end
end
