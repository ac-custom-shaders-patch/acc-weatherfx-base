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

local intensity = 0

local function renderFog()
  render.fullscreenPass({
    blendMode = render.BlendMode.AlphaBlend,
    depthMode = render.DepthMode.ReadOnly,
    depth = 40,  -- fullscreen pass applies to areas further than 40 meters from camera, to improve performance
    shader = 'shaders/fog.fx',
    values = {
      gIntensity = intensity
    },
    async = true
  })
end

local subscribed ---@type fun()
local needsHighFogEffect = nil

function UpdateAboveFog(dt)
  local cc = CurrentConditions
  intensity = math.lerpInvSat(cc.fog, 0.8, 1)
  if intensity == 0 then
    if subscribed then
      subscribed()
      subscribed = nil
    end
    return
  end

  if needsHighFogEffect == nil then
    -- Activating effect only if there is some high enough static geometry
    local startingPoint = ac.getCar(0).pitTransform.position.y
    local _, aabbMax = ac.findMeshes('{ static:yes & alphaBlend:no & transparent:no & ! lodOut:0 & ! largerThan:500 }'):getStaticAABB()
    needsHighFogEffect = aabbMax.y - startingPoint > 100
  end

  if not subscribed and needsHighFogEffect then
    subscribed = RenderTrackSubscribe(render.PassID.Main, renderFog)
  end
end
