#import "metal_internal.h"

MetalRenderer* gActiveMetalRenderer;

static const char* kMetalDefaultShaderSource =
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "struct Vertex { float2 position; float2 uv; float4 color; };\n"
    "struct Uniforms {\n"
    "    float4x4 wvp;\n"
    "    float4 fogColor;\n"
    "    float alphaTestRef;\n"
    "    int alphaTestEnabled;\n"
    "    int _pad0;\n"
    "    int _pad1;\n"
    "};\n"
    "struct VSOut {\n"
    "    float4 position [[position]];\n"
    "    float2 uv;\n"
    "    float4 color;\n"
    "};\n"
    "vertex VSOut bs_vertex(const device Vertex* vertices [[buffer(0)]],\n"
    "                       constant Uniforms& uniforms [[buffer(1)]],\n"
    "                       uint id [[vertex_id]]) {\n"
    "    VSOut out;\n"
    "    float4 pos = float4(vertices[id].position, 0.0, 1.0);\n"
    "    out.position = uniforms.wvp * pos;\n"
    "    out.uv = vertices[id].uv;\n"
    "    out.color = vertices[id].color;\n"
    "    return out;\n"
    "}\n"
    "fragment float4 bs_fragment(VSOut in [[stage_in]],\n"
    "                            constant Uniforms& uniforms [[buffer(1)]],\n"
    "                            texture2d<float> texture [[texture(0)]],\n"
    "                            sampler samp [[sampler(0)]]) {\n"
    "    float4 c = texture.sample(samp, in.uv) * in.color;\n"
    "    if (uniforms.alphaTestEnabled != 0 && uniforms.alphaTestRef >= c.a) discard_fragment();\n"
    "    c.rgb = mix(c.rgb, uniforms.fogColor.rgb, uniforms.fogColor.a);\n"
    "    return c;\n"
    "}\n";

MTLBlendFactor metalBlendFactorToMTL(int factor) {
    switch (factor) {
        case bm_zero: return MTLBlendFactorZero;
        case bm_one: return MTLBlendFactorOne;
        case bm_src_color: return MTLBlendFactorSourceColor;
        case bm_inv_src_color: return MTLBlendFactorOneMinusSourceColor;
        case bm_src_alpha: return MTLBlendFactorSourceAlpha;
        case bm_inv_src_alpha: return MTLBlendFactorOneMinusSourceAlpha;
        case bm_dest_alpha: return MTLBlendFactorDestinationAlpha;
        case bm_inv_dest_alpha: return MTLBlendFactorOneMinusDestinationAlpha;
        case bm_dest_color: return MTLBlendFactorDestinationColor;
        case bm_inv_dest_color: return MTLBlendFactorOneMinusDestinationColor;
        case bm_src_alpha_sat: return MTLBlendFactorSourceAlphaSaturated;
        default: return MTLBlendFactorOne;
    }
}

MTLBlendOperation metalBlendModeToEquation(int mode) {
    switch (mode) {
        case bm_reverse_subtract: return MTLBlendOperationReverseSubtract;
        case bm_min: return MTLBlendOperationMin;
        case bm_max: return MTLBlendOperationMax;
        default: return MTLBlendOperationAdd;
    }
}

void metalFillBlendFactors(MetalRenderer* metal, MTLRenderPipelineColorAttachmentDescriptor* attachment) {
    attachment.blendingEnabled = metal->blendEnabled;
    attachment.rgbBlendOperation = metalBlendModeToEquation(metal->currentBlendMode);
    attachment.alphaBlendOperation = metalBlendModeToEquation(metal->currentBlendMode);
    if (metal->currentBlendMode == bm_subtract) {
        // GL uses ZERO / ONE_MINUS_SRC_COLOR with ADD for subtract.
        attachment.sourceRGBBlendFactor = MTLBlendFactorZero;
        attachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceColor;
        attachment.sourceAlphaBlendFactor = MTLBlendFactorZero;
        attachment.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceColor;
    } else {
        attachment.sourceRGBBlendFactor = metalBlendFactorToMTL(metal->currentSFactor);
        attachment.destinationRGBBlendFactor = metalBlendFactorToMTL(metal->currentDFactor);
        attachment.sourceAlphaBlendFactor = metalBlendFactorToMTL(metal->currentSFactorAlpha);
        attachment.destinationAlphaBlendFactor = metalBlendFactorToMTL(metal->currentDFactorAlpha);
    }
    MTLColorWriteMask mask = MTLColorWriteMaskNone;
    if (metal->colorWriteR) mask |= MTLColorWriteMaskRed;
    if (metal->colorWriteG) mask |= MTLColorWriteMaskGreen;
    if (metal->colorWriteB) mask |= MTLColorWriteMaskBlue;
    if (metal->colorWriteA) mask |= MTLColorWriteMaskAlpha;
    attachment.writeMask = mask;
}

static bool metalPipelineKeysEqual(const MetalPipelineKey* a, const MetalPipelineKey* b) {
    return a->blendMode == b->blendMode &&
           a->sfactor == b->sfactor &&
           a->dfactor == b->dfactor &&
           a->sfactorAlpha == b->sfactorAlpha &&
           a->dfactorAlpha == b->dfactorAlpha &&
           a->blendEnabled == b->blendEnabled &&
           a->colorWriteMask == b->colorWriteMask &&
           a->shaderIndex == b->shaderIndex &&
           a->pixelFormat == b->pixelFormat;
}

