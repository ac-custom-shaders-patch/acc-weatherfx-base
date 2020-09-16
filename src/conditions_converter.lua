--------
-- Reads weather conditions and converts them into a bunch of very simple to interpret values for the rest of the script.
--------

-- Global table with converted weather values
CurrentConditions = {
  fog = 0, -- how foggy is it, from 0 to 1
  clear = 1, -- how clear is the sky, turns to grey with 0
  clouds = 0, -- how many shapy clouds are up there
  cloudsOpacity = 1, -- how visible are clouds
  lightTint = rgb(1, 1, 1), -- color tint for light
  fogTint = rgb(0.4, 0.6, 1), -- color tint for fog
  saturation = 1, -- how saturated are the colors
  wet = 0, -- wet input for track configs
  cold = 0.25, -- something to make weather more varying: changed to random value each time
    -- weather type is changed. original idea is to make sunsets more red if next day is going
    -- to be colder: if I remember correctly, that is what red sunsets usually mean.
  windDir = vec2(0, 1), -- normalized wind direction (for clouds)
  windSpeed = 5 -- wind speed in m/s (for clouds)
}

-- Values for randomized wind
local windValue = 0
local windSpeed = 0

-- Updates wind, randomizing it a bit
local function updateWind(conditions, dt)
  -- conditions.wind.direction = 0
  CurrentConditions.windDir:set(
    math.sin(-conditions.wind.direction * math.pi / 180), 
    math.cos(conditions.wind.direction * math.pi / 180))
  windSpeed = math.clamp(windSpeed + (math.random() * 2 - 1) * dt, -0.3, 0.3)
  if windValue == 0 then windValue = (conditions.wind.speedFrom + conditions.wind.speedTo) / 2 end
  windValue = math.clamp(windValue + windSpeed * dt, conditions.wind.speedFrom, conditions.wind.speedTo)
  CurrentConditions.windSpeed = windValue / 3.6
end

