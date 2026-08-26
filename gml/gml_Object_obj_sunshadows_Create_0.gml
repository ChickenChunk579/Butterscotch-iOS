sunlight_alpha = 1;
marker_mode = false;
surf_resize = -4;
surf_w = (global.darkzone == 0) ? 320 : 640;
surf_h = (global.darkzone == 0) ? 240 : 480;
darkzone_multiplier = (global.darkzone == 0) ? 1 : 2;
resize_mode = global.darkzone;
evening_mode = false;
surf_static_shadows = -4;
surf_static_cutout = -4;
surf_static_hcutout = -4;
surf_dyna_shadows = -4;
surf_highlights = -4;
inst_list = [];
selfshadow_instances = [];
dropshadow_instances = [];
highlight_instances = [];
cuthighlight_instances = [];
shadow_spritecache = [];
shadow_assetcache = {};
if (global.darkzone == 0)
{
    colour_shadowblend = 3671309;
    alpha_shadowblend = 0.3;
    skew_amt = 45;
    highlight_mode = 0;
    tile_layer_names = ["Town_Shadows_morning"];
    asset_layer_names = ["Town_Shadows_morning_a"];
    cutout_tile_layer_names = [];
    cutout_asset_layer_names = ["Town_Shadows_morning_cutout"];
    hcutout_tile_layer_names = ["Town_Shadows_morning"];
    hcutout_asset_layer_names = ["HIGHLIGHTCUT", "Town_Shadows_morning_a"];
    objects_shadows = [];
    objects_cutout = [1240];
    objects_hcutout = [];
}
else if (global.darkzone == 1)
{
    colour_shadowblend = 3676703;
    alpha_shadowblend = 0.7;
    highlight_mode = 0;
    tile_layer_names = ["Town_Shadows_morning"];
    asset_layer_names = ["SHADOW_LAYER"];
    cutout_tile_layer_names = [];
    cutout_asset_layer_names = ["SHADOWCUT_LAYER"];
    hcutout_tile_layer_names = [];
    hcutout_asset_layer_names = ["HIGHLIGHTCUT"];
    objects_shadows = [];
    objects_cutout = [];
    objects_hcutout = [];
}
if (global.darkzone == 0 && global.flag[1324] == 2)
{
    dropshadowcut_assets = [2979, 6701, 6977, 1883, 2986, 6434, 1458, 8192, 6879];
    var _count = array_length(dropshadowcut_assets);
    for (var i = 0; i < _count; i++)
    {
        var _allassets = findspriteinfo_all(dropshadowcut_assets[i]);
        var _count2 = array_length(_allassets);
        for (var j = 0; j < _count2; j++)
        {
            var _asset = _allassets[j];
            var _obj = instance_create(_asset.x, _asset.y, obj_dropshadowcut);
            _obj.sprite_index = _asset.sprite_index;
            _obj.image_alpha = _asset.image_alpha;
            _obj.image_angle = _asset.image_angle;
            _obj.image_index = _asset.image_index;
            _obj.image_speed = _asset.image_speed;
            _obj.image_xscale = _asset.image_xscale;
            _obj.image_yscale = _asset.image_yscale;
        }
    }
}
u_shadowblend = shader_get_uniform(shd_shadowblend, "shadowCol");
u_shadowblend_evening = shader_get_uniform(shd_shadowblend_evening, "shadowCol");
u_pixelw = shader_get_uniform(shd_shadowblend_evening, "pixelw");
u_highlight = shader_get_uniform(shd_forcecolour, "forceColour");
shadowblend_r = color_get_red(colour_shadowblend) / 255;
shadowblend_g = color_get_green(colour_shadowblend) / 255;
shadowblend_b = color_get_blue(colour_shadowblend) / 255;

