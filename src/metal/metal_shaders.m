#import "metal_internal.h"
#include <ctype.h>
#include <stdarg.h>

typedef struct {
    char* name;
    MetalUniformType type;
    uint32_t arraySize;
    uint32_t floatCount;
    bool isSampler;
} MetalParsedUniform;

static MetalUniformType metalParseUniformType(const char* typeName) {
    if (strcmp(typeName, "float") == 0) return METAL_UNIFORM_FLOAT;
    if (strcmp(typeName, "vec2") == 0) return METAL_UNIFORM_FLOAT2;
    if (strcmp(typeName, "vec3") == 0) return METAL_UNIFORM_FLOAT3;
    if (strcmp(typeName, "vec4") == 0) return METAL_UNIFORM_FLOAT4;
    if (strcmp(typeName, "int") == 0) return METAL_UNIFORM_INT;
    if (strcmp(typeName, "ivec2") == 0) return METAL_UNIFORM_INT2;
    if (strcmp(typeName, "ivec3") == 0) return METAL_UNIFORM_INT3;
    if (strcmp(typeName, "ivec4") == 0) return METAL_UNIFORM_INT4;
    if (strcmp(typeName, "mat2") == 0) return METAL_UNIFORM_MAT2;
    if (strcmp(typeName, "mat3") == 0) return METAL_UNIFORM_MAT3;
    if (strcmp(typeName, "mat4") == 0) return METAL_UNIFORM_MAT4;
    if (strcmp(typeName, "bool") == 0) return METAL_UNIFORM_BOOL;
    if (strcmp(typeName, "sampler2D") == 0) return METAL_UNIFORM_SAMPLER;
    return METAL_UNIFORM_UNKNOWN;
}

static uint32_t metalUniformFloatCount(MetalUniformType type, uint32_t arraySize) {
    uint32_t per = 1;
    switch (type) {
        case METAL_UNIFORM_FLOAT:
        case METAL_UNIFORM_INT:
        case METAL_UNIFORM_BOOL: per = 1; break;
        case METAL_UNIFORM_FLOAT2:
        case METAL_UNIFORM_INT2: per = 2; break;
        case METAL_UNIFORM_FLOAT3:
        case METAL_UNIFORM_INT3: per = 3; break;
        case METAL_UNIFORM_FLOAT4:
        case METAL_UNIFORM_INT4: per = 4; break;
        case METAL_UNIFORM_MAT2: per = 4; break;
        case METAL_UNIFORM_MAT3: per = 9; break;
        case METAL_UNIFORM_MAT4: per = 16; break;
        default: per = 1; break;
    }
    return per * (arraySize == 0 ? 1 : arraySize);
}

static void metalAppend(char** out, size_t* len, size_t* cap, const char* text) {
    size_t add = strlen(text);
    if (*len + add + 1 > *cap) {
        *cap = (*len + add + 1) * 2;
        *out = (char*)safeRealloc(*out, *cap);
    }
    memcpy(*out + *len, text, add);
    *len += add;
    (*out)[*len] = 0;
}

static void metalAppendf(char** out, size_t* len, size_t* cap, const char* fmt, ...) {
    char buf[2048];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    metalAppend(out, len, cap, buf);
}

static bool metalIsIdentChar(char c) {
    return isalnum((unsigned char)c) || c == '_';
}

static void metalSkipWs(const char** p) {
    while (**p && isspace((unsigned char)**p)) (*p)++;
}

static bool metalMatchKeyword(const char** p, const char* lit) {
    size_t n = strlen(lit);
    if (strncmp(*p, lit, n) != 0) return false;
    if (metalIsIdentChar((*p)[n])) return false;
    *p += n;
    return true;
}

static bool metalMatch(const char** p, const char* lit) {
    size_t n = strlen(lit);
    if (strncmp(*p, lit, n) == 0) {
        *p += n;
        return true;
    }
    return false;
}

static char* metalDupRange(const char* start, const char* end) {
    size_t n = (size_t)(end - start);
    char* s = (char*)safeMalloc(n + 1);
    memcpy(s, start, n);
    s[n] = 0;
    return s;
}

static char* metalDupStr(const char* s) {
    return metalDupRange(s, s + strlen(s));
}

