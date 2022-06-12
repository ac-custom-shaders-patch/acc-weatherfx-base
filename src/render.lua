--[[
  Core for extra render effects. Allows to set new functions to be called to render new stuff
  by calling `RenderSkySubscribe()` and automatically handles `ac.enableRenderCallback()`. This way,
  multiple effects can be combined together.
  TODO: Might need some extra parameter allowing to define effects order more clear.
]]

local renderSkyListeners = {}
local renderCloudsListeners = {}
local renderTrackListeners = {}

function script.renderSky(passID, frameIndex, uniqueKey)
  for i = 1, #renderSkyListeners do
    local e = renderSkyListeners[i]
    if bit.band(e.passIDMask, passID) ~= 0 then
      e.callback(passID, frameIndex, uniqueKey)
    end
  end
end

function script.renderClouds(passID, frameIndex, uniqueKey)
  for i = 1, #renderCloudsListeners do
    local e = renderCloudsListeners[i]
    if bit.band(e.passIDMask, passID) ~= 0 then
      e.callback(passID, frameIndex, uniqueKey)
    end
  end
end

function script.renderTrack(passID, frameIndex, uniqueKey)
  for i = 1, #renderTrackListeners do
    local e = renderTrackListeners[i]
    if bit.band(e.passIDMask, passID) ~= 0 then
      e.callback(passID, frameIndex, uniqueKey)
    end
  end
end

local function updateSkySubscription()
  local mSky = 0
  local mClouds = 0
  local mTrack = 0
  for i = 1, #renderSkyListeners do
    local e = renderSkyListeners[i]
    mSky = bit.bor(mSky, e.passIDMask)
  end
  for i = 1, #renderCloudsListeners do
    local e = renderCloudsListeners[i]
    mClouds = bit.bor(mClouds, e.passIDMask)
  end
  for i = 1, #renderTrackListeners do
    local e = renderTrackListeners[i]
    mTrack = bit.bor(mTrack, e.passIDMask)
  end
  ac.enableRenderCallback(mSky, mClouds, mTrack)
end

---@param passIDMask render.PassID
---@param callback fun(passID: render.PassID, frameIndex: integer, uniqueKey: integer)
---@return fun() @Call returned function to unsubscribe.
function RenderSkySubscribe(passIDMask, callback)
  if passIDMask == 0 then return function () end end
  local e = { passIDMask = passIDMask, callback = callback }
  renderSkyListeners[#renderSkyListeners + 1] = e
  updateSkySubscription()
  return function()
    table.removeItem(renderSkyListeners, e)
    updateSkySubscription()
  end
end

---@param passIDMask render.PassID
---@param callback fun(passID: render.PassID, frameIndex: integer, uniqueKey: integer)
---@return fun() @Call returned function to unsubscribe.
function RenderCloudsSubscribe(passIDMask, callback)
  if passIDMask == 0 then return function () end end
  local e = { passIDMask = passIDMask, callback = callback }
  renderCloudsListeners[#renderCloudsListeners + 1] = e
  updateSkySubscription()
  return function()
    table.removeItem(renderCloudsListeners, e)
    updateSkySubscription()
  end
end

---@param passIDMask render.PassID
---@param callback fun(passID: render.PassID, frameIndex: integer, uniqueKey: integer)
---@return fun() @Call returned function to unsubscribe.
function RenderTrackSubscribe(passIDMask, callback)
  if passIDMask == 0 then return function () end end
  local e = { passIDMask = passIDMask, callback = callback }
  renderTrackListeners[#renderTrackListeners + 1] = e
  updateSkySubscription()
  return function()
    table.removeItem(renderTrackListeners, e)
    updateSkySubscription()
  end
end