static MTLPixelFormat metalCurrentTargetPixelFormat(MetalRenderer* metal) {
    id<MTLTexture> target = metal->encoderTarget != nil ? metal->encoderTarget : metal->currentTarget;
    if (target != nil) return target.pixelFormat;
    return MTLPixelFormatRGBA8Unorm;
}

static MetalPipelineKey metalMakePipelineKey(MetalRenderer* metal) {
    MetalPipelineKey key = {0};
    key.blendMode = metal->currentBlendMode;
    key.sfactor = metal->currentSFactor;
    key.dfactor = metal->currentDFactor;
    key.sfactorAlpha = metal->currentSFactorAlpha;
    key.dfactorAlpha = metal->currentDFactorAlpha;
    key.blendEnabled = metal->blendEnabled;
    key.colorWriteMask = (uint8_t)((metal->colorWriteR ? 1 : 0) |
                                   (metal->colorWriteG ? 2 : 0) |
                                   (metal->colorWriteB ? 4 : 0) |
                                   (metal->colorWriteA ? 8 : 0));
    key.shaderIndex = metal->base.currentShader;
    key.pixelFormat = metalCurrentTargetPixelFormat(metal);
    return key;
}

id<MTLRenderPipelineState> metalGetPipeline(MetalRenderer* metal) {
    MetalPipelineKey key = metalMakePipelineKey(metal);
    for (uint32_t i = 0; i < metal->pipelineCacheCount; i++) {
        if (metalPipelineKeysEqual(&metal->pipelineCache[i].key, &key))
            return metal->pipelineCache[i].pipeline;
    }

    id<MTLFunction> vert = metal->defaultVertexFunction;
    id<MTLFunction> frag = metal->defaultFragmentFunction;
    if (key.shaderIndex >= 0 && (uint32_t)key.shaderIndex < metal->gmlShaderCount) {
        MetalGMLShader* shader = &metal->gmlShaders[key.shaderIndex];
        if (shader->compiled && shader->vertexFunction != nil && shader->fragmentFunction != nil) {
            vert = shader->vertexFunction;
            frag = shader->fragmentFunction;
        }
    }

    MTLRenderPipelineDescriptor* desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vert;
    desc.fragmentFunction = frag;
    desc.colorAttachments[0].pixelFormat = key.pixelFormat;
    metalFillBlendFactors(metal, desc.colorAttachments[0]);

    NSError* error = nil;
    id<MTLRenderPipelineState> pipeline = [metal->device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (pipeline == nil) {
        logError("Metal: pipeline creation failed: %s\n", error.localizedDescription.UTF8String);
        return metal->defaultPipeline;
    }

    if (metal->pipelineCacheCount < METAL_MAX_PIPELINE_CACHE) {
        metal->pipelineCache[metal->pipelineCacheCount].key = key;
        metal->pipelineCache[metal->pipelineCacheCount].pipeline = pipeline;
        metal->pipelineCacheCount++;
    }
    return pipeline;
}

void metalEndEncoder(MetalRenderer* metal) {
    if (metal->encoder != nil) {
        [metal->encoder endEncoding];
        metal->encoder = nil;
    }
    metal->encoderTarget = nil;
}

void metalEnsureEncoder(MetalRenderer* metal, bool clear, MTLClearColor clearColor) {
    if (metal->commandBuffer == nil || metal->currentTarget == nil) return;
    // Must recreate whenever the color attachment changes; Metal validates scissor
    // against the active render pass, not our bookkeeping pointer.
    if (metal->encoder != nil && !clear && metal->encoderTarget == metal->currentTarget) return;

    metalEndEncoder(metal);

    MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = metal->currentTarget;
    pass.colorAttachments[0].loadAction = clear ? MTLLoadActionClear : MTLLoadActionLoad;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    if (clear) pass.colorAttachments[0].clearColor = clearColor;
    metal->encoder = [metal->commandBuffer renderCommandEncoderWithDescriptor:pass];
    metal->encoderTarget = metal->currentTarget;
}

void metalBindSurfaceTarget(MetalRenderer* metal, int32_t surfaceId, bool clear, MTLClearColor clearColor) {
    if (surfaceId < 0 || (uint32_t)surfaceId >= metal->surfaceCount || !metal->surfaceAlive[surfaceId]) {
        return;
    }
    metal->currentSurfaceId = surfaceId;
    metal->currentTarget = metal->surfaceTextures[surfaceId];
    metalEnsureEncoder(metal, clear, clearColor);
    if (metal->encoder != nil) {
        metalApplyViewportScissor(metal, 0, 0,
                                  metal->surfaceWidth[surfaceId], metal->surfaceHeight[surfaceId], false);
    }
}

void metalApplyViewportScissor(MetalRenderer* metal, int32_t x, int32_t y, int32_t w, int32_t h, bool enableScissor) {
    if (metal->encoder == nil) return;
    // Clamp against the encoder's actual color attachment — never currentTarget alone,
    // which can briefly disagree while switching surfaces.
    id<MTLTexture> pass = metal->encoderTarget != nil ? metal->encoderTarget : metal->currentTarget;
    int32_t targetW = pass != nil ? (int32_t)pass.width : metal->gameW;
    int32_t targetH = pass != nil ? (int32_t)pass.height : metal->gameH;
    if (targetW <= 0) targetW = 1;
    if (targetH <= 0) targetH = 1;

    if (w < 0) w = 0;
    if (h < 0) h = 0;
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x >= targetW) { x = 0; w = 0; }
    if (y >= targetH) { y = 0; h = 0; }
    if (x + w > targetW) w = targetW - x;
    if (y + h > targetH) h = targetH - y;
    if (w < 0) w = 0;
    if (h < 0) h = 0;
    // Metal rejects zero-size scissor rects in some validation paths; use 1x1 at origin.
    if (w == 0 || h == 0) { x = 0; y = 0; w = 1; h = 1; }

    [metal->encoder setViewport:(MTLViewport){(double)x, (double)y, (double)w, (double)h, 0.0, 1.0}];
    if (enableScissor) {
        [metal->encoder setScissorRect:(MTLScissorRect){(NSUInteger)x, (NSUInteger)y, (NSUInteger)w, (NSUInteger)h}];
    } else {
        [metal->encoder setScissorRect:(MTLScissorRect){0, 0, (NSUInteger)targetW, (NSUInteger)targetH}];
    }
}

