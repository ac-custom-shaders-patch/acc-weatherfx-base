--[[
  Rain haze effect. Kind of like volumetric fog, creates some uneven shapes moving with wind
  and rain. Should look like this: https://gfycat.com/handylastinghumpbackwhale

  If you want to integrate it to your WeatherFX script, feel free to copy this implementation
  with all of its details. You would only need to change intensity calculation in `UpdateRainHaze()`.

  Few key points of how it works:
  • It runs a fullscreen pass, taking nine points between camera position and distant surface
    position. For each point it samples a 3D noise map (just a very basic small 3D texture;
    some perlin noise might produce better effect, but would be more expensive and if not
    big enough, would create visible tiling).
  • Nine points per pixel are not enough for a smooth effect, but it can be compensated with
    a random offset for each pixel. However, this creates noise.
  • Because of that, and for performance reasons, actual effect is done in two steps. First,
    actual fog is collected in an offscreen texture with lower resolution. After that, a proper
    fullscreen pass applies that texture to main render target with some blurring to reduce
    noise.

  Note: this technique works here because it’s tied together with regular fog, acting like a slight
  offset for it. However, using the same method to create proper fog might not work that well because
  of complications with various transparent objects.
]]

local intensity = 0
local windOffset = vec3()
local windVelocity = vec3()
local texData = {}

local function createPassData()
  local size = render.getRenderTargetSize()
  return {
    txBaseNoise = ui.ExtraCanvas(size * 0.4, 1, render.TextureFormat.R8.UNorm):setName('Rain haze: base'), -- 40% of main screen resolution
    gBlurRadius = vec2(8 / size.x, 8 / size.y),
  }
end

local function renderHaze(passID, frameIndex, uniqueKey)
  local tex = table.getOrCreate(texData, uniqueKey, createPassData)

  render.backupRenderTarget()
  tex.txBaseNoise:updateSceneWithShader({
    textures = {
      txNoise3D = 'clouds/noise3D.dds'
    },
    values = {
      gRainOffset = windOffset,
      gIntensity = intensity,
      gDistanceInv = 1 / math.lerp(120, 60, math.min(intensity, 1))
    },
    shader = 'shaders/rainhaze_base.fx'
  })
  render.restoreRenderTarget()

  render.fullscreenPass({
    blendMode = render.BlendMode.AlphaBlend,
    depthMode = render.DepthMode.ReadOnly,
    depth = 10,  -- fullscreen pass applies to areas further than 10 meters from camera, to improve performance
    textures = {
      ['txBase.1'] = tex.txBaseNoise
    },
    values = {
      gBlurRadius = tex.gBlurRadius,
    },
    shader = 'shaders/rainhaze_apply.fx'
  })
end

local subscribed ---@type fun()?

function UpdateRainHaze(dt)
  local cc = CurrentConditions
  intensity = (cc.rain ^ 0.5) * (cc.fog + cc.thunder)
  if intensity < 0.2 then
    if subscribed then
      subscribed()
      subscribed = nil
    end
    return
  end

  if not subscribed then
    subscribed = RenderTrackSubscribe(render.PassID.Main, renderHaze)
  end

  ac.getWindVelocityTo(windVelocity)
  windOffset:addScaled(windVelocity, -dt)
  windOffset.y = windOffset.y + 15 * dt  -- 15 m/s for base rain speed
  intensity = intensity * math.lerpInvSat(intensity, 0.2, 0.25)
end
