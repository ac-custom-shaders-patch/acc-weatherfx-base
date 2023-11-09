--------
-- Reads weather conditions and converts them into a bunch of very simple to interpret values for the rest of the script.
--------

-- Global table with converted weather values
CurrentConditions = {
  fog = 0, -- how foggy is it, from 0 to 1
  clear = 1, -- how clear is the sky, turns to grey with 0
  clouds = 0, -- how many shapy clouds are up there
  cloudsDensity = 0, -- how dense are clouds
  tint = rgb(1, 1, 1), -- color tint for light
  saturation = 1, -- how saturated are the colors
  windDir = vec2(0, 1), -- normalized wind direction (for clouds)
  windSpeed = 5, -- wind speed in m/s (for clouds)
  rain = 0,
  wetness = 0,
  water = 0,
  thunder = 0
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
  v[T.NoClouds] =          { fog = 0.0, clear = 1.0, clouds = 0.0 }
  v[T.Clear] =             { fog = 0.0, clear = 1.0, clouds = 0.01 }
  v[T.FewClouds] =         { fog = 0.0, clear = 1.0, clouds = 0.3 }
  v[T.ScatteredClouds] =   { fog = 0.0, clear = 1.0, clouds = 0.5 }
  v[T.BrokenClouds] =      { fog = 0.0, clear = 0.9, clouds = 0.7 }
  v[T.OvercastClouds] =    { fog = 0.1, clear = 0.0, clouds = 1.0 }
  v[T.Windy] =             { fog = 0.0, clear = 0.8, clouds = 0.6, saturation = 0.0 }
  v[T.Cold] =              { fog = 0.3, clear = 0.9, clouds = 0.4, saturation = 0.5, tint = rgb(0.8, 0.9, 1.0) }
  v[T.Hot] =               { fog = 0.1, clear = 1.0, clouds = 0.1, saturation = 1.2, tint = rgb(1.0, 0.9, 0.8) }
  v[T.Fog] =               { fog = 1.0, clear = 0.1, clouds = 0.0 }
  v[T.Mist] =              { fog = 0.4, clear = 0.6, clouds = 0.2, tint = rgb(0.8, 0.9, 1.0) }
  v[T.Haze] =              { fog = 0.3, clear = 0.5, clouds = 0.2, tint = rgb(1, 0.92, 0.9), saturation = 0.8 }
  v[T.Dust] =              { fog = 0.5, clear = 0.9, clouds = 0.2, tint = rgb(1, 0.85, 0.8), saturation = 0.8 }
  v[T.Smoke] =             { fog = 0.7, clear = 0.9, clouds = 0.8, tint = rgb(0.8, 0.8, 1):scale(0.15), saturation = 0.4 }
  v[T.Sand] =              { fog = 0.9, clear = 0.2, clouds = 0.9, tint = rgb(1, 0.6, 0.4):scale(0.5) }

  v[T.LightDrizzle] =      { fog = 0.1, clear = 0.9, clouds = 0.7, cloudsDensity = 0.2, saturation = 0.5 }
  v[T.Drizzle] =           { fog = 0.3, clear = 0.7, clouds = 0.8, cloudsDensity = 0.4, tint = rgb(0.9, 0.95, 1.0) }
  v[T.HeavyDrizzle] =      { fog = 0.5, clear = 0.5, clouds = 0.9, cloudsDensity = 0.6, tint = rgb(0.8, 0.9, 1.0), thunder = 0.1 }
  v[T.LightRain] =         { fog = 0.2, clear = 0.8, clouds = 0.6, cloudsDensity = 0.3 }
  v[T.Rain] =              { fog = 0.4, clear = 0.05, clouds = 0.9, cloudsDensity = 0.5 }
  v[T.HeavyRain] =         { fog = 0.8, clear = 0.0, clouds = 1.0, cloudsDensity = 0.8, thunder = 0.2 }
  v[T.LightThunderstorm] = { fog = 0.4, clear = 0.2, clouds = 0.9, cloudsDensity = 0.8, thunder = 0.4 }
  v[T.Thunderstorm] =      { fog = 0.8, clear = 0.0, clouds = 1.0, cloudsDensity = 0.9, tint = rgb.new(0.5), thunder = 0.6 }
  v[T.HeavyThunderstorm] = { fog = 0.9, clear = 0.0, clouds = 1.0, cloudsDensity = 1.0, tint = rgb.new(0.2), thunder = 0.8 }
  v[T.LightSnow] =         { fog = 0.2, clear = 0.8, clouds = 0.4, cloudsDensity = 0.3, tint = rgb(0.8, 0.9, 1.0) }
  v[T.Snow] =              { fog = 0.4, clear = 0.05, clouds = 0.6, cloudsDensity = 0.5, tint = rgb(0.6, 0.8, 1.0) }
  v[T.HeavySnow] =         { fog = 1.0, clear = 0.0, clouds = 0.8, cloudsDensity = 0.8, tint = rgb(0.4, 0.7, 1.0) }
  v[T.LightSleet] =        { fog = 0.1, clear = 0.9, clouds = 0.7, cloudsDensity = 0.2, tint = rgb(0.6, 0.8, 1.0), saturation = 0.25 }
  v[T.Sleet] =             { fog = 0.3, clear = 0.7, clouds = 0.8, cloudsDensity = 0.4, tint = rgb(0.6, 0.8, 1.0), saturation = 0.12 }
  v[T.HeavySleet] =        { fog = 0.5, clear = 0.5, clouds = 0.9, cloudsDensity = 0.6, tint = rgb(0.6, 0.8, 1.0), saturation = 0.0 }

  v[T.Squalls] =           { fog = 0.1, clear = 1.0, clouds = 1.0, saturation = 1.2 }
  v[T.Tornado] =           { fog = 0.9, clear = 0.25, clouds = 1, tint = rgb(0.08, 0.14, 0.3) }
  v[T.Hurricane] =         { fog = 0.8, clear = 0.0, clouds = 1, tint = rgb(0.14, 0.08, 0.3):adjustSaturation(0.5), thunder = 1 }
  v[T.Hail] =              { fog = 0.5, clear = 0.0, clouds = 1, tint = rgb(0.3, 0.08, 0.14):adjustSaturation(0.5), thunder = 1 }

  for k, v in pairs(v) do
    v.fog = v.fog or 0
    v.clear = v.clear or 1
    v.clouds = v.clouds or 0
    v.cloudsDensity = v.cloudsDensity or 0
    v.tint = v.tint or rgb(1, 1, 1)
    v.fogTint = v.fogTint or rgb(1, 1, 1)
    v.saturation = v.saturation or 1
    v.thunder = v.thunder or 0
  end
end

-- Creates and fills table with weather definitions
local values = {}
ac.WeatherType.NoClouds = 100  -- new type of weather added by Sol and used by Sol controller
fillValues(values, ac.WeatherType)

-- Stuff for smooth transition
local counter = 0

local function lerpConditions(conditions, lagMult, key)
  local vc = values[conditions.currentType]
  local vu = values[conditions.upcomingType]
  if not vc then ac.debug('Unknown type', conditions.currentType) return end
  if not vu then ac.debug('Unknown type', conditions.upcomingType) return end
  local ov = CurrentConditions[key]
  CurrentConditions[key] = ov + (math.lerp(vc[key], vu[key], conditions.transition) - ov) * lagMult
end

-- Uglier code, but happier garbage collector
local function applyLagRGB(v, r, g, b, lagMult, dt) 
  v.r = v.r + (r - v.r) * lagMult
  v.g = v.g + (g - v.g) * lagMult
  v.b = v.b + (b - v.b) * lagMult
end

local function lerpConditionsRGB(conditions, lagMult, key, dt)
  local vc = values[conditions.currentType]
  local vu = values[conditions.upcomingType]
  if not vc then ac.debug('Unknown type', conditions.currentType) return end
  if not vu then ac.debug('Unknown type', conditions.upcomingType) return end
  
  local a = vc[key] 
  local b = vu[key]
  local lr = math.lerp(a and a.r, b and b.r, conditions.transition)
  local lg = math.lerp(a and a.g, b and b.g, conditions.transition)
  local lb = math.lerp(a and a.b, b and b.b, conditions.transition)
  applyLagRGB(CurrentConditions[key], lr, lg, lb, lagMult, dt)
end

-- Read conditions and keep them here
local conditionsMem = ac.getConditionsSet()

function ReadConditions(dt)
  -- Update existing conditions instead of re-reading them to make garbage collector’s life easier
  local conditions = conditionsMem
  ac.getConditionsSetTo(conditions)
  updateWind(conditions, dt)

  local lagMult = math.lagMult((not SmoothTransition or counter < 10) and 0 or 0.95, dt)
  lerpConditions(conditions, lagMult, 'fog')
  lerpConditions(conditions, lagMult, 'clear')
  lerpConditions(conditions, lagMult, 'clouds')
  lerpConditions(conditions, lagMult, 'cloudsDensity')
  lerpConditionsRGB(conditions, lagMult, 'tint', dt)
  lerpConditions(conditions, lagMult, 'saturation')
  lerpConditions(conditions, lagMult, 'thunder')

  CurrentConditions.rain = conditions.rainIntensity
  CurrentConditions.wetness = conditions.rainWetness
  CurrentConditions.water = conditions.rainWater
  counter = counter + 1
end