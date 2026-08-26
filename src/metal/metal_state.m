#import "metal_internal.h"

void metalApplyProjection(Renderer* renderer, const Matrix4f* viewMatrix, const Matrix4f* projectionMatrix) {
    Matrix4f world = renderer->gmlMatrices[MATRIX_WORLD];
    Matrix4f worldView;
    Matrix4f worldViewProjection;
    Matrix4f_multiply(&worldView, viewMatrix, &world);
    Matrix4f_multiply(&worldViewProjection, projectionMatrix, &worldView);
    renderer->gmlMatrices[MATRIX_VIEW] = *viewMatrix;
    renderer->gmlMatrices[MATRIX_PROJECTION] = *projectionMatrix;
    renderer->gmlMatrices[MATRIX_WORLD_VIEW] = worldView;
    renderer->gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION] = worldViewProjection;
}

void metalSetMatrix(Renderer* renderer, int32_t matrixType, Matrix4f matrix) {
    renderer->gmlMatrices[matrixType] = matrix;
    Matrix4f world = renderer->gmlMatrices[MATRIX_WORLD];
    Matrix4f view = renderer->gmlMatrices[MATRIX_VIEW];
    Matrix4f projection = renderer->gmlMatrices[MATRIX_PROJECTION];
    Matrix4f worldView;
    Matrix4f_multiply(&worldView, &view, &world);
    Matrix4f worldViewProjection;
    Matrix4f_multiply(&worldViewProjection, &projection, &worldView);
    renderer->gmlMatrices[MATRIX_WORLD_VIEW] = worldView;
    renderer->gmlMatrices[MATRIX_WORLD_VIEW_PROJECTION] = worldViewProjection;
}

BlendFactors metalGpuGetBlendFactors(Renderer* renderer) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    BlendFactors ret;
    ret.src = metal->currentSFactor;
    ret.dst = metal->currentDFactor;
    ret.srcAlpha = metal->currentSFactorAlpha;
    ret.dstAlpha = metal->currentDFactorAlpha;
    return ret;
}

int32_t metalGpuGetBlendMode(Renderer* renderer) {
    return ((MetalRenderer*)renderer)->currentBlendMode;
}

void metalGpuSetBlendMode(Renderer* renderer, int32_t mode) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (mode == metal->currentBlendMode) return;
    metal->currentBlendMode = mode;
    // Map via the same tables as GL (store bm_* constants, not GL enums).
    switch (mode) {
        case bm_add:
            metal->currentSFactor = bm_src_alpha;
            metal->currentDFactor = bm_one;
            break;
        case bm_subtract:
            metal->currentSFactor = bm_zero;
            metal->currentDFactor = bm_inv_src_color;
            break;
        case bm_reverse_subtract:
            metal->currentSFactor = bm_src_alpha;
            metal->currentDFactor = bm_one;
            break;
        case bm_min:
            metal->currentSFactor = bm_one;
            metal->currentDFactor = bm_one;
            break;
        case bm_max:
            metal->currentSFactor = bm_src_alpha;
            metal->currentDFactor = bm_inv_src_alpha;
            break;
        default:
            metal->currentSFactor = bm_src_alpha;
            metal->currentDFactor = bm_inv_src_alpha;
            break;
    }
    metal->currentSFactorAlpha = metal->currentSFactor;
    metal->currentDFactorAlpha = metal->currentDFactor;
}

void metalGpuSetBlendModeExt(Renderer* renderer, int32_t sfactor, int32_t dfactor,
                             int32_t sfactor_alpha, int32_t dfactor_alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    metal->currentBlendMode = bm_complex;
    metal->currentSFactor = sfactor;
    metal->currentDFactor = dfactor;
    metal->currentSFactorAlpha = sfactor_alpha;
    metal->currentDFactorAlpha = dfactor_alpha;
}

