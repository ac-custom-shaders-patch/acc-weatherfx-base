--[[
  An intermediate step turning image from linear to SRGB for YEBIS post-processing to apply correctly,
]]

local buffersCache = {}
local function createPPData(resolution)
  return {
    canvas = ui.ExtraCanvas(resolution, 1, render.TextureFormat.R16G16B16A16.Float),
    params = {
      blendMode = render.BlendMode.Opaque,
      depthMode = render.DepthMode.Off,
      textures = {
        ['txHDR'] = 'dynamic::pp::hdr'
      },
      values = {
        gBrightness = 1
      },
      directValuesExchange = true,
      cacheKey = 0,
      shader = 'shaders/pp_gamma.fx'
    }
  }
end
ac.onPostProcessing(function (params, exposure, mainPass, updateExposure, rtSize)
  if not UseGammaFix then -- TODO: Remove check when UseGammaFix will become a static thing, move it to weather.lua before including this file
    return nil
  end
  local data = table.getOrCreate(buffersCache, (mainPass and 0 or 1e7) + rtSize.y * 10000 + rtSize.x, createPPData, rtSize)
  data.params.values.gBrightness = 0.45 / GammaFixBrightnessOffset
  data.canvas:updateWithShader(data.params)
  return data.canvas
end)
table.insert(OnResolutionChange, function ()
  table.clear(buffersCache)
end)
