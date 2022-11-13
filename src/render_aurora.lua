--[[
  Aurora effect. Activates for tracks with nothern coordinates, taking into account some major
  known solar flares (last one occuring on February of 2022). Chance is calculated per-day in
  a fixed manner, meaning same track would get the effect on the same day on different AC runs.
  Should look like this: https://files.acstuff.ru/shared/jg7d/20220416-195754-karelia-bmw_m3_e30.jpg

  If you want to integrate it to your WeatherFX script, feel free to copy this implementation
  with all of its details. You would only need to change `computeAuroraIntensity()`: now it relies
  on some global variables set by default script, such as sun and moon direction.

  Few key points of how it works:
  • First, it draws a bunch of squiggly lines on the sky plane, above 10 km from surface. Then,
    to get the shape, it blurs those lines vertically.
  • Squiggly lines are drawn into a texture A, blurred version is drawn into a texture B1, and
    after that resulting blurred version is drawn onto the main render target texture.
  • For blurred version, two textures are made, B1 and B2. This allows to mix together current
    and previous frame taking into account camera motion (see `temporalSmoothing()` in shaders),
    greatly increasing quality for a very low cost. Otherwise, to achieve compatible quality
    shaders would require to use more steps for blurring, which would be more expensive. For that,
    B1 and B2 get swapped around each frame. Blur things into B1 and use B2 as a previous texture.
  • Also, original squiggly lines texture (A) are drawn with extra padding covering more than
    visible on the screen. This is necessary for lines outside of the frame to be able to blur
    into main image.
  • Whole thing is repeated second time with vertical offset and much smaller resolution for
    so called “high shape”: this is a cheap way to get reddish shape above green shape.
  • With all that, you can see that it requires a few extra textures for the whole effect to work.
    That’s why there is a `texData` table and `createPassData()` function. Each cubemap face,
    each rear view mirror, each side in triple screen mode or eye in VR mode, all give their
    own `uniqueKey`. For each of those keys new set of textures is prepared.
]]

local texData = {}
local auroraIntensity = 0
local auroraAmbientColor = rgb(0.3, 1, 0)
local auroraTime = -math.random() * 1e6
local temporalSmoothing = 0.05

local function createPassData(uniqueKey)
  local size = render.getRenderTargetSize()
  local mainFrame = uniqueKey == 100
  return {
    txBaseNoise = ui.ExtraCanvas(size * 0.7, 1, render.TextureFormat.R8.UNorm):setName(mainFrame and 'Aurora: base shape'),
    txBaseBlurred = {
      ui.ExtraCanvas(size * 0.5, 1, render.TextureFormat.R8.UNorm):setName(mainFrame and 'Aurora: blurred base shape (1)'),
      ui.ExtraCanvas(size * 0.5, 1, render.TextureFormat.R8.UNorm):setName(mainFrame and 'Aurora: blurred base shape (2)')
    },

    txHighNoise = ui.ExtraCanvas(size / 8, 1, render.TextureFormat.R8.UNorm):setName(mainFrame and 'Aurora: high shape'),
    txHighBlurred = {
      ui.ExtraCanvas(size / 8, 1, render.TextureFormat.R8.UNorm):setName(mainFrame and 'Aurora: blurred high shape (1)'),
      ui.ExtraCanvas(size / 8, 1, render.TextureFormat.R8.UNorm):setName(mainFrame and 'Aurora: blurred high shape (2)')
    },

    gNoiseScale = vec2(0.02, 0.02 * size.y / size.x),
  }
end

---@param passID render.PassID
local function renderAurora(passID, frameIndex, uniqueKey)
  if passID == render.PassID.CubeMap and frameIndex == 3 then return end

  local tex = table.getOrCreate(texData, uniqueKey, createPassData, uniqueKey)
  local time = auroraTime
  local uvPadding = 1.6

  render.backupRenderTarget()

  tex.txBaseNoise:updateSceneWithShader({
    textures = {
      txNoiseLr = 'rain_fx/puddles.dds',
    },
    values = {
      gTime = time,
      gUVPadding = uvPadding,
      gTemporalSmoothing = temporalSmoothing
    },
    shader = 'shaders/aurora_shape.fx'
  })

  tex.txBaseBlurred[1], tex.txBaseBlurred[2] = tex.txBaseBlurred[2], tex.txBaseBlurred[1]
  tex.txBaseBlurred[1]:updateSceneWithShader({
    textures = {
      ['txPrepared.1'] = tex.txBaseNoise,
      ['txPrevious.1'] = tex.txBaseBlurred[2],
      txNoiseLr = 'rain_fx/puddles.dds',
    },
    values = {
      gTime = time,
      gShuffle = vec2(math.random() * 32, math.random() * 32),
      gUVPadding = uvPadding,
      gTemporalSmoothing = temporalSmoothing
    },
    shader = 'shaders/aurora_blur.fx'
  })

  tex.txHighNoise:updateSceneWithShader({
    textures = {
      txNoiseLr = 'rain_fx/puddles.dds',
    },
    values = {
      gTime = time,
      gUVPadding = uvPadding,
      gTemporalSmoothing = temporalSmoothing
    },
    shader = 'shaders/aurora_shape_high.fx'
  })

  tex.txHighBlurred[1], tex.txHighBlurred[2] = tex.txHighBlurred[2], tex.txHighBlurred[1]
  tex.txHighBlurred[1]:updateSceneWithShader({
    textures = {
      ['txPrepared.1'] = tex.txHighNoise,
      ['txPrevious.1'] = tex.txHighBlurred[2],
      txNoiseLr = 'rain_fx/puddles.dds',
    },
    values = {
      gTime = time,
      gShuffle = vec2(math.random() * 32, math.random() * 32),
      gUVPadding = uvPadding,
      gNoiseScale = tex.gNoiseScale,
      gTemporalSmoothing = temporalSmoothing
    },
    shader = 'shaders/aurora_blur_high.fx'
  })

  render.restoreRenderTarget()

  render.fullscreenPass({
    blendMode = render.BlendMode.BlendAdd,
    textures = {
      ['txMain.1'] = tex.txBaseBlurred[1],
      ['txHigh.1'] = tex.txHighBlurred[1],
    },
    values = {
      gBrightnessMult = auroraIntensity * (passID == render.PassID.CubeMap and 1.6 or 1)
    },
    shader = 'shaders/aurora_apply.fx'
  })