void metalGpuSetBlendEnable(Renderer* renderer, bool enable) {
    ((MetalRenderer*)renderer)->blendEnabled = enable;
}

bool metalGpuGetBlendEnable(Renderer* renderer) {
    return ((MetalRenderer*)renderer)->blendEnabled;
}

void metalGpuSetAlphaTestEnable(Renderer* renderer, bool enable) {
    ((MetalRenderer*)renderer)->alphaTestEnable = enable;
}

void metalGpuSetAlphaTestRef(Renderer* renderer, uint8_t ref) {
    ((MetalRenderer*)renderer)->alphaTestRef = ref / 255.0f;
}

void metalGpuSetColorWriteEnable(Renderer* renderer, bool red, bool green, bool blue, bool alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    metal->colorWriteR = red;
    metal->colorWriteG = green;
    metal->colorWriteB = blue;
    metal->colorWriteA = alpha;
}

void metalGpuGetColorWriteEnable(Renderer* renderer, bool* red, bool* green, bool* blue, bool* alpha) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    *red = metal->colorWriteR;
    *green = metal->colorWriteG;
    *blue = metal->colorWriteB;
    *alpha = metal->colorWriteA;
}

void metalGpuSetFog(Renderer* renderer, bool enable, uint32_t color) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    metal->fogEnable = enable;
    metal->fogColor = color;

    logInfo("METAL gpuSetFog: enable=%d color=%08x\n",
            enable, color);

}

bool metalResolveTextureHandle(MetalRenderer* metal, uint32_t texHandle, TexturePageItem** outTpag,
                               id<MTLTexture>* outTex, int32_t* outW, int32_t* outH) {
    if (texHandle == 0) return false;
    if (texHandle & METAL_SURFACE_TEXTURE_FLAG) {
        uint32_t sid = texHandle & ~METAL_SURFACE_TEXTURE_FLAG;
        if (sid >= metal->surfaceCount || !metal->surfaceAlive[sid]) return false;
        if (outTpag) *outTpag = nullptr;
        *outTex = metal->surfaceTextures[sid];
        *outW = metal->surfaceWidth[sid];
        *outH = metal->surfaceHeight[sid];
        return true;
    }
    int32_t tpagIndex = (int32_t)texHandle - 1;
    TexturePageItem* tpag;
    uint32_t pageId;
    if (!metalResolveTpag(metal, tpagIndex, &tpag, &pageId) || !metalEnsureTextureLoaded(metal, pageId))
        return false;
    if (outTpag) *outTpag = tpag;
    *outTex = metal->textures[pageId];
    *outW = metal->textureWidths[pageId];
    *outH = metal->textureHeights[pageId];
    return true;
}

uint32_t metalSpriteGetTexture(Renderer* renderer, int32_t tpagIndex) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    TexturePageItem* tpag;
    uint32_t pageId;
    if (!metalResolveTpag(metal, tpagIndex, &tpag, &pageId)) return 0;
    return (uint32_t)(tpagIndex + 1);
}

float metalTextureGetTexelWidth(Renderer* renderer, uint32_t texHandle) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    TexturePageItem* tpag;
    id<MTLTexture> tex;
    int32_t w = 0, h = 0;
    if (!metalResolveTextureHandle(metal, texHandle, &tpag, &tex, &w, &h) || w <= 0) return 1.0f;
    return 1.0f / (float)w;
}

float metalTextureGetTexelHeight(Renderer* renderer, uint32_t texHandle) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    TexturePageItem* tpag;
    id<MTLTexture> tex;
    int32_t w = 0, h = 0;
    if (!metalResolveTextureHandle(metal, texHandle, &tpag, &tex, &w, &h) || h <= 0) return 1.0f;
    return 1.0f / (float)h;
}