void metalUploadDefaultUniforms(MetalRenderer* metal) {
    // Match GL: flip clip Y when uploading world->clip (GameMaker Y-down vs Metal NDC).
    Matrix4f wvp = metal->base.gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION];
    //Matrix4f_flipClipY(&wvp);
    memcpy(&metal->defaultUniforms.wvp, wvp.m, sizeof(matrix_float4x4));
    metal->defaultUniforms.fogColor = (vector_float4){
        BGR_R(metal->fogColor) / 255.0f,
        BGR_G(metal->fogColor) / 255.0f,
        BGR_B(metal->fogColor) / 255.0f,
        metal->fogEnable ? 1.0f : 0.0f
    };
    metal->defaultUniforms.alphaTestRef = metal->alphaTestRef;
    metal->defaultUniforms.alphaTestEnabled = metal->alphaTestEnable ? 1 : 0;
}

void metalBindDrawState(MetalRenderer* metal) {
    if (metal->encoder == nil) return;
    logInfo("Metal draw: shader=%d fog=%d fogColor=%08x\n",
        metal->base.currentShader,
        metal->fogEnable,
        metal->fogColor);
        
    id<MTLRenderPipelineState> pipeline = metalGetPipeline(metal);
    [metal->encoder setRenderPipelineState:pipeline];

    if (metal->base.currentShader >= 0 && (uint32_t)metal->base.currentShader < metal->gmlShaderCount &&
        metal->gmlShaders[metal->base.currentShader].compiled) {
        metalRefreshShaderBuiltins(metal);
        MetalGMLShader* shader = &metal->gmlShaders[metal->base.currentShader];
        if (shader->uniformFloatCount > 0 && shader->uniformData != nullptr) {
            [metal->encoder setVertexBytes:shader->uniformData
                                    length:shader->uniformFloatCount * sizeof(float)
                                   atIndex:1];
            [metal->encoder setFragmentBytes:shader->uniformData
                                      length:shader->uniformFloatCount * sizeof(float)
                                     atIndex:1];
        }
        for (uint32_t i = 0; i < shader->samplerCount && i < METAL_MAX_SHADER_SAMPLERS; i++) {
            id<MTLTexture> tex = metal->stagedTextures[i];
            if (tex == nil) tex = metal->whiteTexture;
            [metal->encoder setFragmentTexture:tex atIndex:i];
            [metal->encoder setFragmentSamplerState:metal->nearestSampler atIndex:i];
        }
    } else {
        metalUploadDefaultUniforms(metal);
        [metal->encoder setVertexBytes:&metal->defaultUniforms length:sizeof(MetalDefaultUniforms) atIndex:1];
        [metal->encoder setFragmentBytes:&metal->defaultUniforms length:sizeof(MetalDefaultUniforms) atIndex:1];
        [metal->encoder setFragmentSamplerState:metal->nearestSampler atIndex:0];
    }
}

bool metalEnsureTextureLoaded(MetalRenderer* metal, uint32_t pageId) {
    if (pageId >= metal->textureCount) return false;
    if (metal->textureLoaded[pageId]) return metal->textures[pageId] != nil;

    metal->textureLoaded[pageId] = true;
    DataWin* dataWin = metal->base.dataWin;
    if (pageId >= dataWin->txtr.count) return false;
    Texture* texture = &dataWin->txtr.textures[pageId];
    DataWin_loadTxtrIfNeeded(dataWin, pageId);

    int width = 0;
    int height = 0;
    bool gm2022_5 = DataWin_isVersionAtLeast(dataWin, 2022, 5, 0, 0);
    uint8_t* pixels = ImageDecoder_decodeToRgba(texture->blobData, (size_t)texture->blobSize,
                                                gm2022_5, &width, &height);
    if (pixels == nullptr) {
        logWarn("Metal: failed to decode TXTR page %u\n", pageId);
        return false;
    }
    if (!texture->mapped) {
        free(texture->blobData);
        texture->blobData = nullptr;
    }

    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                             width:(NSUInteger)width
                                                                                            height:(NSUInteger)height
                                                                                         mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> gpuTexture = [metal->device newTextureWithDescriptor:descriptor];
    [gpuTexture replaceRegion:MTLRegionMake2D(0, 0, (NSUInteger)width, (NSUInteger)height)
                  mipmapLevel:0
                    withBytes:pixels
                  bytesPerRow:(NSUInteger)width * 4];
    free(pixels);

    metal->textures[pageId] = gpuTexture;
    metal->textureWidths[pageId] = width;
    metal->textureHeights[pageId] = height;
    logInfo("Metal: loaded TXTR page %u (%dx%d)\n", pageId, width, height);
    return true;
}