static void metalCollectUniforms(const char* src, MetalParsedUniform** uniforms, uint32_t* count) {
    const char* p = src;
    while (*p) {
        if (p[0] == '/' && p[1] == '/') {
            while (*p && *p != '\n') p++;
            continue;
        }
        if (p[0] == '/' && p[1] == '*') {
            p += 2;
            while (*p && !(p[0] == '*' && p[1] == '/')) p++;
            if (*p) p += 2;
            continue;
        }
        if (metalMatchKeyword(&p, "uniform")) {
            metalSkipWs(&p);
            const char* typeStart = p;
            while (*p && metalIsIdentChar(*p)) p++;
            char* typeName = metalDupRange(typeStart, p);
            metalSkipWs(&p);
            if (strcmp(typeName, "lowp") == 0 || strcmp(typeName, "mediump") == 0 || strcmp(typeName, "highp") == 0) {
                free(typeName);
                typeStart = p;
                while (*p && metalIsIdentChar(*p)) p++;
                typeName = metalDupRange(typeStart, p);
                metalSkipWs(&p);
            }
            const char* nameStart = p;
            while (*p && metalIsIdentChar(*p)) p++;
            char* name = metalDupRange(nameStart, p);
            uint32_t arraySize = 1;
            metalSkipWs(&p);
            if (*p == '[') {
                p++;
                arraySize = (uint32_t)strtoul(p, (char**)&p, 10);
                while (*p && *p != ']') p++;
                if (*p == ']') p++;
            }
            MetalUniformType type = metalParseUniformType(typeName);
            if (type != METAL_UNIFORM_UNKNOWN && name[0] != 0) {
                bool exists = false;
                for (uint32_t i = 0; i < *count; i++) {
                    if (strcmp((*uniforms)[i].name, name) == 0) { exists = true; break; }
                }
                if (!exists) {
                    *uniforms = (MetalParsedUniform*)safeRealloc(*uniforms, (*count + 1) * sizeof(MetalParsedUniform));
                    (*uniforms)[*count].name = name;
                    (*uniforms)[*count].type = type;
                    (*uniforms)[*count].arraySize = arraySize == 0 ? 1 : arraySize;
                    (*uniforms)[*count].isSampler = (type == METAL_UNIFORM_SAMPLER);
                    (*uniforms)[*count].floatCount = type == METAL_UNIFORM_SAMPLER ? 0 :
                        metalUniformFloatCount(type, (*uniforms)[*count].arraySize);
                    (*count)++;
                    name = nullptr;
                }
            }
            free(typeName);
            free(name);
            continue;
        }
        p++;
    }
}

static char* metalExtractMainBody(const char* src) {
    const char* mainPos = strstr(src, "main");
    if (mainPos == nullptr) return metalDupStr("");
    const char* brace = strchr(mainPos, '{');
    if (brace == nullptr) return metalDupStr("");
    int depth = 0;
    const char* p = brace;
    do {
        if (*p == '{') depth++;
        else if (*p == '}') depth--;
        p++;
    } while (*p && depth > 0);
    // Exclude outer braces.
    if (p > brace + 1)
        return metalDupRange(brace + 1, p - 1);
    return metalDupStr("");
}

static char* metalReplaceIdentToken(const char* src, const char* token, const char* repl) {
    size_t tokenLen = strlen(token);
    size_t replLen = strlen(repl);
    size_t cap = strlen(src) * 2 + replLen + 64;
    char* out = (char*)safeCalloc(1, cap);
    size_t len = 0;
    const char* p = src;

    while (*p) {
        if (strncmp(p, token, tokenLen) == 0 &&
            (p == src || !metalIsIdentChar(p[-1])) &&
            !metalIsIdentChar(p[tokenLen])) {
            if (len + replLen + 1 > cap) {
                cap = (len + replLen + 1) * 2;
                out = (char*)safeRealloc(out, cap);
            }
            memcpy(out + len, repl, replLen);
            len += replLen;
            p += tokenLen;
            continue;
        }
        if (len + 2 > cap) {
            cap *= 2;
            out = (char*)safeRealloc(out, cap);
        }
        out[len++] = *p++;
    }
    out[len] = 0;
    return out;
}