-- Fills a big table with values for different weathers (those values could definitely use some tweaking)
local function fillValues(v, T)
  v[T.NoClouds] =        { fog = 0.0, clear = 1.0, clouds = 0.0, fogTint = rgb(0.4, 0.6, 1) }
  v[T.Clear] =           { fog = 0.0, clear = 1.0, clouds = 0.025, cloudsOpacity = 0.5, fogTint = rgb(0.4, 0.6, 1) }
  v[T.FewClouds] =       { fog = 0.0, clear = 1.0, clouds = 0.1, fogTint = rgb(0.4, 0.6, 1) }
  v[T.ScatteredClouds] = { fog = 0.0, clear = 1.0, clouds = 0.4, fogTint = rgb(0.4, 0.6, 1) }
  v[T.BrokenClouds] =    { fog = 0.0, clear = 0.9, clouds = 0.8, fogTint = rgb(0.4, 0.6, 1) }
  -- v[T.OvercastClouds] =  { fog = 0.1, clear = 0.0, clouds = 0.9, cloudsOpacity = 0.1, fogTint = rgb(1, 1, 1) }
  v[T.OvercastClouds] =  { fog = 0.1, clear = 0.0, clouds = 0.9, cloudsOpacity = 0.5, fogTint = rgb(1, 1, 1) }
  -- v[T.OvercastClouds] =  { fog = 0.1, clear = 0.0, clouds = 0, fogTint = rgb(1, 1, 1) }
  v[T.Windy] =           { fog = 0.0, clear = 0.8, clouds = 0.4, lightTint = rgb(0.6, 0.8, 1), fogTint = rgb(1, 1, 1) }
  v[T.Fog] =             { fog = 1.0, clear = 0.0, clouds = 0.0, fogTint = rgb(0.8, 0.9, 1) }
  -- v[T.Fog] =             { fog = 1.0, clear = 0.0, clouds = 0.0, fogTint = rgb(1.4, 1.4, 1.4) }
  v[T.Mist] =            { fog = 0.3, clear = 0.6, clouds = 0.2, fogTint = rgb(0.8, 0.9, 1) }
  v[T.Haze] =            { fog = 0.2, clear = 0.5, clouds = 0.2, lightTint = rgb(1, 0.9, 0.8), fogTint = rgb(1, 0.6, 0.4) }
  v[T.Dust] =            { fog = 0.3, clear = 0.9, clouds = 0.4, lightTint = rgb(0.8, 0.8, 1), fogTint = rgb(1, 0.8, 0.8) }
  v[T.Smoke] =           { fog = 0.5, clear = 0.9, clouds = 0.6, lightTint = rgb(0.8, 0.8, 1), fogTint = rgb(1, 0.8, 0.8), saturation = 0.5 }
  v[T.Sand] =            { fog = 0.8, clear = 0.4, clouds = 0.2, lightTint = rgb(1, 0.6, 0.4), fogTint = rgb(1, 0.6, 0.4) }
  v[T.LightDrizzle] =    { fog = 0.1, clear = 0.3, clouds = 0.6, fogTint = rgb(0.9, 0.95, 1), wet = 0.2 }
  v[T.Drizzle] =         { fog = 0.3, clear = 0.16, clouds = 0.8, fogTint = rgb(0.9, 0.95, 1), wet = 0.3 }
  v[T.HeavyDrizzle] =    { fog = 0.5, clear = 0.02, clouds = 1.0, fogTint = rgb(0.9, 0.95, 1), wet = 0.4 }
  v[T.LightRain] =       { fog = 0.2, clear = 0.0, clouds = 0.6, fogTint = rgb(0.9, 0.9, 0.9), wet = 0.6 }
  v[T.Rain] =            { fog = 0.4, clear = 0.0, clouds = 0.8, fogTint = rgb(0.7, 0.7, 0.7), wet = 0.8 }
  v[T.HeavyRain] =       { fog = 0.9, clear = 0.0, clouds = 1.0, lightTint = rgb(0.5, 0.5, 0.5), fogTint = rgb(0.7, 0.8, 0.9) / 0.8, wet = 1.0 }
  v[T.LightThunderstorm] = { fog = 0.6, clear = 0.0, clouds = 1.0, lightTint = rgb(0.3, 0.3, 0.3), fogTint = rgb(0.5, 0.5, 0.6), wet = 0.8 }
  v[T.Thunderstorm] =    { fog = 0.8, clear = 0.0, clouds = 1.0, lightTint = rgb(0.1, 0.1, 0.1), fogTint = rgb(0.4, 0.4, 0.5), wet = 0.9 }
  v[T.HeavyThunderstorm] = { fog = 1.0, clear = 0.0, clouds = 1.0, lightTint = rgb(0, 0, 0), fogTint = rgb(0.2, 0.2, 0.3), wet = 1.0 }
  v[T.Squalls] =         { fog = 0.1, clear = 1.0, clouds = 1.0, saturation = 1.2 }
  v[T.Tornado] =         { fog = 0.5, clear = 0.25, clouds = 1, fogTint = rgb(0.2, 0.2, 0.3) }
  v[T.Hurricane] =       { fog = 0.8, clear = 0.0, clouds = 1, lightTint = rgb(), fogTint = rgb(0.2, 0.2, 0.3), wet = 1.0 }
  v[T.LightSnow] =       { fog = 0.0, clear = 0.7, clouds = 0.4, lightTint = rgb(0.6, 0.8, 1), fogTint = rgb(0.6, 0.8, 1), saturation = 0.25 }
  v[T.Snow] =            { fog = 0.3, clear = 0.2, clouds = 0.8, lightTint = rgb(0.6, 0.8, 1), fogTint = rgb(0.6, 0.8, 1), saturation = 0.25 }
  v[T.HeavySnow] =       { fog = 0.5, clear = 0.1, clouds = 1.0, lightTint = rgb(0.6, 0.8, 1), fogTint = rgb(0.6, 0.8, 1), saturation = 0.25 }
  v[T.LightSleet] =      { fog = 0.2, clear = 0.5, clouds = 0.4, lightTint = rgb(0.6, 0.8, 1), fogTint = rgb(0.6, 0.8, 1), saturation = 0.75 }
  v[T.Sleet] =           { fog = 0.5, clear = 0.16, clouds = 0.8, lightTint = rgb(0.6, 0.8, 1), fogTint = rgb(0.6, 0.8, 1), saturation = 0.75 }
  v[T.HeavySleet] =      { fog = 0.7, clear = 0.02, clouds = 1.0, lightTint = rgb(0.6, 0.8, 1), fogTint = rgb(0.6, 0.8, 1), saturation = 0.75 }
  v[T.Hail] =            { fog = 0.5, clear = 0.0, clouds = 1, lightTint = rgb.new(0.5), fogTint = rgb(0.2, 0.2, 0.3) }

  for k, v in pairs(v) do
    v.fog = v.fog or 0
    v.clear = v.clear or 1
    v.clouds = v.clouds or 0
    v.cloudsOpacity = v.cloudsOpacity or 1
    v.lightTint = v.lightTint or rgb(1, 1, 1)
    v.fogTint = v.fogTint or rgb(1, 1, 1)
    v.saturation = v.saturation or 1
    v.wet = v.wet or 0
  end
