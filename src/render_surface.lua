
local function renderBillboard(passID, frameIndex, uniqueKey)
  render.setBlendMode(render.BlendMode.AlphaTest)
  render.setDepthMode(render.DepthMode.Normal)
  render.shaderedQuad({
    p1 = vec3(0, 80, 0),
    p2 = vec3(0, 80, 2e4),
    p3 = vec3(2e4, 80, 2e4),
    p4 = vec3(2e4, 80, 0),
    textures = {
    },
    values = {
    },
    shader = 'shaders/surface.fx'
  })
end

RenderTrackSubscribe(render.PassID.Main, renderBillboard)