static char* metalConvertGlslTypes(const char* src) {
    // Longer tokens first to avoid partial replacements.
    static const struct { const char* from; const char* to; } kMap[] = {
        {"ivec4", "int4"}, {"ivec3", "int3"}, {"ivec2", "int2"},
        {"bvec4", "bool4"}, {"bvec3", "bool3"}, {"bvec2", "bool2"},
        {"uvec4", "uint4"}, {"uvec3", "uint3"}, {"uvec2", "uint2"},
        {"vec4", "float4"}, {"vec3", "float3"}, {"vec2", "float2"},
        {"mat4", "float4x4"}, {"mat3", "float3x3"}, {"mat2", "float2x2"},
    };
    char* cur = metalDupStr(src);
    for (uint32_t i = 0; i < sizeof(kMap) / sizeof(kMap[0]); i++) {
        char* next = metalReplaceIdentToken(cur, kMap[i].from, kMap[i].to);
        free(cur);
        cur = next;
    }
    return cur;
}

static char* metalPostProcessGlslBody(const char* body, bool isVertex) {
    const char* uvRepl = isVertex ? "vout.uv" : "fin.uv";
    const char* colRepl = isVertex ? "vout.color" : "fin.color";

    char* s = metalDupStr(body);
    char* step;

    step = metalReplaceIdentToken(s, "v_vTexcoord", uvRepl); free(s); s = step;
    step = metalReplaceIdentToken(s, "v_vTexCoord", uvRepl); free(s); s = step;
    step = metalReplaceIdentToken(s, "v_vTexCoord0", uvRepl); free(s); s = step;
    step = metalReplaceIdentToken(s, "vTexCoord", uvRepl); free(s); s = step;
    step = metalReplaceIdentToken(s, "v_vColour", colRepl); free(s); s = step;
    step = metalReplaceIdentToken(s, "v_vColor", colRepl); free(s); s = step;
    step = metalReplaceIdentToken(s, "vColour", colRepl); free(s); s = step;
    step = metalReplaceIdentToken(s, "vColor", colRepl); free(s); s = step;
    step = metalReplaceIdentToken(s, "gl_FragColor", "_mtl_fragColor"); free(s); s = step;
    step = metalReplaceIdentToken(s, "gl_FragData", "_mtl_fragColor"); free(s); s = step;

    step = metalConvertGlslTypes(s);
    free(s);
    return step;
}

