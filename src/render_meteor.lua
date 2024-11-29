--[[
  Falling stars.
]]

if not ScriptSettings.EXTRA_EFFECTS.ECLIPSE then
  return
end

local function castFallingStar()
  local dir = vec3(math.random() * 2 - 1, 0.7, math.random() * 2 - 1)
  if #vec2(dir.x, dir.z) > 1 then return end
  dir:normalize():scale(1e4)
  local alignment = vec3(math.random() * 2 - 1, -1, math.random() * 2 - 1):normalize()
  local size, speed = 7e3 + 6e3 * math.random(), 1.5 + math.random()
  local stage = 0
  local tint = math.random()
  local color = rgb(10, 9 + tint * 2, 8 + tint * 4):scale(StarsBrightness * 50)
  local sub = RenderSkySubscribe(render.PassID.Main, function()
    render.setDepthMode(render.DepthMode.ReadOnly)
    render.setBlendMode(render.BlendMode.BlendAdd)
    render.shaderedQuad({
      pos = ac.getSim().cameraPosition + dir,
      up = alignment,
      width = 200,
      height = size,
      values = {
        gStage = stage,
        gColor = color * GammaFixBrightnessOffset
      },
      async = true,
      cacheKey = 1,
      shader = [[
        float4 main(PS_IN pin) {
          float i = pow(max(0, 1 - abs(pin.Tex.x * 2 - 1) / (fwidth(pin.Tex.x) * 2)), 4)
            + pow(max(0, 1 - abs(pin.Tex.x * 2 - 1)), 2) * 0.005;
          i *= pow(1 - gStage, 4);
          i *= gStage > pin.Tex.y ? max(0, 1 - (gStage - pin.Tex.y) * (2 + 10 * gStage)) : 0;
          i *= pow(max(0, min(1, gStage * 4 - 0.5) * min(1, (1 - gStage) * 4)), 2);
          return float4(gColor, i);
        }
      ]]
    })
  end, 3)
  setInterval(function ()
    stage = stage + Sim.dt * speed
    if stage > 1 then
      sub()
      return clearInterval
    end
  end)
end

setInterval(function ()
  if math.random() > 0.98 and NightK > 0 then
    castFallingStar()
  end
end, 2.7)
