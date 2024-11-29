--[[
  Lightweight post-processing alternative. Meant to do a single full-res pass, so it could run as fast as possible, while
  also being compatible with YEBIS where possible.

  Features:
  • Color corrections;
  • Color grading;
  • Tonemapping (sensitometric and logarithmic aren’t entirely precise though);
  • Vignette (apart from FOV parameter at the moment);
  • Auto-exposure (simpler version because I couldn’t figure out original behaviour);
  • Lens distortion (alternative stupid version which might be somewhat more usable);
  • Chromatic aberration (without extra samples to keep things fast, but respects other settings);
  • Sun rays (alternative version, ignores settings);
  • Glare (very basic glow which shouldn’t flicker as much, ignores settings);
  • DOF (experimental single-pass effect ignoring most settings).
]]

local buffersCache = {}

table.insert(OnResolutionChange, function ()
  table.clear(buffersCache)
end)

---@param resolution vec2
local function createPPData(resolution)
  resolution = resolution:clone():scale(0.5)
  local skyMask = ui.ExtraCanvas(resolution, 1,
    render.AntialiasingMode.None, render.TextureFormat.R8.UNorm) --:setName('skyMask')
  local sunRays1 = ui.ExtraCanvas(resolution, 1,
    render.AntialiasingMode.None, render.TextureFormat.R8.UNorm) --:setName('sunRays1')
  local sunRays2 = ui.ExtraCanvas(resolution, 1,
    render.AntialiasingMode.None, render.TextureFormat.R8.UNorm) --:setName('sunRays2')
  local blur1Prepare = ui.ExtraCanvas(resolution, 1,
    render.AntialiasingMode.None, render.TextureFormat.R11G11B10.Float) --:setName('blur1Prepare')
  local blur1Ready = ui.ExtraCanvas(resolution, 1,
    render.AntialiasingMode.None, render.TextureFormat.R11G11B10.Float) --:setName('blur1Ready')
  local blur2Ready = ui.ExtraCanvas(resolution:scale(0.5), 1,
    render.AntialiasingMode.None, render.TextureFormat.R11G11B10.Float) --:setName('blur2Ready')
  return {
    skyMask = skyMask, 
    sunRays1 = sunRays1, 
    sunRays2 = sunRays2, 
    blur1Prepare = blur1Prepare, 
    blur1Ready = blur1Ready, 
    blur2Ready = blur2Ready,
    passSkyMaskParams = {
      textures = {
        ['txHDR'] = 'dynamic::pp::hdr',
        ['txDepth.1'] = 'dynamic::pp::depth',
      },
      values = {
        gBrightnessMult = 0.65
      },
      shader = [[float4 main(PS_IN pin) {
        return dot(txDepth.GatherRed(samLinearBorder0, pin.Tex) == 1, 0.25) 
          * saturate(txHDR.SampleLevel(samLinearBorder0, pin.Tex, 0).b * gBrightnessMult);
      }]]
    },
    passSun1Params = {
      textures = {
        ['txNoise'] = 'dynamic::noise',
        ['txMask.1'] = skyMask,
      },
      values = {
        gSunPosition = vec2()
      },
      shader = [[float4 main(PS_IN pin) {
        float m = 0;
        float2 d = gSunPosition - pin.Tex;
        // d *= min(1, min(d.x > 0 ? (1 - pin.Tex.x) / d.x  : pin.Tex.x / -d.x, d.y > 0 ? (1 - pin.Tex.y) / d.y  : pin.Tex.y / -d.y)) / 10;
        d /= 10;
        float2 s = pin.Tex + d * txNoise.Load(int3(pin.PosH.xy % 32, 0)).x;
        for (int i = 0; i < 10; ++i){
          m += txMask.SampleLevel(samLinearBorder0, s, 0);
          s += d;
        }
        return m / 10;
      }]]
    },
    passSun2Params = {
      textures = {
        ['txIn.1'] = sunRays1,
      },
      values = {
        gSunPosition = vec2()
      },
      shader = [[float4 main(PS_IN pin) {
        float m = 0;
        float2 dir = gSunPosition - pin.Tex;
        for (int i = -5; i < 5; ++i) m += txIn.SampleLevel(samLinearClamp, pin.Tex + dir * (i / 25.), 0);
        return m / 10;
      }]]
    },
    passSun3Params = {
      textures = {
        ['txIn.1'] = sunRays2,
      },
      values = {
        gSunPosition = vec2()
      },
      shader = [[float4 main(PS_IN pin) {
        float m = 0;
        float2 dir = (gSunPosition - pin.Tex);
        for (int i = -5; i < 5; ++i) m += txIn.SampleLevel(samLinearClamp, pin.Tex + dir * (i / 100.), 0);
        return m / 10;
      }]]
    },
    pass1Params = {
      textures = {
        txInput = 'dynamic::pp::hdr',
      },
      values = {
        gThreshold = 0,
        gBrightnessMult = 0,
      },
      shader = 'shaders/pp_blur_prepare.fx'
    },
    pass2Params = {
      blendMode = render.BlendMode.Opaque,
      depthMode = render.DepthMode.Off,
      textures = {
        txInput = 'dynamic::pp::hdr',
        txBlur1 = blur1Ready,
        txBlur2 = blur2Ready,
        ['txMask.1'] = skyMask,
        ['txSunRaysMask.1'] = sunRays1,
        txColorGrading = 'dynamic::pp::colorGrading3D',
      },
      values = {
        gMatHDR = mat4x4(),
        gMatLDR = mat4x4(),
        gColorGrading = 0,
        gVignette = 0,
        gVignetteRatio = vec2(1, 1),
        gExposure = 1,
        gGamma = 1,
        gMappingFactor = 32,
        gMappingData = vec4(),
        gGlareLuminance = 1,
        gLensDistortion = 0,
        gLensDistortionRoundness = 0,
        gLensDistortionSmoothness = 0,
        gSunPosition = vec2(),
        gSunColor = rgb(),
        gChromaticAberrationLateral = vec2(),
        gChromaticAberrationUniform = vec2(),
        gTime = 0,
        gGammaFixBrightnessOffset = 0
      },
      defines = {
        TONEMAP_FN = -1,
        USE_GLARE = false,
        USE_SUN_RAYS = false,
        USE_COLOR_GRADING = false,
        USE_VIGNETTE = false,
        USE_LENS_DISTORTION = false,
        USE_CHROMATIC_ABERRATION = false,
        USE_FILM_GRAIN = false,
        USE_GLARE_CHROMATIC_ABERRATION = ScriptSettings.POSTPROCESSING.GLARE_CHROMATIC_ABERRATION
      },
      cacheKey = 0,
      directValuesExchange = true,
      shader = 'shaders/pp_final.fx'
    },
    useDof = false
  } 