static char* metalRewriteMainBody(const char* body, bool isVertex,
                                  MetalShaderUniform* uniforms, uint32_t uniformCount) {
    size_t cap = strlen(body) * 3 + 256;
    char* out = (char*)safeCalloc(1, cap);
    size_t len = 0;
    const char* p = body;

    while (*p) {
        if (p[0] == '/' && p[1] == '/') {
            while (*p && *p != '\n') {
                char ch[2] = {*p++, 0};
                metalAppend(&out, &len, &cap, ch);
            }
            continue;
        }
        if (p[0] == '/' && p[1] == '*') {
            while (*p && !(p[0] == '*' && p[1] == '/')) {
                char ch[2] = {*p++, 0};
                metalAppend(&out, &len, &cap, ch);
            }
            if (*p) { metalAppend(&out, &len, &cap, "*/"); p += 2; }
            continue;
        }

        if (metalMatch(&p, "texture2D")) {
            metalSkipWs(&p);
            if (*p != '(') { metalAppend(&out, &len, &cap, "texture2D"); continue; }
            p++;
            metalSkipWs(&p);
            const char* sampStart = p;
            while (*p && metalIsIdentChar(*p)) p++;
            char* samp = metalDupRange(sampStart, p);
            metalSkipWs(&p);
            if (*p == ',') p++;
            metalSkipWs(&p);
            int depth = 1;
            const char* uvStart = p;
            while (*p && depth > 0) {
                if (*p == '(') depth++;
                else if (*p == ')') {
                    depth--;
                    if (depth == 0) break;
                }
                p++;
            }
            char* uv = metalDupRange(uvStart, p);
            if (*p == ')') p++;
            metalAppendf(&out, &len, &cap, "%s.sample(_samp_%s, %s)", samp, samp, uv);
            free(samp);
            free(uv);
            continue;
        }

        if (metalMatchKeyword(&p, "gl_Position")) { metalAppend(&out, &len, &cap, "_mtl_position"); continue; }
        if (metalMatchKeyword(&p, "gl_FragColor")) { metalAppend(&out, &len, &cap, "_mtl_fragColor"); continue; }
        if (metalMatchKeyword(&p, "discard")) { metalAppend(&out, &len, &cap, "discard_fragment()"); continue; }

        if (metalMatchKeyword(&p, "in_Position")) { metalAppend(&out, &len, &cap, "vin.position"); continue; }
        if (metalMatchKeyword(&p, "in_Colour") || metalMatchKeyword(&p, "in_Color")) {
            metalAppend(&out, &len, &cap, "vin.color"); continue;
        }
        if (metalMatchKeyword(&p, "in_TextureCoord")) { metalAppend(&out, &len, &cap, "vin.uv"); continue; }
        if (metalMatchKeyword(&p, "v_vTexcoord") || metalMatchKeyword(&p, "v_vTexCoord") ||
            metalMatchKeyword(&p, "vTexCoord")) {
            metalAppend(&out, &len, &cap, isVertex ? "vout.uv" : "fin.uv"); continue;
        }
        if (metalMatchKeyword(&p, "v_vColour") || metalMatchKeyword(&p, "v_vColor") ||
            metalMatchKeyword(&p, "vColor") || metalMatchKeyword(&p, "vColour")) {
            metalAppend(&out, &len, &cap, isVertex ? "vout.color" : "fin.color"); continue;
        }

        if (metalMatchKeyword(&p, "MATRIX_WORLD_VIEW_PROJECTION")) { metalAppend(&out, &len, &cap, "4"); continue; }
        if (metalMatchKeyword(&p, "MATRIX_WORLD_VIEW")) { metalAppend(&out, &len, &cap, "3"); continue; }
        if (metalMatchKeyword(&p, "MATRIX_WORLD")) { metalAppend(&out, &len, &cap, "2"); continue; }
        if (metalMatchKeyword(&p, "MATRIX_PROJECTION")) { metalAppend(&out, &len, &cap, "1"); continue; }
        if (metalMatchKeyword(&p, "MATRIX_VIEW")) { metalAppend(&out, &len, &cap, "0"); continue; }

        if (metalIsIdentChar(*p) && (p == body || !metalIsIdentChar(p[-1]))) {
            const char* start = p;
            while (*p && metalIsIdentChar(*p)) p++;
            char* ident = metalDupRange(start, p);

            bool handled = false;
            for (uint32_t i = 0; i < uniformCount; i++) {
                if (strcmp(uniforms[i].name, ident) != 0) continue;
                if (uniforms[i].type == METAL_UNIFORM_SAMPLER) {
                    metalAppend(&out, &len, &cap, ident);
                    handled = true;
                    break;
                }
                if (uniforms[i].type == METAL_UNIFORM_MAT4 && uniforms[i].arraySize > 1) {
                    metalSkipWs(&p);
                    if (*p == '[') {
                        p++;
                        const char* idxStart = p;
                        int depth = 1;
                        while (*p && depth > 0) {
                            if (*p == '[') depth++;
                            else if (*p == ']') { depth--; if (depth == 0) break; }
                            p++;
                        }
                        char* idx = metalDupRange(idxStart, p);
                        if (*p == ']') p++;
                        metalAppendf(&out, &len, &cap, "_load_mat4_from(udata, %d, (int)(%s))",
                                     uniforms[i].location, idx);
                        free(idx);
                        handled = true;
                    }
                }
                if (!handled) {
                    metalAppendf(&out, &len, &cap, "_U_%s", ident);
                    handled = true;
                }
                break;
            }
            if (!handled) metalAppend(&out, &len, &cap, ident);
            free(ident);
            continue;
        }

        char ch[2] = {*p++, 0};
        metalAppend(&out, &len, &cap, ch);
    }
    char* post = metalPostProcessGlslBody(out, isVertex);
    free(out);
    return post;
}

