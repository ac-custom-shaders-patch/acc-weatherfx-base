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
    rainGrass.cameraInteriorMultiplier = 0.5
    rainGravel.cameraInteriorMultiplier = 0.5
    for i = 1, 4 do
      rainSkidsInterior[i].cameraInteriorMultiplier = 1
      rainSkidsExterior[i].cameraInteriorMultiplier = 0.5
    end
  end

  rainAmbientAudio:start()
end

local pos = vec3()
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
  return car and car.position:closerToThan(pos, 10) and car or nil
end

local appliedWet = 0
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

local function updateRainAudio(rainAmount, dt)
  ac.getCameraPositionTo(pos)
  groundPos:set(pos.x, ac.getGroundYApproximation(), pos.z)

  local localOcclusion = ac.sampleCameraAO()
  if localOcclusion == 1 then
    localOcclusion = ac.getCameraOcclusion(dirUp)
  end

  local volume = ac.getAudioVolume(ac.AudioChannel.Rain)
  local wetVolume = localOcclusion * volume * CurrentConditions.wet
  local thunderMix = CurrentConditions.thunder
  local cloudsDensity = CurrentConditions.cloudsDensity
  local localRain = rainAmount * localOcclusion

  if math.abs(wetVolume - appliedWet) > 0.02 then
    appliedWet = wetVolume
    setWetMultiplier(1 - wetVolume)
  end

  if thunderMix > 0 and not thunderActive then
    thunderActive = true
    rainAmbientThunderAudio:start()
  end
  
  rainAmbientAudio.volume = volume * (1 - thunderMix)
  rainAmbientThunderAudio.volume = volume * thunderMix

  local car = nearestCar()
  rainAmbientAudio:setPosition(groundPos, dirUp, dirFwd, car and car.velocity or nil)
  rainAmbientAudio:setParam('intensity\n' --[[ yup, that’s a bug with that FMOD soundbank I have ]], localRain)

  if thunderActive then
    rainAmbientThunderAudio:setPosition(pos, dirUp, dirFwd, car and car.velocity or nil)
    rainAmbientThunderAudio:setParam('intensity\n', localRain)
  end

  local speed = 400 * cloudsDensity + (car and car.speedKmh or 0)
  if thunderActive then
    rainAmbientThunderAudio:setParam('speed', speed)
  end

  if carAudioPlaying ~= (car ~= nil) then
    carAudioPlaying = car ~= nil
    rainCarExterior:resumeIf(carAudioPlaying)
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

  rainCarExterior.volume = volume * (1 + thunderMix) * (1 + cloudsDensity) * math.lerpInvSat(car.position:distance(pos), 10, 0) * (0.2 + math.saturateN(car.speedKmh / 200))
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
  grassPos:set(0, 0, 0)
  gravelPos:set(0, 0, 0)
  for i = 0, 3 do
    local wheel = car.wheels[i]
    local surfaceType = wheel.surfaceType

    local newWaterGrassSmooth = math.applyLag(wheelGrassSmooth[i + 1], surfaceType == ac.SurfaceType.Grass and 0.6 or wheel.waterThickness > 0.001 and 0.9 or 0, 0.6, dt)
    wheelGrassSmooth[i + 1] = newWaterGrassSmooth
    if newWaterGrassSmooth > 0.001 then
      surfaceGrass = surfaceGrass + newWaterGrassSmooth
      grassPos:addScaled(wheel.contactPoint, newWaterGrassSmooth)
    end
    
    local newWaterDirtSmooth = math.applyLag(wheelDirtSmooth[i + 1], surfaceType == ac.SurfaceType.Dirt and 0.25 or 0, 0.6, dt)
    wheelDirtSmooth[i + 1] = newWaterDirtSmooth
    if newWaterDirtSmooth > 0.001 then
      surfaceGravel = surfaceGravel + newWaterDirtSmooth
      gravelPos:addScaled(wheel.contactPoint, newWaterDirtSmooth)
    end

    local targetVolume = wheel.surfaceGrip > 0.9 and not wheel.isBlown
      and math.lerpInvSat(wheel.ndSlip, 1, 2.5) * math.lerpInvSat(car.speedKmh, 2, 10) * 0.4 or 0
    local newVolume = math.applyLag(rainSkidsExterior[i + 1].volume, targetVolume, 0.6, dt)
    rainSkidsExterior[i + 1].volume = newVolume
    rainSkidsExterior[i + 1].pitch = 1 + math.saturateN(wheel.angularSpeed / 100)
    rainSkidsExterior[i + 1]:resumeIf(newVolume > 0.01)
    rainSkidsExterior[i + 1]:setPosition(wheel.position, dirUp, dirFwd, wheel.velocity)
    if car.focusedOnInterior then
      rainSkidsInterior[i + 1].volume = newVolume
      rainSkidsInterior[i + 1].pitch = 1 + math.saturateN(wheel.angularSpeed / 100)
      rainSkidsInterior[i + 1]:resumeIf(newVolume > 0.01)
      rainSkidsInterior[i + 1]:setPosition(wheel.position, dirUp, dirFwd, wheel.velocity)
    else
      rainSkidsInterior[i + 1]:resumeIf(false)
    end
  end

  if rainGrassActive ~= (surfaceGrass > 0 and wetVolume > 0.01) then
    rainGrassActive = not rainGrassActive
    rainGrass:resumeIf(rainGrassActive)
  end

  if rainGrassActive then
    rainGrass.volume = 2 * wetVolume * math.sqrt(surfaceGrass)
    rainGrass:setPosition(grassPos:scale(1 / surfaceGrass), dirUp, dirFwd, car and car.velocity or nil)
    rainGrass:setParam('speed', car.speedKmh)
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
  local rain = CurrentConditions.rain
  if rain > 0 then
    if not rainActive then
      rainActive = true
      startRainAudio()
    end
    updateRainAudio(rain, dt)
  elseif rainActive then
    stopRainAudio()
  end
end