end

local auroraGlow ---@type ac.SkyExtraGradient
local subscribed ---@type fun()?

local function setAuroraActive(active)
  if active ~= (subscribed ~= nil) then
    if subscribed == nil then
      if not auroraGlow then
        auroraGlow = ac.SkyExtraGradient()
        auroraGlow.direction = vec3(0, 1, 0)
        auroraGlow.sizeFull = 0.5
        auroraGlow.sizeStart = 1
        auroraGlow.exponent = 0.3
      end
      subscribed = RenderSkySubscribe(render.PassID.All, renderAurora)
      ac.skyExtraGradients:push(auroraGlow)
    else
      ac.skyExtraGradients:erase(auroraGlow)
      subscribed()
      subscribed = nil
    end
  end
end

local solarStorms = stringify.tryParse(ac.storage.solarStorms, nil, { '0501', '1709', '2202' })
local currentTime = os.time()

-- Updating list of auroras every three days
if not ac.storage.solarStormsTime or currentTime > tonumber(ac.storage.solarStormsTime) + 3 * 24 * 60 * 60 then
  web.get('https://acstuff.ru/j/auroras.txt', function (err, response)
    if err then return end
    local newList = table.filter(response.body:split('\n'), function (s) return #s == 4 end)
    if #newList > 4 then
      solarStorms = newList
      ac.storage.solarStorms = stringify(newList)
      ac.storage.solarStormsTime = currentTime
    end
  end)
end

local sim = ac.getSim()
local lattitude = math.abs(ac.getTrackCoordinatesDeg().x)

local function computeAuroraChance()
  local solarStorm = table.contains(solarStorms, os.dateGlobal('%y%m', sim.timestamp))
  local solarStormMult = solarStorm and 1 - math.abs(tonumber(os.dateGlobal('%d', sim.timestamp)) / 15 - 1) or 1
  local bandHalfWidth = solarStorm and 20/2 or 5/2
  local bandFullHalfWidth = bandHalfWidth / 2
  local bandCenter = 70

  return math.lerpInvSat(lattitude, bandCenter - bandHalfWidth, bandCenter - bandFullHalfWidth)
    * math.lerpInvSat(lattitude, bandCenter + bandHalfWidth, bandCenter + bandFullHalfWidth)
    * (solarStorm and solarStormMult or 0.05)
end

local function computeAuroraIntensity(chance)
  local diceBase = bit.bxor(328383, math.floor(sim.dayOfYear + sim.timeTotalSeconds / (24 * 60 * 60) + 0.5) + math.floor(lattitude * 1e4))
  local dice = math.seededRandom(diceBase)
  if chance < dice * 0.2 then return 0 end

  local ret = chance < 0.1 and (dice * 1e3 % 1) or math.min((chance - dice * 0.2) * 4, 1)
  ret = ret * math.saturateN(-SunDir.y * 10 - 0.5)          -- fade when sun is above horizon
  ret = ret * math.lerp(1, 0.6, math.saturateN(MoonDir.y))  -- lower intensity if moon is high
  ret = ret * math.max(0, 1 - LightPollutionValue * 4)      -- lower intensity if light pollution is present
  ret = ret * math.max(0, 1 - CurrentConditions.clouds * 2) -- lower intensity if there are a lot of clouds (doesn’t look too good otherwise)
  ret = ret * CurrentConditions.clear                       -- lower intensity if weather is not clear
  return ret
end

local prevHour, chance

function UpdateAurora(dt)
  local curHour = math.floor(sim.timestamp / (60 * 60))
  if curHour ~= prevHour then
    chance = computeAuroraChance()
    prevHour = curHour
  end

  if chance == 0 then
    if subscribed then setAuroraActive(false) end
    return
  end

  auroraTime = auroraTime + dt
  temporalSmoothing = dt < 0.05 and 0.05 or 0.5
  auroraIntensity = computeAuroraIntensity(chance)
  setAuroraActive(auroraIntensity > 0)

  if subscribed and auroraGlow then
    local noise = math.sin(auroraTime * 0.1) * 0.45 + math.sin(auroraTime * 0.713) * 0.3 + math.sin(auroraTime * 1.303) * 0.25
    auroraGlow.color:set(auroraAmbientColor):scale(0.15 * (1 + 0.3 * noise) * auroraIntensity)
  end
end