end

local aeMeasure1 = ui.ExtraCanvas(256, 8, render.TextureFormat.R16.Float)
local aeMeasure2 = ui.ExtraCanvas(vec2(4, 256), 8, render.TextureFormat.R16.Float)
local aeMeasure3 = ui.ExtraCanvas(4, 4, render.TextureFormat.R16.Float)
local aeMeasured = 0
local aeCurrent = tonumber(ac.load('wfx.base.ae')) or 1
if not math.isfinite(aeCurrent) then aeCurrent = 1 end

table.insert(OnGammaFixChange, function ()
  aeCurrent = 1
end)

local aePass1 = {
  textures = {
    txInput = 'dynamic::pp::hdr',
  },
  values = {
    gGammaFixBrightnessOffset = 1,
    gMappingFactor = 32,
    gMappingData = vec4(),
    gAreaSize = vec2(),
    gAreaOffset = vec2(),
  },
  defines = {},
  cacheKey = 1,
  shader = 'shaders/pp_ae_1.fx'
}

local aePass2 = {
  textures = {
    ['txInput.1'] = aeMeasure1,
  },
  shader = [[float main(PS_IN pin) {
    float r = 0;
    for (int i = 0; i < 64; ++i) {
      r += txInput.Load(int3((int)pin.PosH.x * 64 + i, (int)pin.PosH.y, 0));
    }
    return r / 64;
  }]]
}

local aePass3 = {
  textures = {
    ['txInput.1'] = aeMeasure2,
  },
  shader = [[float main(PS_IN pin) {
    float r = 0;
    for (int i = 0; i < 64; ++i) {
      r += txInput.Load(int3((int)pin.PosH.x, (int)pin.PosH.y * 64 + i, 0));
    }
    return r / 64;
  }]]
}

---@param data ui.ExtraCanvasData
local function autoExposureDataCallback(err, data)
  if data then
    local v = 0
    for y = 0, 3 do
      for x = 0, 3 do
        v = v + data:floatValue(x, y)
      end
    end
    aeMeasured = math.exp(v / 16)
    data:dispose()
  else
    aeMeasured = 0
  end
end

SunRaysCustom = true

local function createDevPPData(resolution)
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