bool metalTextureGetUVs(Renderer* renderer, uint32_t texHandle, float* outUVs) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    TexturePageItem* tpag;
    id<MTLTexture> tex;
    int32_t w = 0, h = 0;
    if (!metalResolveTextureHandle(metal, texHandle, &tpag, &tex, &w, &h) || w <= 0 || h <= 0) return false;
    if (tpag == nullptr) {
        outUVs[0] = 0.0f; outUVs[1] = 0.0f; outUVs[2] = 1.0f; outUVs[3] = 1.0f;
        return true;
    }
    float divW = 1.0f / (float)w;
    float divH = 1.0f / (float)h;
    outUVs[0] = (float)tpag->sourceX * divW;
    outUVs[1] = (float)tpag->sourceY * divH;
    outUVs[2] = outUVs[0] + (float)tpag->sourceWidth * divW;
    outUVs[3] = outUVs[1] + (float)tpag->sourceHeight * divH;
    return true;
}

void metalTextureSetStage(Renderer* renderer, int32_t slot, uint32_t texHandle) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (slot < 0 || slot >= MAX_TEXTURE_STAGES) return;
    metal->stagedTextures[slot] = nil;
    TexturePageItem* tpag;
    id<MTLTexture> tex = nil;
    int32_t w, h;
    if (metalResolveTextureHandle(metal, texHandle, &tpag, &tex, &w, &h))
        metal->stagedTextures[slot] = tex;
}

void metalGpuSetShader(Renderer* renderer, int32_t shaderIndex) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (shaderIndex < 0 || (uint32_t)shaderIndex >= metal->gmlShaderCount) {
        renderer->currentShader = -1;
        return;
    }
    if (!metal->gmlShaders[shaderIndex].compiled) {
        renderer->currentShader = -1;
        return;
    }
    renderer->currentShader = shaderIndex;
    metalRefreshShaderBuiltins(metal);
}

void metalGpuResetShader(Renderer* renderer) {
    renderer->currentShader = -1;
}

int32_t metalShaderGetUniform(Renderer* renderer, int32_t shaderIndex, char* uniform) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    int32_t target = (shaderIndex != -1) ? shaderIndex : renderer->currentShader;
    if (target < 0 || (uint32_t)target >= metal->gmlShaderCount) return -1;
    MetalGMLShader* shader = &metal->gmlShaders[target];
    if (!shader->compiled) return -1;

    for (uint32_t i = 0; i < shader->uniformCount; i++) {
        if (strcmp(shader->uniforms[i].name, uniform) == 0)
            return shader->uniforms[i].location;
        // Allow looking up array base as name[0]
        char arrayName[256];
        snprintf(arrayName, sizeof(arrayName), "%s[0]", uniform);
        if (strcmp(shader->uniforms[i].name, arrayName) == 0 || strcmp(shader->uniforms[i].name, uniform) == 0)
            return shader->uniforms[i].location;
    }
    return -1;
}

int32_t metalShaderGetSamplerIndex(Renderer* renderer, int32_t shaderIndex, char* uniform) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (shaderIndex < 0 || (uint32_t)shaderIndex >= metal->gmlShaderCount) return -1;
    MetalGMLShader* shader = &metal->gmlShaders[shaderIndex];
    for (uint32_t i = 0; i < shader->uniformCount; i++) {
        if (shader->uniforms[i].type == METAL_UNIFORM_SAMPLER &&
            strcmp(shader->uniforms[i].name, uniform) == 0) {
            return (int32_t)shader->uniforms[i].samplerSlot;
        }
    }
    // Shader may have failed to transpile/compile — still reserve a stable slot so
    // texture_set_stage calls don't all collide on stage 0.
    if (shader->compiled) {
        logWarn("Metal: Sampler Index %s not found for shader %d\n", uniform, shaderIndex);
    }
    return -1;
}

static MetalShaderUniform* metalFindUniformByLocation(MetalGMLShader* shader, int32_t location) {
    for (uint32_t i = 0; i < shader->uniformCount; i++) {
        if (shader->uniforms[i].location == location && shader->uniforms[i].type != METAL_UNIFORM_SAMPLER)
            return &shader->uniforms[i];
    }
    return nullptr;
}

