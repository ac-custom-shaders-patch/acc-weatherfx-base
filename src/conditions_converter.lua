--------
-- Reads weather conditions and converts them into a bunch of very simple to interpret values for the rest of the script.
--------

-- Global table with converted weather values
local defaultWeatherDefinition = {
  fog = 0,              -- how foggy is it, from 0 to 1
  clear = 1,            -- how clear is the sky, turns to grey with 0
  clouds = 0,           -- how many shapy clouds are up there
  cloudsDensity = 0,    -- how dense are clouds
  tint = rgb(1, 1, 1),  -- color tint for light
  saturation = 1,       -- how saturated are the colors
  thunder = 0,
  pollution = 0
}

CurrentConditions = table.assign({
  windDir = vec2(0, 0),        -- smoothed wind direction (for clouds)
  windDirInstant = vec2(0, 0), -- normalized wind direction
  windSpeed = 0,               -- smoothed wind speed in m/s (for clouds)
  windSpeedInstant = 0,        -- wind speed in m/s
  rain = 0,
  wetness = 0,
  water = 0,
}, defaultWeatherDefinition, {tint = rgb(1, 1, 1)})

-- Creates and fills table with weather definitions
local weatherDefinitions = {}
ac.WeatherType.NoClouds = 100  -- new type of weather added by Sol and used by Sol controller

local function defineWeather(params)
  weatherDefinitions[params.type] = table.assign({}, defaultWeatherDefinition, params)
end

defineWeather{type = ac.WeatherType.NoClouds,          fog = 0,   clear = 1,    clouds = 0}
defineWeather{type = ac.WeatherType.Clear,             fog = 0,   clear = 1,    clouds = 0.01}
defineWeather{type = ac.WeatherType.FewClouds,         fog = 0,   clear = 1,    clouds = 0.25}
defineWeather{type = ac.WeatherType.ScatteredClouds,   fog = 0,   clear = 1,    clouds = 0.5}
defineWeather{type = ac.WeatherType.BrokenClouds,      fog = 0,   clear = 0.9,  clouds = 0.75}
defineWeather{type = ac.WeatherType.OvercastClouds,    fog = 0.1, clear = 0,    clouds = 1}
defineWeather{type = ac.WeatherType.Windy,             fog = 0,   clear = 0.8,  clouds = 0.6, saturation = 0.0}
defineWeather{type = ac.WeatherType.Cold,              fog = 0.3, clear = 0.9,  clouds = 0.4, saturation = 0.5, tint = rgb(0.8, 0.9, 1.0)}
defineWeather{type = ac.WeatherType.Hot,               fog = 0.1, clear = 1,    clouds = 0.1, saturation = 1.2, tint = rgb(1.0, 0.9, 0.8)}
defineWeather{type = ac.WeatherType.Fog,               fog = 1,   clear = 0.1,  clouds = 0}
defineWeather{type = ac.WeatherType.Mist,              fog = 0.4, clear = 0.6,  clouds = 0.2, tint = rgb(0.8, 0.9, 1.0)}
defineWeather{type = ac.WeatherType.Haze,              fog = 0.3, clear = 0.5,  clouds = 0.2, tint = rgb(1, 0.92, 0.9), saturation = 0.8, pollution = 0.25}
defineWeather{type = ac.WeatherType.Dust,              fog = 0.5, clear = 0.9,  clouds = 0.2, tint = rgb(1, 0.85, 0.8), saturation = 0.8, pollution = 0.5}
defineWeather{type = ac.WeatherType.Smoke,             fog = 0.7, clear = 0.9,  clouds = 0.8, tint = rgb(0.8, 0.7, 0.9):scale(0.4), saturation = 0.4, pollution = 0.75}
defineWeather{type = ac.WeatherType.Sand,              fog = 0.9, clear = 0.2,  clouds = 0.9, tint = rgb(1, 0.6, 0.4):scale(0.7), pollution = 1}
defineWeather{type = ac.WeatherType.LightDrizzle,      fog = 0.1, clear = 0.9,  clouds = 0.7, cloudsDensity = 0.2, saturation = 0.5}
defineWeather{type = ac.WeatherType.Drizzle,           fog = 0.3, clear = 0.7,  clouds = 0.8, cloudsDensity = 0.4, tint = rgb(0.9, 0.95, 1.0)}
defineWeather{type = ac.WeatherType.HeavyDrizzle,      fog = 0.5, clear = 0.5,  clouds = 0.9, cloudsDensity = 0.6, tint = rgb(0.8, 0.9, 1.0), thunder = 0.1}
defineWeather{type = ac.WeatherType.LightRain,         fog = 0.2, clear = 0.8,  clouds = 0.6, cloudsDensity = 0.3}
defineWeather{type = ac.WeatherType.Rain,              fog = 0.4, clear = 0.05, clouds = 0.9, cloudsDensity = 0.5}
defineWeather{type = ac.WeatherType.HeavyRain,         fog = 0.8, clear = 0,    clouds = 1,   cloudsDensity = 0.8, thunder = 0.2}
defineWeather{type = ac.WeatherType.LightThunderstorm, fog = 0.4, clear = 0.2,  clouds = 0.9, cloudsDensity = 0.8, thunder = 0.4}
defineWeather{type = ac.WeatherType.Thunderstorm,      fog = 0.8, clear = 0,    clouds = 1,   cloudsDensity = 0.9, tint = rgb.new(0.6), thunder = 0.6}
defineWeather{type = ac.WeatherType.HeavyThunderstorm, fog = 0.9, clear = 0,    clouds = 1,   cloudsDensity = 1.0, tint = rgb.new(0.4), thunder = 0.8}
defineWeather{type = ac.WeatherType.LightSnow,         fog = 0.2, clear = 0.8,  clouds = 0.4, cloudsDensity = 0.3, tint = rgb(0.8, 0.9, 1.0)}
defineWeather{type = ac.WeatherType.Snow,              fog = 0.4, clear = 0.05, clouds = 0.6, cloudsDensity = 0.5, tint = rgb(0.6, 0.8, 1.0)}
defineWeather{type = ac.WeatherType.HeavySnow,         fog = 1,   clear = 0,    clouds = 0.8, cloudsDensity = 0.8, tint = rgb(0.4, 0.7, 1.0)}
defineWeather{type = ac.WeatherType.LightSleet,        fog = 0.1, clear = 0.9,  clouds = 0.7, cloudsDensity = 0.2, tint = rgb(0.6, 0.8, 1.0), saturation = 0.25}
defineWeather{type = ac.WeatherType.Sleet,             fog = 0.3, clear = 0.7,  clouds = 0.8, cloudsDensity = 0.4, tint = rgb(0.6, 0.8, 1.0), saturation = 0.12}
defineWeather{type = ac.WeatherType.HeavySleet,        fog = 0.5, clear = 0.5,  clouds = 0.9, cloudsDensity = 0.6, tint = rgb(0.6, 0.8, 1.0), saturation = 0.0}
defineWeather{type = ac.WeatherType.Squalls,           fog = 0.1, clear = 1,    clouds = 1,   saturation = 1.2}
defineWeather{type = ac.WeatherType.Tornado,           fog = 0.9, clear = 0.25, clouds = 1,   tint = rgb(0.24, 0.28, 0.3)}
defineWeather{type = ac.WeatherType.Hurricane,         fog = 0.8, clear = 0,    clouds = 1,   tint = rgb(0.28, 0.24, 0.3):adjustSaturation(0.5), thunder = 1}
defineWeather{type = ac.WeatherType.Hail,              fog = 0.5, clear = 0,    clouds = 1,   tint = rgb(0.3, 0.24, 0.28):adjustSaturation(0.5), thunder = 1}