static void metalEmitUniformLoads(char** msl, size_t* len, size_t* cap,
                                  MetalGMLShader* meta) {
    for (uint32_t i = 0; i < meta->uniformCount; i++) {
        MetalShaderUniform* u = &meta->uniforms[i];
        if (u->type == METAL_UNIFORM_SAMPLER) continue;
        if (u->type == METAL_UNIFORM_MAT4 && u->arraySize > 1) continue; // loaded via _load_mat4_from
        int32_t loc = u->location;
        switch (u->type) {
            case METAL_UNIFORM_FLOAT:
            case METAL_UNIFORM_BOOL:
            case METAL_UNIFORM_INT:
                metalAppendf(msl, len, cap, "    float _U_%s = udata[%d];\n", u->name, loc);
                break;
            case METAL_UNIFORM_FLOAT2:
            case METAL_UNIFORM_INT2:
                metalAppendf(msl, len, cap, "    float2 _U_%s = float2(udata[%d], udata[%d]);\n", u->name, loc, loc + 1);
                break;
            case METAL_UNIFORM_FLOAT3:
            case METAL_UNIFORM_INT3:
                metalAppendf(msl, len, cap, "    float3 _U_%s = float3(udata[%d], udata[%d], udata[%d]);\n",
                             u->name, loc, loc + 1, loc + 2);
                break;
            case METAL_UNIFORM_FLOAT4:
            case METAL_UNIFORM_INT4:
                metalAppendf(msl, len, cap, "    float4 _U_%s = float4(udata[%d], udata[%d], udata[%d], udata[%d]);\n",
                             u->name, loc, loc + 1, loc + 2, loc + 3);
                break;
            case METAL_UNIFORM_MAT4:
                metalAppendf(msl, len, cap,
                    "    float4x4 _U_%s = float4x4("
                    "float4(udata[%d],udata[%d],udata[%d],udata[%d]),"
                    "float4(udata[%d],udata[%d],udata[%d],udata[%d]),"
                    "float4(udata[%d],udata[%d],udata[%d],udata[%d]),"
                    "float4(udata[%d],udata[%d],udata[%d],udata[%d]));\n",
                    u->name,
                    loc, loc+1, loc+2, loc+3,
                    loc+4, loc+5, loc+6, loc+7,
                    loc+8, loc+9, loc+10, loc+11,
                    loc+12, loc+13, loc+14, loc+15);
                break;
            default:
                metalAppendf(msl, len, cap, "    float _U_%s = udata[%d];\n", u->name, loc);
                break;
        }
    }
}