generate_shadow_surface = function(arg0, arg1, arg2)
{
    var _surface_needed = false;
    for (var i = 0; i < array_length(arg0); i++)
    {
        if (layer_exists(layer_get_id(arg0[i])))
        {
            _surface_needed = true;
        }
    }
    for (var i = 0; i < array_length(arg1); i++)
    {
        if (layer_exists(layer_get_id(arg1[i])))
        {
            _surface_needed = true;
        }
    }
    for (var i = 0; i < array_length(arg2); i++)
    {
        if (i_ex(arg2[i]))
        {
            _surface_needed = true;
        }
    }
    if (!_surface_needed)
    {
        return -4;
    }
    surface_depth_disable(true);
    shader_replace_simple_set_hook(37);
    var _surf = surface_create(room_width, room_height);
    surface_set_target(_surf);
    draw_clear_alpha(c_black, 0);
    for (var i = 0; i < array_length(arg2); i++)
    {
        with (arg2[i])
        {
            if (!variable_instance_exists(id, "sunshadows_exclude"))
            {
                if (variable_instance_exists(id, "_shadowdraw_func"))
                {
                    _shadowdraw_func();
                }
                else
                {
                    draw_self();
                }
                draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, image_angle, image_blend, image_alpha);
                show_debug_message_concat("shadow masking for: ", sprite_get_name(sprite_index));
            }
            else
            {
                show_debug_message_concat("IGNORING shadow mask for: ", sprite_get_name(sprite_index));
            }
        }
    }
    for (var i = 0; i < array_length(arg0); i++)
    {
        if (layer_exists(layer_get_id(arg0[i])))
        {
            var _tilemap = layer_tilemap_get_id(layer_get_id(arg0[i]));
            draw_tilemap(_tilemap, 0, 0);
        }
    }
    for (var i = 0; i < array_length(arg1); i++)
    {
        if (layer_exists(layer_get_id(arg1[i])))
        {
            var _lay = layer_get_id(arg1[i]);
            var _elements = layer_get_all_elements(_lay);
            for (var j = 0; j < array_length(_elements); j++)
            {
                if (layer_get_element_type(_elements[j]) == 4)
                {
                    draw_sprite_ext(layer_sprite_get_sprite(_elements[j]), layer_sprite_get_index(_elements[j]), layer_sprite_get_x(_elements[j]), layer_sprite_get_y(_elements[j]), layer_sprite_get_xscale(_elements[j]), layer_sprite_get_yscale(_elements[j]), layer_sprite_get_angle(_elements[j]), layer_sprite_get_blend(_elements[j]), layer_sprite_get_alpha(_elements[j]));
                }
            }
        }
    }
    surface_reset_target();
    shader_replace_simple_reset_hook();
    surface_depth_disable(false);
    return _surf;
};

cast_shadow = function(arg0, arg1 = false)
{
    var _cx = cx;
    var _cy = cy;
    var _resizemultiplier = resize_mode ? 0.5 : 1;
    if (evening_mode)
    {
        with (arg0)
        {
            if (arg1 == false || visible == true)
            {
                var _sprname = sprite_get_name(sprite_index);
                var _cache = obj_sunshadows.shadow_assetcache;
                var _sprite_cached = variable_struct_get(_cache, _sprname);
                var _finalsprite;
                if (is_undefined(_sprite_cached) || is_undefined(variable_struct_get(_sprite_cached, "dropshadow")))
                {
                    var _spritelookup = asset_get_index(sprite_get_name(sprite_index) + "_shadow_floor");
                    if (is_undefined(_sprite_cached))
                    {
                        variable_struct_set(_cache, _sprname, 
                        {
                            dropshadow: _spritelookup
                        });
                    }
                    else
                    {
                        variable_struct_get(_cache, _sprname).dropshadow = _spritelookup;
                    }
                    _finalsprite = _spritelookup;
                }
                else
                {
                    _finalsprite = _sprite_cached.dropshadow;
                }
                if (_finalsprite != -1)
                {
                    draw_sprite_ext(_finalsprite, image_index, x - _cx, y - _cy, image_xscale, image_yscale, image_angle, image_blend, image_alpha);
                }
                else
                {
                }
            }
        }
    }
    else if (highlight_mode == 0)
    {
        with (arg0)
        {
            if (arg1 == false || visible == true)
            {
                var _adj_x = 0;
                var _adj_y = 0;
                if (object_index == obj_mainchara && global.darkzone == 0)
                {
                    _adj_y = 1;
                }
                else if (object_index == obj_actor || object_index == obj_caterpillarchara)
                {
                    if (name == "susie" && global.darkzone == 1)
                    {
                        _adj_y = 0;
                    }
                    if (name == "ralsei")
                    {
                        _adj_y = 0;
                    }
                    if (name == "noelle")
                    {
                        _adj_y = 1;
                    }
                    if (name == "kris")
                    {
                        _adj_y = 1;
                    }
                }
                var dw_amp = 1;
                if (global.darkzone == 1)
                {
                    dw_amp = 2;
                }
                x -= _cx;
                y -= _cy;
                var use_special_shadowcast = true;
                var _xxx = (x + (other.skew_amt * dw_amp)) * _resizemultiplier;
                var _yyy = (y + (sprite_height * 2) + _adj_y + (sprite_height * (1 - other.sunlight_alpha))) * _resizemultiplier;
                if (object_index == obj_caterpillar_dash || object_index == obj_mainchara_dash)
                {
                    _yyy = (y + sprite_height) * _resizemultiplier;
                    _xxx = (x + other.skew_amt) * _resizemultiplier;
                    use_special_shadowcast = true;
                }
                var _spr = sprite_index;
                if (object_index == obj_jump_to_point)
                {
                    _spr = target.sprite_index;
                    _yyy += 60;
                    _xxx -= 10;
                    use_special_shadowcast = false;
                }
                if (variable_instance_exists(id, "__sunshadow_y_offset"))
                {
                    _adj_y = __sunshadow_y_offset;
                }
                if (use_special_shadowcast)
                {
                    draw_shadowcast(-1, other.skew_amt, -dw_amp, image_alpha, false, 1 / dw_amp, true, other.shadow_spritecache, _adj_y);
                    x += _cx;
                    y += _cy;
                }
                else
                {
                    draw_sprite_skew_ext(_spr, image_index, _xxx, _yyy + 40, image_xscale * _resizemultiplier, image_yscale * -1 * (2 - other.sunlight_alpha) * _resizemultiplier, image_angle, image_blend, image_alpha, other.skew_amt, 0);
                    x += _cx;
                    y += _cy;
                }
            }
        }
    }
};