-- Read conditions and keep them here
local state = ac.getConditionsSet()
local previousType = nil

function ReadConditions(dt)
  -- Update existing conditions instead of re-reading them to make garbage collector’s life easier
  local s = state
  ac.getConditionsSetTo(s)
  if s.currentType ~= previousType then
    previousType = s.currentType
    ForceRapidUpdates = 100
  end

  -- Update wind
  local cc = CurrentConditions
  local dir = s.wind.direction * math.pi / 180 + math.perlin(Sim.timestamp / 1.04e5, 3) * 2
  cc.windDirInstant:set(-math.sin(dir), math.cos(dir))
  cc.windSpeedInstant = (s.wind.speedFrom + s.wind.speedTo) / (2 * 3.6)

  -- Mixing definitions and applying them smoothly 
  local lagMult = math.lagMult((not SmoothTransition or os.preciseClock() < 1) and 0 or 0.95, dt)
  local vc = weatherDefinitions[s.currentType] or defaultWeatherDefinition
  local vu = weatherDefinitions[s.upcomingType] or defaultWeatherDefinition
  cc.fog = cc.fog + (math.lerp(vc.fog, vu.fog, s.transition) - cc.fog) * lagMult
  cc.clear = cc.clear + (math.lerp(vc.clear, vu.clear, s.transition) - cc.clear) * lagMult
  cc.clouds = cc.clouds + (math.lerp(vc.clouds, vu.clouds, s.transition) - cc.clouds) * lagMult
  cc.cloudsDensity = cc.cloudsDensity + (math.lerp(vc.cloudsDensity, vu.cloudsDensity, s.transition) - cc.cloudsDensity) * lagMult
  cc.saturation = cc.saturation + (math.lerp(vc.saturation, vu.saturation, s.transition) - cc.saturation) * lagMult
  cc.thunder = cc.thunder + (math.lerp(vc.thunder, vu.thunder, s.transition) - cc.thunder) * lagMult
  cc.pollution = cc.pollution + (math.lerp(vc.pollution, vu.pollution, s.transition) - cc.pollution) * lagMult
  cc.rain = cc.rain + (s.rainIntensity - cc.rain) * lagMult
  cc.wetness = cc.wetness + (s.rainWetness - cc.wetness) * lagMult
  cc.water = cc.water + (s.rainWater - cc.water) * lagMult
  cc.tint.r = cc.tint.r + (math.lerp(vc.tint.r, vu.tint.r, s.transition) - cc.tint.r) * lagMult
  cc.tint.g = cc.tint.g + (math.lerp(vc.tint.g, vu.tint.g, s.transition) - cc.tint.g) * lagMult
  cc.tint.b = cc.tint.b + (math.lerp(vc.tint.b, vu.tint.b, s.transition) - cc.tint.b) * lagMult

  if table.nkeys(Overrides) > 1 then
    CurrentConditions.fog = Overrides.fog or CurrentConditions.fog
    CurrentConditions.clouds = Overrides.clouds or CurrentConditions.clouds
    CurrentConditions.cloudsDensity = Overrides.cloudsDensity or CurrentConditions.cloudsDensity
    CurrentConditions.clear = Overrides.clear or CurrentConditions.clear
    CurrentConditions.saturation = Overrides.saturation or CurrentConditions.saturation
    CurrentConditions.tint = Overrides.tint and Overrides.tint:clone() or CurrentConditions.tint
    CurrentConditions.thunder = Overrides.thunder or CurrentConditions.thunder
    CurrentConditions.pollution = Overrides.pollution or CurrentConditions.pollution
    CurrentConditions.rain = Overrides.rain or CurrentConditions.rain
    CurrentConditions.wetness = Overrides.wetness or CurrentConditions.wetness
    CurrentConditions.water = Overrides.water or CurrentConditions.water
  end
end