bool metalResolveTpag(MetalRenderer* metal, int32_t tpagIndex, TexturePageItem** outTpag, uint32_t* outPageId) {
    DataWin* dataWin = metal->base.dataWin;
    if (tpagIndex < 0 || (uint32_t)tpagIndex >= dataWin->tpag.count) return false;
    TexturePageItem* tpag = &dataWin->tpag.items[tpagIndex];
    if (tpag->texturePageId < 0 || (uint32_t)tpag->texturePageId >= metal->textureCount) return false;
    *outTpag = tpag;
    *outPageId = (uint32_t)tpag->texturePageId;
    return true;
}

uint32_t metalFindOrAllocTexturePageSlot(MetalRenderer* metal) {
    for (uint32_t i = metal->originalTexturePageCount; i < metal->textureCount; i++) {
        if (metal->textures[i] == nil) return i;
    }
    uint32_t newPageId = metal->textureCount;
    metal->textureCount++;
    metal->textures = (__strong id<MTLTexture>*)safeRealloc(metal->textures, metal->textureCount * sizeof(id<MTLTexture>));
    metal->textureWidths = (int32_t*)safeRealloc(metal->textureWidths, metal->textureCount * sizeof(int32_t));
    metal->textureHeights = (int32_t*)safeRealloc(metal->textureHeights, metal->textureCount * sizeof(int32_t));
    metal->textureLoaded = (bool*)safeRealloc(metal->textureLoaded, metal->textureCount * sizeof(bool));
    metal->textures[newPageId] = nil;
    metal->textureWidths[newPageId] = 0;
    metal->textureHeights[newPageId] = 0;
    metal->textureLoaded[newPageId] = false;
    return newPageId;
}

uint32_t metalFindOrAllocTpagSlot(DataWin* dw, uint32_t originalTpagCount) {
    for (uint32_t i = originalTpagCount; i < dw->tpag.count; i++) {
        if (dw->tpag.items[i].texturePageId == -1) return i;
    }
    uint32_t newIndex = dw->tpag.count;
    dw->tpag.count++;
    dw->tpag.items = (TexturePageItem*)safeRealloc(dw->tpag.items, dw->tpag.count * sizeof(TexturePageItem));
    memset(&dw->tpag.items[newIndex], 0, sizeof(TexturePageItem));
    dw->tpag.items[newIndex].texturePageId = -1;
    return newIndex;
}

uint32_t metalFindOrAllocateSurfaceSlot(MetalRenderer* metal) {
    for (uint32_t i = 0; i < metal->surfaceCount; i++) {
        if (!metal->surfaceAlive[i]) return i;
    }
    uint32_t newIndex = metal->surfaceCount;
    metal->surfaceCount++;
    metal->surfaceTextures = (__strong id<MTLTexture>*)safeRealloc(metal->surfaceTextures, metal->surfaceCount * sizeof(id<MTLTexture>));
    metal->surfaceWidth = (int32_t*)safeRealloc(metal->surfaceWidth, metal->surfaceCount * sizeof(int32_t));
    metal->surfaceHeight = (int32_t*)safeRealloc(metal->surfaceHeight, metal->surfaceCount * sizeof(int32_t));
    metal->surfaceAlive = (bool*)safeRealloc(metal->surfaceAlive, metal->surfaceCount * sizeof(bool));
    metal->surfaceTextures[newIndex] = nil;
    metal->surfaceWidth[newIndex] = 0;
    metal->surfaceHeight[newIndex] = 0;
    metal->surfaceAlive[newIndex] = false;
    return newIndex;
}

id<MTLTexture> metalCreateRenderTexture(MetalRenderer* metal, int32_t width, int32_t height) {
    if (width <= 0 || height <= 0) return nil;
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                             width:(NSUInteger)width
                                                                                            height:(NSUInteger)height
                                                                                         mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    descriptor.storageMode = MTLStorageModeShared;
    return [metal->device newTextureWithDescriptor:descriptor];
}

