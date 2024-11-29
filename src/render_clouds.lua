--[[
  Simplest effect, adds fog above covering tops of tall buildings in foggy weather. Should look like this:
  https://files.acstuff.ru/shared/IMs1/20220508-183448-shuto_revival_project_beta-ks_audi_a1s1.jpg

  If you want to integrate it to your WeatherFX script, feel free to copy this implementation
  with all of its details. You would only need to change intensity calculation in `UpdateAboveFog()`.

  Few key points of how it works:
  • It simply runs a semi-transparent fullscreen pass, finds out position of onscreen pixel using
    depth buffer, finds how high it is above camera and then uses it to calculate opacity.
  • Only active if there is any tall geometry and current fog amount is a lot.

  Note: this effect currently doesn’t work too well with SSLR: SSLR expects original objects to be there
  to subtract base reflections and add SSLR ones, but instead it just does that to a fog. Rain haze
  is not affected by it because it never really goes full opacity, instead it’s a much more subtle effect.
  Not entirely sure what the fix for SSLR might be at the moment, but anyway the issue is not that
  pronounced for most objects.
]]

if not ScriptSettings.EXTRA_EFFECTS.UPPER_CLOUDS then
  UpdateCloudLayers = function (dt) end
  return
end

local intensity = 0
local windOffset = vec2()
local windMTg = 0

local renderFogParams = {
  blendMode = render.BlendMode.AlphaBlend,
  depthMode = render.DepthMode.ReadOnly,
  depth = 1e4,
  shader = 'shaders/clouds.fx',
  textures = {
    txNoiseLr = 'rain_fx/puddles.dds',
  },
  values = {
    gIntensity = intensity,
    gWindOffset = vec2(),
    gCloudsAmbientColor = rgb(),
    gCloudsSunColor = rgb(),
    gCloudsSunDirection = vec3(),
    gMaskOffset = vec2(math.random() * 10, math.random() * 10),
    gWindShift00 = vec2(1, 0),
    gWindShift01 = vec2(0, 1),
    gWindShift10 = vec2(1, 0),
    gWindShift11 = vec2(0, 1),
    gWindShiftAlt00 = vec2(1, 0),
    gWindShiftAlt01 = vec2(0, 1),
    gWindShiftAlt10 = vec2(1, 0),
    gWindShiftAlt11 = vec2(0, 1),
    gMaskShift = vec3(-9, -9, -9),
    gMaskBoost = vec3(0, 0, 0),
    gThickness = vec3(0, 0, 0),
    gCloudsShadow = 0,
    gWindMix = 0,
  },
  defines = {
    MAIN_PASS = 1
  },
  async = true,
  cacheKey = 1
}

local function packWindTransform(v0, v1, alt)
  local u = CurrentConditions.windDir.x
  local v = CurrentConditions.windDir.y
  local skewFactor = (alt and -0.25 or -0.75) * math.clamp(CurrentConditions.windSpeed / (35 / 3.6), 0.3, 1)
  v0.x, v1.x = 1 + u * skewFactor * u, u * skewFactor * v
  v0.y, v1.y = v * skewFactor * u, 1 + v * skewFactor * v
end

local lastUpdateFrame = {-1, -1}

---@param passID render.PassID
local function renderCloudLayers(passID)
  local key = passID == render.PassID.Main and 2 or 1
  renderFogParams.defines.MAIN_PASS = key - 1
  renderFogParams.cacheKey = key

  if lastUpdateFrame[key] ~= Sim.frame then
    lastUpdateFrame[key] = Sim.frame

    local ccClouds, ccDensity = CurrentConditions.clouds, CurrentConditions.cloudsDensity
    windOffset:addScaled(CurrentConditions.windDir, CurrentConditions.windSpeed * CloudsDT * 2)
    renderFogParams.values.gIntensity = intensity
    renderFogParams.values.gWindOffset:set(windOffset)
    renderFogParams.values.gCloudsAmbientColor:set(CloudMaterials.Main.ambientColor)
    renderFogParams.values.gCloudsSunColor:set(CloudsLightColor):scale((1 - ccClouds * 0.8) * (1 - ccDensity))
    renderFogParams.values.gCloudsSunDirection:set(CloudsLightDirection)
    ac.fixHeadingSelf(renderFogParams.values.gCloudsSunDirection)
  
    renderFogParams.values.gThickness.x = 0.2 * (5 * ccClouds / (1 + 4 * ccClouds)) * (1 + 4 * ccDensity)
    renderFogParams.values.gMaskBoost.x = 2.5
    renderFogParams.values.gMaskShift.x = -renderFogParams.values.gMaskBoost.x * (1 - ccClouds * 0.15) ^ 8 + math.min(0, math.perlin(Sim.timestamp / 1.15e5) * 3 + 1.5)
    renderFogParams.values.gThickness.y = 2 * ccClouds / (1 + ccClouds)
    renderFogParams.values.gMaskBoost.y = 2.5
    renderFogParams.values.gMaskShift.y = -renderFogParams.values.gMaskBoost.y * (1 - ccClouds ^ 0.3 * 0.4) + math.min(0, math.perlin(Sim.timestamp / 1.16e5) * 4 + 0.5)
    renderFogParams.values.gThickness.z = 2 * ccClouds / (1 + ccClouds)
    renderFogParams.values.gMaskBoost.z = 1.5
    renderFogParams.values.gMaskShift.z = -renderFogParams.values.gMaskBoost.z * (1 - ccClouds ^ 0.3 * 0.3) + math.min(0, math.perlin(Sim.timestamp / 1.17e5) * 5 - 0.5)
    renderFogParams.values.gCloudsShadow = ccClouds
  
    if math.abs(renderFogParams.values.gWindMix - windMTg) > 0.001 then
      renderFogParams.values.gWindMix = math.saturateN(renderFogParams.values.gWindMix + math.sign(windMTg - renderFogParams.values.gWindMix) * Sim.dt * 0.1)
    else
      packWindTransform(
        windMTg == 0 and renderFogParams.values.gWindShift10 or renderFogParams.values.gWindShift00,
        windMTg == 0 and renderFogParams.values.gWindShift11 or renderFogParams.values.gWindShift01)
      packWindTransform(
        windMTg == 0 and renderFogParams.values.gWindShiftAlt10 or renderFogParams.values.gWindShiftAlt00,
        windMTg == 0 and renderFogParams.values.gWindShiftAlt11 or renderFogParams.values.gWindShiftAlt01, true)
      windMTg = 1 - windMTg
    end
  end

  render.fullscreenPass(renderFogParams)
end

local subscribed ---@type fun()?
local prevTimestamp = 0

function UpdateCloudLayers(dt)
  local needsCloudLayers = UseGammaFix and CurrentConditions.clouds > 0
  if math.abs(prevTimestamp - Sim.timestamp) > 600 then
    windOffset:set(math.random() * 1e4, math.random() * 1e4)
  end
  prevTimestamp = Sim.timestamp
  if needsCloudLayers then
    if not subscribed then
      subscribed = RenderSkySubscribe(render.PassID.All, renderCloudLayers, 0)
    end
  elseif subscribed then
    subscribed()
    subscribed = nil
  end
end