char* metalTranspileGMEStoMSL(const char* glslVertex, const char* glslFragment,
                              MAYBE_UNUSED const char** vertexAttributes,
                              MAYBE_UNUSED uint32_t vertexAttributeCount,
                              MetalGMLShader* outMeta) {
    if (glslVertex == nullptr || glslFragment == nullptr) return nullptr;

    MetalParsedUniform* uniforms = nullptr;
    uint32_t uniformCount = 0;
    metalCollectUniforms(glslVertex, &uniforms, &uniformCount);
    metalCollectUniforms(glslFragment, &uniforms, &uniformCount);

    const char* builtins[] = {"gm_Matrices", "gm_FogColour", "gm_AlphaTestEnabled", "gm_AlphaRefValue", "gm_BaseTexture"};
    MetalUniformType builtinTypes[] = {METAL_UNIFORM_MAT4, METAL_UNIFORM_FLOAT4, METAL_UNIFORM_BOOL, METAL_UNIFORM_FLOAT, METAL_UNIFORM_SAMPLER};
    uint32_t builtinArrays[] = {5, 1, 1, 1, 1};
    for (uint32_t b = 0; b < 5; b++) {
        bool found = false;
        for (uint32_t i = 0; i < uniformCount; i++) {
            if (strcmp(uniforms[i].name, builtins[b]) == 0) { found = true; break; }
        }
        if (!found) {
            uniforms = (MetalParsedUniform*)safeRealloc(uniforms, (uniformCount + 1) * sizeof(MetalParsedUniform));
            uniforms[uniformCount].name = metalDupStr(builtins[b]);
            uniforms[uniformCount].type = builtinTypes[b];
            uniforms[uniformCount].arraySize = builtinArrays[b];
            uniforms[uniformCount].isSampler = builtinTypes[b] == METAL_UNIFORM_SAMPLER;
            uniforms[uniformCount].floatCount = uniforms[uniformCount].isSampler ? 0 :
                metalUniformFloatCount(builtinTypes[b], builtinArrays[b]);
            uniformCount++;
        } else {
            for (uint32_t i = 0; i < uniformCount; i++) {
                if (strcmp(uniforms[i].name, "gm_Matrices") == 0) {
                    uniforms[i].arraySize = 5;
                    uniforms[i].floatCount = metalUniformFloatCount(METAL_UNIFORM_MAT4, 5);
                }
            }
        }
    }

    memset(outMeta, 0, sizeof(*outMeta));
    outMeta->uniforms = (MetalShaderUniform*)safeCalloc(uniformCount, sizeof(MetalShaderUniform));
    uint32_t floatCursor = 0;
    uint32_t samplerCursor = 0;
    for (uint32_t i = 0; i < uniformCount; i++) {
        MetalParsedUniform* u = &uniforms[i];
        MetalShaderUniform* dest = &outMeta->uniforms[outMeta->uniformCount++];
        dest->name = metalDupStr(u->name);
        dest->type = u->type;
        dest->arraySize = u->arraySize;
        dest->floatCount = u->floatCount;
        if (u->isSampler) {
            dest->location = -1;
            dest->samplerSlot = samplerCursor++;
            outMeta->samplerCount++;
            if (strcmp(u->name, "gm_BaseTexture") == 0) outMeta->gmBaseTexture = dest;
            continue;
        }
        dest->location = (int32_t)floatCursor;
        floatCursor += u->floatCount;
        if (strcmp(u->name, "gm_Matrices") == 0) outMeta->gmMatrices = dest;
        if (strcmp(u->name, "gm_FogColour") == 0) outMeta->gmFogColour = dest;
        if (strcmp(u->name, "gm_AlphaTestEnabled") == 0) outMeta->gmAlphaTestEnabled = dest;
        if (strcmp(u->name, "gm_AlphaRefValue") == 0) outMeta->gmAlphaRefValue = dest;
    }
    outMeta->uniformFloatCount = floatCursor < 4 ? 4 : floatCursor;
    outMeta->uniformData = (float*)safeCalloc(outMeta->uniformFloatCount, sizeof(float));

    char* vertMainRaw = metalExtractMainBody(glslVertex);
    char* fragMainRaw = metalExtractMainBody(glslFragment);
    char* vertMain = metalRewriteMainBody(vertMainRaw, true, outMeta->uniforms, outMeta->uniformCount);
    char* fragMain = metalRewriteMainBody(fragMainRaw, false, outMeta->uniforms, outMeta->uniformCount);
    free(vertMainRaw);
    free(fragMainRaw);

    size_t cap = 32768;
    char* msl = (char*)safeCalloc(1, cap);
    size_t len = 0;

    metalAppend(&msl, &len, &cap,
        "#include <metal_stdlib>\n"
        "using namespace metal;\n"
        "struct VertexIn { float2 position; float2 uv; float4 color; };\n"
        "struct VSOut { float4 position [[position]]; float2 uv; float4 color; };\n"
        "struct VertexAttr { float3 position; float4 color; float2 uv; };\n"
        "static inline float4x4 _load_mat4_from(const constant float* udata, int base, int index) {\n"
        "    int o = base + index * 16;\n"
        "    return float4x4(float4(udata[o],udata[o+1],udata[o+2],udata[o+3]),\n"
        "                    float4(udata[o+4],udata[o+5],udata[o+6],udata[o+7]),\n"
        "                    float4(udata[o+8],udata[o+9],udata[o+10],udata[o+11]),\n"
        "                    float4(udata[o+12],udata[o+13],udata[o+14],udata[o+15]));\n"
        "}\n");

    metalAppend(&msl, &len, &cap,
        "vertex VSOut gm_vertex(const device VertexIn* vertices [[buffer(0)]],\n"
        "                       const constant float* udata [[buffer(1)]],\n"
        "                       uint vid [[vertex_id]]) {\n"
        "    VSOut vout;\n"
        "    VertexAttr vin;\n"
        "    vin.position = float3(vertices[vid].position, 0.0);\n"
        "    vin.uv = vertices[vid].uv;\n"
        "    vin.color = vertices[vid].color;\n"
        "    vout.uv = vin.uv;\n"
        "    vout.color = vin.color;\n"
        "    float4 _mtl_position = float4(vin.position, 1.0);\n");
    metalEmitUniformLoads(&msl, &len, &cap, outMeta);
    metalAppend(&msl, &len, &cap, vertMain);
    metalAppend(&msl, &len, &cap,
        "\n    vout.position = _mtl_position;\n"
        "    return vout;\n"
        "}\n");

    metalAppend(&msl, &len, &cap,
        "fragment float4 gm_fragment(VSOut fin [[stage_in]],\n"
        "                            const constant float* udata [[buffer(1)]]");
    for (uint32_t i = 0; i < outMeta->uniformCount; i++) {
        if (outMeta->uniforms[i].type != METAL_UNIFORM_SAMPLER) continue;
        metalAppendf(&msl, &len, &cap,
            ",\n                            texture2d<float> %s [[texture(%u)]],\n"
            "                            sampler _samp_%s [[sampler(%u)]]",
            outMeta->uniforms[i].name, outMeta->uniforms[i].samplerSlot,
            outMeta->uniforms[i].name, outMeta->uniforms[i].samplerSlot);
    }
    metalAppend(&msl, &len, &cap, ") {\n    float4 _mtl_fragColor = float4(1.0);\n");
    metalEmitUniformLoads(&msl, &len, &cap, outMeta);
    metalAppend(&msl, &len, &cap, fragMain);
    metalAppend(&msl, &len, &cap, "\n    return _mtl_fragColor;\n}\n");

    free(vertMain);
    free(fragMain);
    for (uint32_t i = 0; i < uniformCount; i++) free(uniforms[i].name);
    free(uniforms);
    return msl;
}