static void metalInit(Renderer* renderer, DataWin* dataWin) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    CAMetalLayer* layer = (__bridge CAMetalLayer*)platformGetMetalLayer();

    renderer->dataWin = dataWin;
    Matrix4f world;
    Matrix4f_identity(&world);
    renderer->gmlMatrices[MATRIX_WORLD] = world;

    metal->device = MTLCreateSystemDefaultDevice();
    if (metal->device == nil || layer == nil) {
        logError("Metal: no default device or CAMetalLayer is available\n");
        return;
    }

    layer.device = metal->device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = NO; // need to sample/blit from drawable path via surfaces
    layer.magnificationFilter = kCAFilterNearest;
    layer.minificationFilter = kCAFilterNearest;
    metal->commandQueue = [metal->device newCommandQueue];

    NSError* error = nil;
    metal->defaultLibrary = [metal->device newLibraryWithSource:[NSString stringWithUTF8String:kMetalDefaultShaderSource]
                                                         options:nil
                                                           error:&error];
    if (metal->defaultLibrary == nil) {
        logError("Metal: default shader library failed: %s\n", error.localizedDescription.UTF8String);
        return;
    }
    metal->defaultVertexFunction = [metal->defaultLibrary newFunctionWithName:@"bs_vertex"];
    metal->defaultFragmentFunction = [metal->defaultLibrary newFunctionWithName:@"bs_fragment"];

    MTLRenderPipelineDescriptor* pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = metal->defaultVertexFunction;
    pipelineDescriptor.fragmentFunction = metal->defaultFragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    pipelineDescriptor.colorAttachments[0].blendingEnabled = YES;
    pipelineDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    metal->defaultPipeline = [metal->device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (metal->defaultPipeline == nil) {
        logError("Metal: default pipeline failed: %s\n", error.localizedDescription.UTF8String);
        return;
    }

    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.colorAttachments[0].blendingEnabled = NO;
    metal->presentPipeline = [metal->device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (metal->presentPipeline == nil) {
        logError("Metal: present pipeline failed: %s\n", error.localizedDescription.UTF8String);
        return;
    }

    MTLTextureDescriptor* whiteDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                  width:1 height:1 mipmapped:NO];
    metal->whiteTexture = [metal->device newTextureWithDescriptor:whiteDescriptor];
    uint32_t whitePixel = 0xFFFFFFFFu;
    [metal->whiteTexture replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0
                             withBytes:&whitePixel bytesPerRow:sizeof(whitePixel)];

    MTLSamplerDescriptor* samplerDesc = [[MTLSamplerDescriptor alloc] init];
    samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
    samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    metal->nearestSampler = [metal->device newSamplerStateWithDescriptor:samplerDesc];
    samplerDesc.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDesc.tAddressMode = MTLSamplerAddressModeRepeat;
    metal->nearestRepeatSampler = [metal->device newSamplerStateWithDescriptor:samplerDesc];

    metal->textureCount = dataWin->txtr.count;
    metal->originalTexturePageCount = dataWin->txtr.count;
    metal->originalTpagCount = dataWin->tpag.count;
    metal->originalSpriteCount = dataWin->sprt.count;
    metal->textures = (__strong id<MTLTexture>*)safeCalloc(metal->textureCount, sizeof(id<MTLTexture>));
    metal->textureWidths = (int32_t*)safeCalloc(metal->textureCount, sizeof(int32_t));
    metal->textureHeights = (int32_t*)safeCalloc(metal->textureCount, sizeof(int32_t));
    metal->textureLoaded = (bool*)safeCalloc(metal->textureCount, sizeof(bool));
    metal->stagedTextures = (__strong id<MTLTexture>*)safeCalloc(MAX_TEXTURE_STAGES, sizeof(id<MTLTexture>));

    metal->blendEnabled = true;
    metal->colorWriteR = metal->colorWriteG = metal->colorWriteB = metal->colorWriteA = true;
    metal->alphaTestEnable = false;
    metal->alphaTestRef = 0.0f;
    metal->fogEnable = false;
    metal->fogColor = 0;
    metal->currentBlendMode = bm_normal;
    metal->currentSFactor = bm_src_alpha;
    metal->currentDFactor = bm_inv_src_alpha;
    metal->currentSFactorAlpha = bm_src_alpha;
    metal->currentDFactorAlpha = bm_inv_src_alpha;
    metal->currentSurfaceId = -1;
    metal->videoSurfaceId = -1;

    metalInitShaders(metal, dataWin);
    logInfo("Metal: initialized device %s (%u shaders)\n", metal->device.name.UTF8String, metal->gmlShaderCount);
}

static void metalDestroy(Renderer* renderer) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    metalEndEncoder(metal);
    metalDestroyShaders(metal);
    metal->commandBuffer = nil;
    metal->drawable = nil;
    metal->commandQueue = nil;
    metal->device = nil;
    free(metal->textures);
    free(metal->textureWidths);
    free(metal->textureHeights);
    free(metal->textureLoaded);
    free(metal->stagedTextures);
    free(metal->surfaceTextures);
    free(metal->surfaceWidth);
    free(metal->surfaceHeight);
    free(metal->surfaceAlive);
    if (gActiveMetalRenderer == metal) gActiveMetalRenderer = nil;
    free(metal);
}