void metalShaderSetUniformF(Renderer* renderer, int32_t handle, int32_t count,
                            float value1, float value2, float value3, float value4) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (handle < 0 || renderer->currentShader < 0) return;
    MetalGMLShader* shader = &metal->gmlShaders[renderer->currentShader];
    MetalShaderUniform* uniform = metalFindUniformByLocation(shader, handle);
    if (uniform == nullptr || shader->uniformData == nullptr) return;
    float values[4] = {value1, value2, value3, value4};
    uint32_t n = (count <= 0) ? uniform->floatCount : (uint32_t)count;
    if (n > 4) n = 4;
    if (n > uniform->floatCount) n = uniform->floatCount;
    memcpy(shader->uniformData + handle, values, n * sizeof(float));
}

void metalShaderSetUniformFArray(Renderer* renderer, int32_t handle, float* values, uint32_t count) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (handle < 0 || renderer->currentShader < 0 || values == nullptr || count == 0) return;
    MetalGMLShader* shader = &metal->gmlShaders[renderer->currentShader];
    if (shader->uniformData == nullptr) return;
    MetalShaderUniform* uniform = metalFindUniformByLocation(shader, handle);
    uint32_t n = count;
    if (uniform != nullptr && n > uniform->floatCount) n = uniform->floatCount;
    if ((uint32_t)handle + n > shader->uniformFloatCount) n = shader->uniformFloatCount - (uint32_t)handle;
    memcpy(shader->uniformData + handle, values, n * sizeof(float));
}

void metalShaderSetUniformI(Renderer* renderer, int32_t handle, int32_t count,
                            int32_t value1, int32_t value2, int32_t value3, int32_t value4) {
    metalShaderSetUniformF(renderer, handle, count, (float)value1, (float)value2, (float)value3, (float)value4);
}

bool metalShaderIsCompiled(Renderer* renderer, int32_t shader) {
    MetalRenderer* metal = (MetalRenderer*)renderer;
    if (shader < 0 || (uint32_t)shader >= metal->gmlShaderCount) return false;
    return metal->gmlShaders[shader].compiled;
}

bool metalShadersSupported(void) {
    return true;
}

void metalRefreshShaderBuiltins(MetalRenderer* metal) {
    if (metal->base.currentShader < 0) return;
    MetalGMLShader* shader = &metal->gmlShaders[metal->base.currentShader];
    if (!shader->compiled || shader->uniformData == nullptr) return;

    if (shader->gmMatrices != nullptr) {
        Matrix4f flipped[MATRICES_MAX];
        memcpy(flipped, metal->base.gmlMatrices, sizeof(flipped));
        Matrix4f_flipClipY(&flipped[MATRIX_PROJECTION]);
        Matrix4f_flipClipY(&flipped[MATRIX_WORLD_VIEW_PROJECTION]);
        memcpy(shader->uniformData + shader->gmMatrices->location, flipped[0].m,
               MATRICES_MAX * 16 * sizeof(float));
    }
    if (shader->gmFogColour != nullptr) {
        float fog[4] = {
            BGR_R(metal->fogColor) / 255.0f,
            BGR_G(metal->fogColor) / 255.0f,
            BGR_B(metal->fogColor) / 255.0f,
            metal->fogEnable ? 1.0f : 0.0f
        };
        memcpy(shader->uniformData + shader->gmFogColour->location, fog, sizeof(fog));
    }
    if (shader->gmAlphaTestEnabled != nullptr) {
        float enabled = metal->alphaTestEnable ? 1.0f : 0.0f;
        shader->uniformData[shader->gmAlphaTestEnabled->location] = enabled;
    }
    if (shader->gmAlphaRefValue != nullptr) {
        shader->uniformData[shader->gmAlphaRefValue->location] = metal->alphaTestRef;
    }
}