static bool metalCompileGMLShader(MetalRenderer* metal, MetalGMLShader* dest, Shader* src) {
    memset(dest, 0, sizeof(*dest));
    if (!src->present || src->glslES_Vertex == nullptr || src->glslES_Fragment == nullptr)
        return false;

    char* msl = metalTranspileGMEStoMSL(src->glslES_Vertex, src->glslES_Fragment,
                                       src->vertexAttributes, src->vertexAttributeCount, dest);
    if (msl == nullptr) return false;

    NSError* error = nil;
    id<MTLLibrary> library = [metal->device newLibraryWithSource:[NSString stringWithUTF8String:msl]
                                                          options:nil
                                                            error:&error];
    if (library == nil) {
        logWarn("Metal: failed to compile shader %s: %s\n",
                src->name ? src->name : "?", error.localizedDescription.UTF8String);
        free(msl);
        for (uint32_t i = 0; i < dest->uniformCount; i++) free(dest->uniforms[i].name);
        free(dest->uniforms);
        free(dest->uniformData);
        memset(dest, 0, sizeof(*dest));
        return false;
    }
    free(msl);

    dest->library = library;
    dest->vertexFunction = [library newFunctionWithName:@"gm_vertex"];
    dest->fragmentFunction = [library newFunctionWithName:@"gm_fragment"];
    if (dest->vertexFunction == nil || dest->fragmentFunction == nil) {
        logWarn("Metal: shader %s missing entry points\n", src->name ? src->name : "?");
        for (uint32_t i = 0; i < dest->uniformCount; i++) free(dest->uniforms[i].name);
        free(dest->uniforms);
        free(dest->uniformData);
        memset(dest, 0, sizeof(*dest));
        return false;
    }

    dest->compiled = true;
    logInfo("Metal: compiled shader %s (%u uniforms, %u samplers)\n",
            src->name ? src->name : "?", dest->uniformCount, dest->samplerCount);
    return true;
}

void metalInitShaders(MetalRenderer* metal, DataWin* dataWin) {
    metal->gmlShaderCount = dataWin->shdr.count;
    metal->gmlShaders = (MetalGMLShader*)safeCalloc(metal->gmlShaderCount, sizeof(MetalGMLShader));
    logInfo("Metal: %u shaders found\n", metal->gmlShaderCount);
    uint32_t compiled = 0;
    for (uint32_t i = 0; i < metal->gmlShaderCount; i++) {
        Shader* shdr = &dataWin->shdr.shaders[i];
        if (!shdr->present) continue;
        if (metalCompileGMLShader(metal, &metal->gmlShaders[i], shdr))
            compiled++;
    }
    logInfo("Metal: %u/%u shaders compiled\n", compiled, metal->gmlShaderCount);
}

void metalDestroyShaders(MetalRenderer* metal) {
    if (metal->gmlShaders == nullptr) return;
    for (uint32_t i = 0; i < metal->gmlShaderCount; i++) {
        MetalGMLShader* shader = &metal->gmlShaders[i];
        for (uint32_t u = 0; u < shader->uniformCount; u++)
            free(shader->uniforms[u].name);
        free(shader->uniforms);
        free(shader->uniformData);
        shader->library = nil;
        shader->vertexFunction = nil;
        shader->fragmentFunction = nil;
        shader->pipeline = nil;
    }
    free(metal->gmlShaders);
    metal->gmlShaders = nullptr;
    metal->gmlShaderCount = 0;
}