---@param params ac.PostProcessingParameters
---@param finalExposure number
local function configureAutoExposure(passParams, params, finalExposure, limited)
  local tonemap = params.tonemapFunction < 0 and 2 or params.tonemapFunction
  if limited and tonemap > 6 then
    limited = 2
  end
  passParams.values.gExposure = finalExposure
  passParams.values.gGamma = 1 / params.tonemapGamma
  passParams.values.gMappingFactor = params.tonemapMappingFactor
  if tonemap == 2 then
    passParams.values.gMappingData.x = math.lerp(1.4, 3.2, params.filmicContrast ^ 0.6)
    passParams.values.gMappingData.y = math.lerp(0.1, 0.9, params.filmicContrast ^ 0.6)
  elseif tonemap == 3 or tonemap == 4 then
    passParams.values.gMappingData.x = 1 / (params.tonemapMappingFactor * finalExposure) ^ 2
  elseif tonemap == 5 or tonemap == 6 then
    passParams.values.gMappingData.x = math.log(params.tonemapMappingFactor + 1) / 0.6931
    passParams.values.gMappingData.y = 1 / passParams.values.gMappingData.x
    passParams.values.gMappingData.z = 1 / (params.tonemapMappingFactor * finalExposure) ^ 2
  end    
  if passParams.defines.TONEMAP_FN ~= tonemap then
    passParams.defines.TONEMAP_FN = tonemap
    passParams.cacheKey = bit.bor(bit.band(passParams.cacheKey, bit.bnot(127)), tonemap)
  end  
end