static void metalBeginFrame(Renderer* renderer, int32_t gameW, int32_t gameH, int32_t windowW, int32_t windowH) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    CAMetalLayer* layer = (__bridge CAMetalLayer*)platformGetMetalLayer();
    metal->windowW = windowW;
    metal->windowH = windowH;
    metal->gameW = gameW;
    metal->gameH = gameH;

    if (layer == nil || metal->commandQueue == nil) return;
    layer.drawableSize = CGSizeMake(windowW, windowH);
    metal->drawable = [layer nextDrawable];
    metal->commandBuffer = [metal->commandQueue commandBuffer];
    if (metal->drawable == nil || metal->commandBuffer == nil) {
        logDebug("Metal: drawable acquisition skipped for frame\n");
        return;
    }

    int32_t appId = renderer->runner->applicationSurfaceId;
    if (appId >= 0 && (uint32_t)appId < metal->surfaceCount && metal->surfaceAlive[appId]) {
        metalBindSurfaceTarget(metal, appId, false, MTLClearColorMake(0, 0, 0, 1));
        metal->base.CPortX = 0;
        metal->base.CPortY = 0;
        metal->base.CPortW = gameW;
        metal->base.CPortH = gameH;
    }
}

static void metalEndFrameInit(MAYBE_UNUSED Renderer* renderer) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    // Manual application_surface draw path: leave the host clear of auto-blit.
    if (renderer->runner->usingAppSurface && !renderer->runner->appSurfaceAutoDraw) {
        metalEndEncoder(metal);
        metal->currentTarget = nil;
        metal->currentSurfaceId = -1;
    }
}

void metalSetGuiProjection(Renderer* renderer, int32_t guiW, int32_t guiH,
                           MAYBE_UNUSED int32_t portW, MAYBE_UNUSED int32_t portH,
                           bool renderingToUserSurface);

static void metalEndFrameEnd(Renderer* renderer) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (renderer->runner->usingAppSurface && !renderer->runner->appSurfaceAutoDraw) {
        return;
    }
    if (metal->commandBuffer == nil || metal->drawable == nil) return;

    int32_t appId = renderer->runner->applicationSurfaceId;
    if (appId < 0 || (uint32_t)appId >= metal->surfaceCount || !metal->surfaceAlive[appId]) return;

    metalEndEncoder(metal);

    // Present pass: clear drawable, letterbox-blit application_surface.
    MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = metal->drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    metal->encoder = [metal->commandBuffer renderCommandEncoderWithDescriptor:pass];
    metal->currentTarget = metal->drawable.texture;
    metal->encoderTarget = metal->drawable.texture;
    metal->currentSurfaceId = -1;

    [metal->encoder setViewport:(MTLViewport){0, 0, (double)metal->windowW, (double)metal->windowH, 0, 1}];
    [metal->encoder setScissorRect:(MTLScissorRect){0, 0, (NSUInteger)metal->windowW, (NSUInteger)metal->windowH}];

    int32_t sx, sy, ex, ey;
    int32_t gameW = metal->gameW, gameH = metal->gameH;
    int32_t windowW = metal->windowW, windowH = metal->windowH;
    int32_t effW, effH;
    if ((gameW * windowH) / gameH < windowW) {
        effW = (gameW * windowH) / gameH;
        effH = windowH;
    } else {
        effW = windowW;
        effH = (gameH * windowW) / gameW;
    }
    sx = (windowW - effW) / 2;
    sy = (windowH - effH) / 2;
    ex = sx + effW;
    ey = sy + effH;

    Matrix4f prevWVP = renderer->gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION];
    Matrix4f_flipClipY(&prevWVP);
    int32_t prevShader = metal->base.currentShader;
    metal->base.currentShader = -1;
    metalSetGuiProjection(renderer, windowW, windowH, windowW, windowH, false);
    metalUploadDefaultUniforms(metal);

    // Present pipeline is BGRA8 to match the CAMetalLayer drawable.
    [metal->encoder setRenderPipelineState:metal->presentPipeline];
    [metal->encoder setVertexBytes:&metal->defaultUniforms length:sizeof(MetalDefaultUniforms) atIndex:1];
    [metal->encoder setFragmentBytes:&metal->defaultUniforms length:sizeof(MetalDefaultUniforms) atIndex:1];
    [metal->encoder setFragmentSamplerState:metal->nearestSampler atIndex:0];
    [metal->encoder setFragmentTexture:metal->surfaceTextures[appId] atIndex:0];

    float x0 = (float)sx, y0 = (float)sy;
    float x1 = (float)ex, y1 = (float)ey;
    MetalVertex vertices[6];
    float positions[8] = {x0, y0, x1, y0, x1, y1, x0, y1};
    float uvs[8] = {0.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f, 0.0f, 1.0f};
    const int indices[6] = {0, 1, 2, 2, 3, 0};
    Matrix4f* matrix = &renderer->gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION];
    Matrix4f_flipClipY(&matrix);
    for (int i = 0; i < 6; i++) {
        int source = indices[i];
        float clipX, clipY;
        Matrix4f_transformPoint(matrix, positions[source * 2], positions[source * 2 + 1], &clipX, &clipY);
        // Present path still transforms on CPU into clip space; zero out WVP to identity via uploading
        // already-clipped verts by using an identity WVP for this draw.
        vertices[i].position = (vector_float2){positions[source * 2], positions[source * 2 + 1]};
        vertices[i].uv = (vector_float2){uvs[source * 2], uvs[source * 2 + 1]};
        vertices[i].color = (vector_float4){1, 1, 1, 1};
        (void)clipX; (void)clipY;
    }
    // Use GPU WVP from setGuiProjection (room/window space → clip).
    [metal->encoder setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
    [metal->encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

    renderer->gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION] = prevWVP;
    metal->base.currentShader = prevShader;

    metalEndEncoder(metal);
    metal->currentTarget = nil;
}