cast_shadow_self = function(arg0, arg1 = false)
{
    var _cx = other.cx;
    var _cy = other.cy;
    with (arg0)
    {
        if (arg1 == false || visible == true)
        {
            var _jumpadj = 0;
            if (object_index == obj_caterpillar_dash || object_index == obj_mainchara_dash)
            {
                _jumpadj = jumppos;
            }
            if (object_index == obj_climb_kris)
            {
                _jumpadj = -drawoffsety;
            }
            x -= _cx;
            y -= _cy;
            y -= _jumpadj;
            if (variable_instance_exists(id, "_shadowdraw_func"))
            {
                _shadowdraw_func();
            }
            else
            {
                draw_self();
            }
            x += _cx;
            y += _cy;
            y += _jumpadj;
        }
    }
};

cast_highlight = function(arg0, arg1 = false)
{
    var _yoffset = 0;
    var _xoffset = 0;
    var _cx = other.cx;
    var _cy = other.cy;
    if (highlight_mode == 0)
    {
        _yoffset = darkzone_multiplier;
    }
    if (highlight_mode == 1)
    {
        _xoffset = -darkzone_multiplier;
    }
    with (arg0)
    {
        if (arg1 == false || visible == true)
        {
            var _jumpadj = 0;
            if (object_index == obj_caterpillar_dash || object_index == obj_mainchara_dash)
            {
                _jumpadj = jumppos;
            }
            x -= _cx;
            y -= _cy;
            y -= _jumpadj;
            if (variable_instance_exists(id, "_shadowdraw_func"))
            {
                _shadowdraw_func();
            }
            else
            {
                draw_self();
            }
            x += _cx;
            y += _cy;
            y += _jumpadj;
        }
    }
};

cast_highlight_cutout = function(arg0)
{
    var _yoffset = 0;
    var _xoffset = 0;
    var _cx = cx;
    var _cy = cy;
    if (highlight_mode == 0)
    {
        _yoffset = darkzone_multiplier;
    }
    if (highlight_mode == 1)
    {
        _xoffset = -darkzone_multiplier;
    }
    with (arg0)
    {
        if (visible)
        {
            var _jumpadj = 0;
            if (object_index == obj_caterpillar_dash || object_index == obj_mainchara_dash)
            {
                _jumpadj = jumppos;
            }
            x -= _cx;
            y -= _cy;
            y -= _jumpadj;
            gpu_set_blendmode(bm_subtract);
            y += _yoffset;
            x += _xoffset;
            if (variable_instance_exists(id, "_shadowdraw_func"))
            {
                _shadowdraw_func();
            }
            else
            {
                draw_self();
            }
            gpu_set_blendmode(bm_normal);
            y -= _yoffset;
            x -= _xoffset;
            x += _cx;
            y += _cy;
            y += _jumpadj;
        }
    }
};

for (var i = 0; i < array_length(tile_layer_names); i++)
{
    layer_set_visible(layer_get_id(tile_layer_names[i]), false);
}
for (var i = 0; i < array_length(asset_layer_names); i++)
{
    layer_set_visible(layer_get_id(asset_layer_names[i]), false);
}
for (var i = 0; i < array_length(cutout_tile_layer_names); i++)
{
    layer_set_visible(layer_get_id(cutout_tile_layer_names[i]), false);
}
for (var i = 0; i < array_length(cutout_asset_layer_names); i++)
{
    layer_set_visible(layer_get_id(cutout_asset_layer_names[i]), false);
}
for (var i = 0; i < array_length(hcutout_tile_layer_names); i++)
{
    layer_set_visible(layer_get_id(hcutout_tile_layer_names[i]), false);
}
for (var i = 0; i < array_length(hcutout_asset_layer_names); i++)
{
    layer_set_visible(layer_get_id(hcutout_asset_layer_names[i]), false);
}
surf_static_shadows = generate_shadow_surface(tile_layer_names, asset_layer_names, objects_shadows);
surf_static_cutout = generate_shadow_surface(cutout_tile_layer_names, cutout_asset_layer_names, objects_cutout);
surf_static_hcutout = generate_shadow_surface(hcutout_tile_layer_names, hcutout_asset_layer_names, objects_hcutout);

free_surfaces = function()
{
    if (surface_exists(surf_static_shadows))
    {
        surface_free(surf_static_shadows);
    }
    if (surface_exists(surf_static_cutout))
    {
        surface_free(surf_static_cutout);
    }
    if (surface_exists(surf_static_hcutout))
    {
        surface_free(surf_static_hcutout);
    }
};

if (global.flag[915] == 20 && global.plot == 160)
{
    instance_destroy();
}
