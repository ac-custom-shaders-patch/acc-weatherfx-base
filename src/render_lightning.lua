--[[
  Simple bolt-like visual effect. Call once with given direction and this thing will draw a quad there
  for 100 ms (very quickly fading in intensity).

  Actual pattern is computed in main render pass, but for a nice glow this module also precomputes shape
  in a low-res buffer and applies gaussian blur to it.
]]

if not ScriptSettings.EXTRA_EFFECTS.FOG_ABOVE then
  AddVisualLightning = function (dir) end
  return
end

local lightningPool

---@param dir vec3
function AddVisualLightning(dir)
  local r = math.random()
  if not lightningPool then
    lightningPool = {
      main = ui.ExtraCanvas(256),
      blurred = {}
    }
  end
  lightningPool.main:updateWithShader({
    textures = { txNoise = 'dynamic::noise', txNoiseLR = 'rain_fx/puddles.dds' },
    values = { gSeed = r, gTimer = 0 },
    defines = { LOWRES = 1 },
    cacheKey = 1,
    shader = 'shaders/lightning.fx'
  })
  local size = 150 + 150 * math.random()
  local pos = Sim.cameraPosition + (dir * vec3(1, 0, 1)):normalize() * 500
  pos.y = Sim.cameraPosition.y + size / 2
  local blurred = table.remove(lightningPool.blurred) or ui.ExtraCanvas(128)
  blurred:gaussianBlurFrom(lightningPool.main, 63)
  local timer = 0
  local subscribed
  subscribed = RenderTrackSubscribe(bit.bor(render.PassID.Main, render.PassID.Mirror), function (passID, frameIndex, uniqueKey)
    render.setBlendMode(render.BlendMode.AlphaBlend)
    render.setDepthMode(render.DepthMode.ReadOnly)
    render.setCullMode(render.CullMode.None)

    render.shaderedQuad({
      pos = pos,
      width = size,
      height = size,
      up = vec3(0, -1, 0),
      textures = { txGlow = blurred, txNoiseLR = 'rain_fx/puddles.dds' }, 
      values = { gSeed = r, gTimer = timer }, 
      cacheKey = 2,
      shader = 'shaders/lightning.fx'
    })

    timer = timer + ac.getGameDeltaT() * 10
    if timer > 1 then
      setTimeout(function ()
        table.insert(lightningPool.blurred, blurred)
        subscribed()
      end)
    end
  end)
end