static void metalBeginView(Renderer* renderer, MAYBE_UNUSED int32_t viewX, MAYBE_UNUSED int32_t viewY,
                           MAYBE_UNUSED int32_t viewW, MAYBE_UNUSED int32_t viewH,
                           int32_t portX, int32_t portY, int32_t portW, int32_t portH,
                           MAYBE_UNUSED float viewAngle) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    // Views always render into the application surface (or its current binding).
    int32_t appId = renderer->runner->applicationSurfaceId;
    if (appId >= 0 && (metal->currentSurfaceId != appId || metal->encoderTarget == nil ||
                       metal->encoderTarget != metal->surfaceTextures[appId])) {
        metalBindSurfaceTarget(metal, appId, false, MTLClearColorMake(0, 0, 0, 1));
    } else {
        metalEnsureEncoder(metal, false, MTLClearColorMake(0, 0, 0, 1));
    }
    renderer->CPortX = portX;
    renderer->CPortY = portY;
    renderer->CPortW = portW;
    renderer->CPortH = portH;
    metalApplyViewportScissor(metal, portX, portY, portW, portH, true);

    int32_t viewCurrent = renderer->runner->viewsEnabled ? renderer->runner->viewCurrent : 0;
    RuntimeView* view = &renderer->runner->views[viewCurrent];
    renderer->cameraCurrent = view->cameraId;
    GMLCamera* camera = Runner_getCameraById(renderer->runner, renderer->cameraCurrent);
    metalApplyProjection(renderer, &camera->viewMatrix, &camera->projectionMatrix);
}

static void metalEndView(MAYBE_UNUSED Renderer* renderer) {}

void metalSetGuiProjection(Renderer* renderer, int32_t guiW, int32_t guiH,
                           MAYBE_UNUSED int32_t portW, MAYBE_UNUSED int32_t portH,
                           bool renderingToUserSurface) {
    renderer->cameraCurrent = GUI_CAMERA;
    GMLCamera* camera = &renderer->runner->guiCamera;
    camera->allocated = true;
    camera->viewX = 0.0;
    camera->viewY = 0.0;
    camera->viewWidth = guiW;
    camera->viewHeight = guiH;
    camera->borderX = 0;
    camera->borderY = 0;
    camera->speedX = 0;
    camera->speedY = 0;
    camera->objectId = -1;
    camera->viewAngle = 0;

    Matrix4f projection;
    Matrix4f_Orthographic(&projection, (float)guiW, (float)guiH, 32000.0, 0.0);
    Matrix4f_flipClipY(&projection);
    //if (renderingToUserSurface) //Matrix4f_flipClipY(&projection);
    Matrix4f view;
    Matrix4f_identity(&view);
    Matrix4f_LookAt(&view, (float)guiW * 0.5f, (float)guiH * 0.5f, -16000.0,
                    (float)guiW * 0.5f, (float)guiH * 0.5f, 16000.0,
                    0.0, 1.0, 0.0);
    camera->viewMatrix = view;
    camera->projectionMatrix = projection;
    metalApplyProjection(renderer, &view, &projection);
}

static void metalBeginGUI(Renderer* renderer, int32_t guiW, int32_t guiH,
                          int32_t portX, int32_t portY, int32_t portW, int32_t portH,
                          int32_t targetSurfaceId) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    bool renderingToUserSurface = false;

    if (targetSurfaceId == RENDER_TARGET_HOST_FRAMEBUFFER) {
        // Rare: draw GUI straight to drawable.
        metalEndEncoder(metal);
        if (metal->drawable != nil) {
            MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
            pass.colorAttachments[0].texture = metal->drawable.texture;
            pass.colorAttachments[0].loadAction = MTLLoadActionLoad;
            pass.colorAttachments[0].storeAction = MTLStoreActionStore;
            metal->encoder = [metal->commandBuffer renderCommandEncoderWithDescriptor:pass];
            metal->currentTarget = metal->drawable.texture;
            metal->encoderTarget = metal->drawable.texture;
            metal->currentSurfaceId = -1;
        }
    } else if (targetSurfaceId >= 0) {
        renderingToUserSurface = (targetSurfaceId != renderer->runner->applicationSurfaceId);
        metalBindSurfaceTarget(metal, targetSurfaceId, false, MTLClearColorMake(0, 0, 0, 1));
    }

    metalEnsureEncoder(metal, false, MTLClearColorMake(0, 0, 0, 1));
    metalApplyViewportScissor(metal, portX, portY, portW, portH, true);
    metalSetGuiProjection(renderer, guiW, guiH, portW, portH, renderingToUserSurface);
}

static void metalEndGUI(Renderer* renderer) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    (void)metal;
}

static void metalFlush(MAYBE_UNUSED Renderer* renderer) {}

