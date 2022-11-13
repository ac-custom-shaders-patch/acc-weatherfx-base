--[[
  An experiment I did some time to see if I can render somewhat decent trees, before doing anything
  in C++ code. Not needed for weather itself, but might still be useful as an example of drawing
  custom things.
]]

local time = 0

local basePoints = math.poissonSamplerCircle(100)

-- math.randomseed(0)
-- basePoints = table.range(100, function (index, callbackData)
--   return vec2(math.random(), math.random()):scale(2):add(-1)
-- end)

local trees = table.map(basePoints, function (point)
  local size = math.lerp(8, 12, math.random())
  return {
    pos = vec3(point.x * 100, -1 + size * 1.5, point.y * 100),
    size = size,
    offset = math.random(),
    bias = vec3(math.random(), math.random(), math.random())
  }
end)

local treeDrawCall = {
  p1 = vec3(),
  p2 = vec3(),
  p3 = vec3(),
  p4 = vec3(),
  textures = {
    txColor = 'H:/2/color.dds',
    txNormal = 'H:/2/normal.dds',
    txSubsurface = 'H:/2/subsurface.dds',
    txOcclusion = 'H:/2/occlusion.dds'
  },
  values = {
    gTime = time,
    gDir = vec3(),
    gSide = vec3(),
    gUp = vec3(),
    gOffset = 0,
    gBias = vec3()
  },
  shader = 'shaders/test.fx'
}

local cameraPos = ac.getSim().cameraPosition
local baseUp = vec3(0, 1, 0)

local function drawTree(tree)
  local pos = tree.pos
  local dir = treeDrawCall.values.gDir:set(pos):sub(cameraPos)
  if dir.y > 0 then dir.y = 0 end
  dir:normalize()
  local side = treeDrawCall.values.gSide:setCrossNormalized(dir, baseUp)
  local up = treeDrawCall.values.gUp:setCrossNormalized(side, dir)
  local height = math.lerp(1.5, 1, math.abs(dir.y)) * tree.size
  treeDrawCall.p1:set(pos):addScaled(up, height):addScaled(side, tree.size)
  treeDrawCall.p2:set(pos):addScaled(up, height):addScaled(side, -tree.size)
  treeDrawCall.p3:set(pos):addScaled(up, -height):addScaled(side, -tree.size)
  treeDrawCall.p4:set(pos):addScaled(up, -height):addScaled(side, tree.size)
  treeDrawCall.values.gOffset = tree.offset
  treeDrawCall.values.gBias = tree.bias  
  render.shaderedQuad(treeDrawCall)

  -- tree.offset = tree.offset + 0.03
end

local function renderBillboard(passID, frameIndex, uniqueKey)
  treeDrawCall.values.gTime = time
  render.setBlendMode(render.BlendMode.AlphaTest)
  render.setDepthMode(render.DepthMode.Normal)
  for i = 1, #trees do
    drawTree(trees[i])
  end
  time = time + 1
end

RenderTrackSubscribe(render.PassID.Main, renderBillboard)