end

-- Creates and fills table with weather definitions
local values = {}
ac.WeatherType.NoClouds = 100  -- new type of weather added by Sol and used by Sol controller
fillValues(values, ac.WeatherType)

-- Stuff for smooth transition
local lastTransition = 0
local counter = 0
local target = { cold = 0 }

local function applyTarget(lagMult, key)
  local ov = CurrentConditions[key]
  CurrentConditions[key] = ov + (target[key] - ov) * lagMult
end

local function lerpConditions(conditions, lagMult, key)
  local vc = values[conditions.currentType]
  local vu = values[conditions.upcomingType]
  if not vc then ac.debug('Unknown type', conditions.currentType) end
  if not vu then ac.debug('Unknown type', conditions.upcomingType) end
  local ov = CurrentConditions[key]
  CurrentConditions[key] = ov + (math.lerp(vc[key], vu[key], conditions.transition) - ov) * lagMult
end

-- Uglier code, but happier garbage collector
local function applyLagRGB(v, r, g, b, lagMult, dt) 
  v.r = v.r + (r - v.r) * lagMult
  v.g = v.g + (g - v.g) * lagMult
  v.b = v.b + (b - v.b) * lagMult
end

local function lerpConditionsRGB(conditions, lagMult, key)
  local vc = values[conditions.currentType]
  local vu = values[conditions.upcomingType]
  if not vc then ac.debug('Unknown type', conditions.currentType) end
  if not vu then ac.debug('Unknown type', conditions.upcomingType) end
  
  local a = vc[key]
  local b = vu[key]
  local lr = math.lerp(a and a.r, b and b.r, conditions.transition)
  local lg = math.lerp(a and a.g, b and b.g, conditions.transition)
  local lb = math.lerp(a and a.b, b and b.b, conditions.transition)
  applyLagRGB(CurrentConditions[key], lr, lg, lb, lagMult, dt)
end

-- Read conditions and keep them here
local conditionsMem = ac.getConditionsSet()

-- WIP, wetness
local wetness = 0

function readConditions(dt)
  -- Update existing conditions instead of re-reading them to make garbage collector’s life easier
  local conditions = conditionsMem
  ac.getConditionsSetTo(conditions)
  updateWind(conditions, dt)  

  local lagMult = math.lagMult((not SmoothTransition or counter < 10) and 0 or 0.99, dt)
  lerpConditions(conditions, lagMult, 'fog')
  lerpConditions(conditions, lagMult, 'clear')
  lerpConditions(conditions, lagMult, 'clouds')
  lerpConditions(conditions, lagMult, 'cloudsOpacity')
  lerpConditionsRGB(conditions, lagMult, 'lightTint')
  lerpConditionsRGB(conditions, lagMult, 'fogTint')
  lerpConditions(conditions, lagMult, 'saturation')
  lerpConditions(conditions, lagMult, 'wet')

  if lastTransition ~= conditions.upcomingType then
    target.cold = math.random()
    lastTransition = conditions.upcomingType
  end

  applyTarget(lagMult, 'cold')
  ac.setTrackCondition('wfx_WET', CurrentConditions.wet)
  ac.setRainAmount(CurrentConditions.wet)
  wetness = math.applyLag(wetness, CurrentConditions.wet > 0.1 and 1 or 0, 0.997, dt)  -- TODO: link to 
  -- ac.setRainWetness(wetness)
  -- ac.setRainWetness(0.35)
  -- ac.setRainWetness(1)
  -- ac.setRainWetness(0)
  -- ac.debug('rain', CurrentConditions.wet)
  -- ac.debug('wetness', wetness)

  counter = counter + 1
end