static RendererVtable metalVtable = {
    .init = metalInit,
    .destroy = metalDestroy,
    .beginFrame = metalBeginFrame,
    .endFrameInit = metalEndFrameInit,
    .endFrameEnd = metalEndFrameEnd,
    .beginView = metalBeginView,
    .endView = metalEndView,
    .applyProjection = metalApplyProjection,
    .beginGUI = metalBeginGUI,
    .setGuiProjection = metalSetGuiProjection,
    .endGUI = metalEndGUI,
    .drawSprite = metalDrawSprite,
    .drawSpritePart = metalDrawSpritePart,
    .drawSpritePos = metalDrawSpritePos,
    .drawRectangle = metalDrawRectangle,
    .drawRectangleColor = metalDrawRectangleColor,
    .drawLine = metalDrawLine,
    .drawTriangle = metalDrawTriangle,
    .drawLineColor = metalDrawLineColor,
    .drawText = metalDrawText,
    .drawTextColor = metalDrawTextColor,
    .flush = metalFlush,
    .clearScreen = metalClearScreen,
    .createSpriteFromSurface = metalCreateSpriteFromSurface,
    .deleteSprite = metalDeleteSprite,
    .gpuGetBlendFactors = metalGpuGetBlendFactors,
    .gpuGetBlendMode = metalGpuGetBlendMode,
    .gpuSetBlendMode = metalGpuSetBlendMode,
    .gpuSetBlendModeExt = metalGpuSetBlendModeExt,
    .gpuSetBlendEnable = metalGpuSetBlendEnable,
    .gpuSetAlphaTestEnable = metalGpuSetAlphaTestEnable,
    .gpuSetAlphaTestRef = metalGpuSetAlphaTestRef,
    .gpuSetColorWriteEnable = metalGpuSetColorWriteEnable,
    .gpuGetColorWriteEnable = metalGpuGetColorWriteEnable,
    .gpuGetBlendEnable = metalGpuGetBlendEnable,
    .gpuSetFog = metalGpuSetFog,
    .drawTile = nullptr,
    .drawSpriteTiled = metalDrawSpriteTiled,
    .drawSurfaceTiled = metalDrawSurfaceTiled,
    .createSurface = metalCreateSurface,
    .surfaceExists = metalSurfaceExists,
    .setRenderTarget = metalSetRenderTarget,
    .ensureApplicationSurface = metalEnsureApplicationSurface,
    .getSurfaceWidth = metalGetSurfaceWidth,
    .getSurfaceHeight = metalGetSurfaceHeight,
    .drawSurface = metalDrawSurface,
    .drawSurfaceColor = metalDrawSurfaceColor,
    .surfaceResize = metalSurfaceResize,
    .surfaceFree = metalSurfaceFree,
    .surfaceCopy = metalSurfaceCopy,
    .surfaceGetPixels = metalSurfaceGetPixels,
    .drawTiledPart = metalDrawTiledPart,
    .gpuSetShader = metalGpuSetShader,
    .gpuResetShader = metalGpuResetShader,
    .shaderGetUniform = metalShaderGetUniform,
    .shaderGetSamplerIndex = metalShaderGetSamplerIndex,
    .shaderSetUniformF = metalShaderSetUniformF,
    .shaderSetUniformFArray = metalShaderSetUniformFArray,
    .shaderSetUniformI = metalShaderSetUniformI,
    .spriteGetTexture = metalSpriteGetTexture,
    .surfaceGetTexture = metalSurfaceGetTexture,
    .textureGetTexelWidth = metalTextureGetTexelWidth,
    .textureGetTexelHeight = metalTextureGetTexelHeight,
    .textureGetUVs = metalTextureGetUVs,
    .textureSetStage = metalTextureSetStage,
    .shaderIsCompiled = metalShaderIsCompiled,
    .shadersSupported = metalShadersSupported,
    .setMatrix = metalSetMatrix,
    .videoUploadFrame = metalVideoUploadFrame,
};

Renderer* MetalRenderer_create(void) {
    MetalRenderer* metal = (MetalRenderer*)safeCalloc(1, sizeof(MetalRenderer));
    metal->base.vtable = &metalVtable;
    metal->base.drawColor = 0xFFFFFF;
    metal->base.drawAlpha = 1.0f;
    metal->base.drawFont = -1;
    metal->base.drawHalign = 0;
    metal->base.drawValign = 0;
    metal->base.circlePrecision = 24;
    metal->base.currentShader = -1;
    gActiveMetalRenderer = metal;
    return &metal->base;
}

void MetalRenderer_presentFrame(void) {
    MetalRenderer* metal = gActiveMetalRenderer;
    if (metal == nil || metal->commandBuffer == nil || metal->drawable == nil) return;
    metalEndEncoder(metal);
    [metal->commandBuffer presentDrawable:metal->drawable];
    [metal->commandBuffer commit];
    metal->presentedCommandBuffer = metal->commandBuffer;
    metal->commandBuffer = nil;
    metal->drawable = nil;
    metal->currentTarget = nil;
    metal->currentSurfaceId = -1;
}

void MetalRenderer_waitForPresentedFrame(void) {
    if (gActiveMetalRenderer != nil && gActiveMetalRenderer->presentedCommandBuffer != nil) {
        [gActiveMetalRenderer->presentedCommandBuffer waitUntilCompleted];
        gActiveMetalRenderer->presentedCommandBuffer = nil;
    }
}