local finalExposure = 1
local lastBrightnessMult = -1
ac.onPostProcessing(function (params, exposure, mainPass, updateExponent, rtSize)
  if mainPass and ScriptSettings.LINEAR_COLOR_SPACE.DEV_MODE and Overrides.originalPostProcessing then
    if not UseGammaFix then
      return
    end
    local data = table.getOrCreate(buffersCache, 2e7 + rtSize.y * 10000 + rtSize.x, createDevPPData, rtSize)
    data.params.values.gBrightness = 0.45 / GammaFixBrightnessOffset
    data.canvas:updateWithShader(data.params)
    return data.canvas
  end

  local data = table.getOrCreate(buffersCache, (mainPass and 0 or 1e7) + rtSize.y * 10000 + rtSize.x, createPPData, rtSize)
  if Sim.isPreviewsGenerationMode then
    params.autoExposureEnabled = false
    params.godraysEnabled = false
    params.chromaticAberrationEnabled = false
    params.dofActive = false
    params.lensDistortionEnabled = false
    params.vignetteStrength = 0
  end

  if updateExponent and mainPass then
    -- We could add separate autoexposure to non-main views if we’d want to, but we don’t
    if params.autoExposureEnabled then
      aePass1.values.gGammaFixBrightnessOffset = UseGammaFix and 0.45 / GammaFixBrightnessOffset or 1
      aePass1.values.gAreaOffset:set(params.autoExposureAreaOffset)
      aePass1.values.gAreaSize:set(params.autoExposureAreaSize)
      configureAutoExposure(aePass1, params, 1, true)
      aeMeasure1:updateWithShader(aePass1)
      aeMeasure2:updateWithShader(aePass2)
      aeMeasure3:updateWithShader(aePass3)
      aeMeasure3:accessData(autoExposureDataCallback)
      if aeMeasured > 0 then
        local aeTarget = params.autoExposureTarget * exposure / aeMeasured
        if UseGammaFix then
          -- TODO: Find a better way?
          aeTarget = aeTarget * (Sim.isFocusedOnInterior and 0.35 or 0.6)
        end
        aeTarget = math.clamp(aeTarget, params.autoExposureMin, params.autoExposureMax)
        if lastBrightnessMult ~= -1 and BrightnessMultApplied > 0 then
          aeCurrent = aeCurrent * lastBrightnessMult / BrightnessMultApplied
        end
        lastBrightnessMult = BrightnessMultApplied
        aeCurrent = math.applyLag(aeCurrent, aeTarget, RecentlyJumped > 0 and 0 or 0.97, ac.getDeltaT())
        ac.store('wfx.base.ae', aeCurrent)
        finalExposure = aeCurrent
        -- ac.debug('aeTarget', aeTarget)
        -- ac.debug('aeCurrent', aeCurrent)
      end
      -- ac.debug('finalExposure', finalExposure)
    else
      finalExposure = params.tonemapExposure
    end
  end

  local useDof = mainPass and params.dofActive and params.dofActive and params.dofQuality >= 4
  if useDof ~= data.useDof then
    if not data.dofPrepared then
      data.dofPrepared = ui.ExtraCanvas(rtSize:clone():scale(0.5), 1, render.TextureFormat.R16G16B16A16.Float) --:setName('dofPrepared')
      data.dofOutput = ui.ExtraCanvas(rtSize, 1, render.TextureFormat.R16G16B16A16.Float) --:setName('dofOutput')
      data.passDofPrepare = {
        textures = {
          txInput = 'dynamic::pp::hdr',
          ['txDepth.1'] = 'dynamic::pp::depth',
        },
        shader = [[float4 main(PS_IN pin) {
          return float4(txInput.SampleLevel(samLinearSimple, pin.Tex, 0).rgb, txDepth.SampleLevel(samLinearSimple, pin.Tex, 0));
        }]]
      }
      data.passDofProcess = {
        textures = {
          txInput = 'dynamic::pp::hdr',
          ['txDepth.1'] = 'dynamic::pp::depth',
          txDOF = data.dofPrepared,
        },
        values = {
          focusPoint = 0,
          focusScale = 0,
          uPixelSize = 1 / rtSize,
        },
        directValuesExchange = true,
        shader = 'shaders/pp_dof.fx'
      }
    end
    data.useDof = useDof
    data.pass1Params.textures.txInput = useDof and data.dofOutput or 'dynamic::pp::hdr'
    data.pass2Params.textures.txInput = useDof and data.dofOutput or 'dynamic::pp::hdr'
  end

  if useDof then
    local gNearPlane = params.cameraNearPlane
    local gFarPlane = params.cameraFarPlane
    local focusPoint = (gFarPlane + gNearPlane - 2 * gNearPlane * gFarPlane / params.dofFocusDistance) / (gFarPlane - gNearPlane) / 2 + 0.5
    data.passDofProcess.values.focusPoint = focusPoint
    data.passDofProcess.values.focusScale = (1 + focusPoint * 5) * 6 / params.dofApertureFNumber
    data.dofPrepared:updateWithShader(data.passDofPrepare)
    data.dofOutput:updateWithShader(data.passDofProcess)
  end

  data.pass2Params.values.gMatHDR:set(ac.getPostProcessingHDRColorMatrix())
  data.pass2Params.values.gMatHDR:transposeSelf() -- with `directValuesExchange` we need to transpose matrices manually

  data.pass2Params.values.gMatLDR:set(ac.getPostProcessingLDRColorMatrix())
  data.pass2Params.values.gMatLDR:transposeSelf() 

  local ratioHalf = (rtSize.x / rtSize.y + 0.5) / 2
  data.pass2Params.values.gVignetteRatio:set(ratioHalf, 1 / ratioHalf)

  configureAutoExposure(data.pass2Params, params, finalExposure)

  local useGlare = params.glareEnabled and params.glareLuminance > 0
  if useGlare ~= data.pass2Params.defines.USE_GLARE then
    data.pass2Params.defines.USE_GLARE = useGlare ~= 0
    data.pass2Params.cacheKey = bit.bor(bit.band(data.pass2Params.cacheKey, bit.bnot(128)), useGlare and 128 or 0)
  end
  if useGlare then
    data.pass1Params.values.gThreshold = params.glareThreshold * (UseGammaFix and 1 or 1)
    data.pass1Params.values.gBrightnessMult = UseGammaFix and GammaFixBrightnessOffset or 0
    data.pass2Params.values.gGlareLuminance = params.glareLuminance * 0.13 * (UseGammaFix and 1 / GammaFixBrightnessOffset or 1)
    data.blur1Prepare:updateWithShader(data.pass1Params)
    data.blur1Ready:gaussianBlurFrom(data.blur1Prepare, 23)
    data.blur2Ready:gaussianBlurFrom(data.blur1Ready, 63)
  end

  if params.vignetteStrength ~= data.pass2Params.values.gVignette then
    data.pass2Params.defines.USE_VIGNETTE = params.vignetteStrength ~= 0
    data.pass2Params.values.gVignette = params.vignetteStrength
    data.pass2Params.cacheKey = bit.bor(bit.band(data.pass2Params.cacheKey, bit.bnot(256)), params.vignetteStrength ~= 0 and 256 or 0)
  end

  local cg = ac.getPostProcessingColorGradingIntensity()
  if cg ~= data.pass2Params.values.gColorGrading then
    data.pass2Params.values.gColorGrading = cg
    data.pass2Params.defines.USE_COLOR_GRADING = cg ~= 0
    data.pass2Params.cacheKey = bit.bor(bit.band(data.pass2Params.cacheKey, bit.bnot(512)), cg ~= 0 and 512 or 0)
  end

  if data.pass2Params.defines.USE_LENS_DISTORTION ~= params.lensDistortionEnabled then
    data.pass2Params.defines.USE_LENS_DISTORTION = params.lensDistortionEnabled
    data.pass2Params.cacheKey = bit.bor(bit.band(data.pass2Params.cacheKey, bit.bnot(1024)), params.lensDistortionEnabled and 1024 or 0)
  end
  if params.lensDistortionEnabled then
    data.pass2Params.values.gLensDistortion = math.tan(params.cameraVerticalFOVRad / 2)
    data.pass2Params.values.gLensDistortionRoundness = 1 / (0.01 + params.lensDistortionRoundness)
    data.pass2Params.values.gLensDistortionSmoothness = 1 / (0.01 + params.lensDistortionSmoothness)
  end

  local useSunRays = mainPass and params.godraysEnabled and params.godraysInCameraFustrum 
    and params.godraysColor:value() > 1 and not Sim.isTripleFSRActive
  if data.pass2Params.defines.USE_SUN_RAYS ~= useSunRays then
    data.pass2Params.defines.USE_SUN_RAYS = useSunRays
    data.pass2Params.cacheKey = bit.bor(bit.band(data.pass2Params.cacheKey, bit.bnot(2048)), useSunRays and 2048 or 0)
  end
  if useSunRays then
    data.passSun1Params.values.gSunPosition:set(params.godraysOrigin)
    data.passSun2Params.values.gSunPosition:set(params.godraysOrigin)
    data.passSun3Params.values.gSunPosition:set(params.godraysOrigin)
    data.passSkyMaskParams.values.gBrightnessMult = 1e-2 / GammaFixBrightnessOffset
    data.skyMask:updateWithShader(data.passSkyMaskParams)
    data.sunRays1:updateWithShader(data.passSun1Params)
    data.sunRays2:updateWithShader(data.passSun2Params)
    data.sunRays1:updateWithShader(data.passSun3Params)
    data.pass2Params.values.gSunPosition:set(params.godraysOrigin)
    data.pass2Params.values.gSunColor:set(GodraysColor):scale(UseGammaFix and (10 * GammaFixBrightnessOffset / BrightnessMultApplied) or 1)
  end

  local useChromaticAberration = params.chromaticAberrationEnabled and params.chromaticAberrationActive
  if data.pass2Params.defines.USE_CHROMATIC_ABERRATION ~= useChromaticAberration then
    data.pass2Params.defines.USE_CHROMATIC_ABERRATION = useChromaticAberration
    data.pass2Params.cacheKey = bit.bor(bit.band(data.pass2Params.cacheKey, bit.bnot(4096)), useChromaticAberration and 4096 or 0)
  end
  if useChromaticAberration then
    data.pass2Params.values.gChromaticAberrationLateral:set(params.chromaticAberrationLateralDisplacement):div(rtSize):scale(100)
    data.pass2Params.values.gChromaticAberrationUniform:set(params.chromaticAberrationUniformDisplacement):div(rtSize):scale(100)
  end

  local useFilmGrain = ScriptSettings.POSTPROCESSING.FILM_GRAIN and Sim.cameraMode ~= ac.CameraMode.Cockpit and not Sim.isPreviewsGenerationMode
  if data.pass2Params.defines.USE_FILM_GRAIN ~= useFilmGrain then
    data.pass2Params.defines.USE_FILM_GRAIN = useFilmGrain
    data.pass2Params.cacheKey = bit.bor(bit.band(data.pass2Params.cacheKey, bit.bnot(8192)), useFilmGrain and 8192 or 0)

    if useFilmGrain then
      local noise = ui.ExtraCanvas(vec2(128, 2048))
      noise:updateWithShader({
        shader = [[
        float4 hash4(float2 p) {
          float4 q = float4(dot(p, float2(127.1, 311.7)), 
            dot(p, float2(269.5, 183.3)), 
            dot(p, float2(419.2, 371.9)), 
            dot(p, float2(381.2, 687.4)));
          return frac(sin(q) * 43758.5453);
        }
        float4 main(PS_IN pin) {
          float4 col = hash4(pin.Tex);
          col.rgb = lerp(col.rgb, dot(col.rgb, 0.33), 0.5);
          return col;
        }]]
      })
      data.pass2Params.textures.txGrain = noise or 'dynamic::noise'
    end
  end
  if useFilmGrain and not Sim.isMakingScreenshot then
    data.pass2Params.values.gTime = Sim.gameTime
  end

  if UseGammaFix then
    data.pass2Params.values.gGammaFixBrightnessOffset = 0.45 / GammaFixBrightnessOffset
  end
  render.fullscreenPass(data.pass2Params)
  return true
end)
