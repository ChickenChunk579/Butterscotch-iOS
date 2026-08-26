if (scr_battlebg_fullalpha())
{
    exit;
}
var ys = array_get(scr_platswap_yscale(), 0);
if (ys == 1)
{
    exit;
}
var _shadow_alpha = 1 - ys;
if (!surface_exists(surf_static_shadows))
{
    surf_static_shadows = generate_shadow_surface(tile_layer_names, asset_layer_names, objects_shadows);
}
if (!surface_exists(surf_static_cutout))
{
    surf_static_cutout = generate_shadow_surface(cutout_tile_layer_names, cutout_asset_layer_names, objects_cutout);
}
if (!surface_exists(surf_static_hcutout))
{
    surf_static_hcutout = generate_shadow_surface(hcutout_tile_layer_names, hcutout_asset_layer_names, objects_hcutout);
}
if (!surface_exists(surf_dyna_shadows))
{
    surf_dyna_shadows = surface_create(surf_w, surf_h);
}
if (!surface_exists(surf_highlights))
{
    surf_highlights = surface_create(surf_w, surf_h);
}
cx = camerax();
cy = cameray();
var skip_main_characters = false;
with (obj_platswap)
{
    if (mode == 1)
    {
        skip_main_characters = true;
    }
}
if (resize_mode)
{
    if (!surface_exists(surf_resize))
    {
        surf_resize = surface_create(320, 240);
    }
    surface_set_target(surf_resize);
    draw_clear_alpha(c_black, 0);
    if (!skip_main_characters)
    {
        cast_shadow(1200, true);
        cast_shadow(1662, true);
        cast_shadow(1561, true);
        cast_shadow(1391, true);
        cast_shadow(777, true);
    }
    if (array_length(dropshadow_instances) > 0)
    {
        for (var i = 0; i < array_length(dropshadow_instances); i++)
        {
            if (instance_exists(dropshadow_instances[i]))
            {
                cast_shadow(dropshadow_instances[i], true);
            }
        }
    }
    if (array_length(inst_list) > 0)
    {
        for (var i = 0; i < array_length(inst_list); i++)
        {
            if (instance_exists(inst_list[i]) && variable_instance_exists(inst_list[i].id, "__cast_shadow") && inst_list[i].__cast_shadow)
            {
                cast_shadow(inst_list[i], false);
            }
        }
    }
    surface_reset_target();
}
surface_set_target(surf_dyna_shadows);
draw_clear_alpha(c_black, 0);
if (surface_exists(surf_static_shadows))
{
    draw_surface(surf_static_shadows, -cx, -cy);
}
if (resize_mode)
{
    draw_surface_ext(surf_resize, 0, 0, 2, 2, 0, c_white, 1);
}
else
{
    if (!skip_main_characters)
    {
        cast_shadow(1200, true);
        cast_shadow(1662, true);
        cast_shadow(1561, true);
        cast_shadow(1391, true);
        cast_shadow(777, true);
    }
    if (array_length(dropshadow_instances) > 0)
    {
        for (var i = 0; i < array_length(dropshadow_instances); i++)
        {
            if (instance_exists(dropshadow_instances[i]))
            {
                cast_shadow(dropshadow_instances[i], true);
            }
        }
    }
    if (array_length(inst_list) > 0)
    {
        for (var i = 0; i < array_length(inst_list); i++)
        {
            if (instance_exists(inst_list[i]) && variable_instance_exists(inst_list[i].id, "__cast_shadow") && inst_list[i].__cast_shadow)
            {
                cast_shadow(inst_list[i], true);
            }
        }
    }
}
with (obj_dropshadowcut)
{
    gpu_set_blendmode(bm_subtract);
    draw_sprite_ext(sprite_index, image_index, x - other.cx, y - other.cy, image_xscale, image_yscale, image_angle, image_blend, 1);
    gpu_set_blendmode(bm_normal);
}
with (obj_dynamicshadowmask)
{
    image_alpha = 1 - other.sunlight_alpha;
}
cast_shadow_self(699);
with (obj_dynamicshadowmask_slope)
{
    image_alpha = 1 - other.sunlight_alpha;
}
cast_shadow_self(829);
gpu_set_blendmode(bm_subtract);
if (surface_exists(surf_static_cutout))
{
    draw_surface(surf_static_cutout, -cx, -cy);
}
if (!skip_main_characters)
{
    cast_shadow_self(1200, true);
    cast_shadow_self(1561, true);
    cast_shadow_self(1391, true);
}
if (array_length(selfshadow_instances) > 0)
{
    for (var i = 0; i < array_length(selfshadow_instances); i++)
    {
        if (instance_exists(selfshadow_instances[i]))
        {
            cast_shadow_self(selfshadow_instances[i], true);
        }
    }
}
gpu_set_blendmode(bm_normal);
surface_reset_target();
if (global.darkzone)
{
    surface_set_target(surf_highlights);
    draw_clear_alpha(c_white, 0);
    if (!skip_main_characters)
    {
        cast_highlight(1200, true);
        cast_highlight(1662, true);
        cast_highlight(1561, true);
        cast_highlight(1391, true);
        cast_highlight(777, true);
        cast_highlight(1166, true);
        cast_highlight(18, true);
    }
    if (marker_mode)
    {
        cast_highlight(1240, true);
    }
    if (array_length(inst_list) > 0)
    {
        for (var i = 0; i < array_length(inst_list); i++)
        {
            if (instance_exists(inst_list[i]))
            {
                cast_highlight(inst_list[i], true);
            }
        }
    }
    if (array_length(highlight_instances) > 0)
    {
        for (var i = 0; i < array_length(highlight_instances); i++)
        {
            if (instance_exists(highlight_instances[i]))
            {
                cast_highlight(highlight_instances[i], true);
            }
        }
    }
    if (!skip_main_characters)
    {
        cast_highlight_cutout(1200);
        cast_highlight_cutout(1662, true);
        cast_highlight_cutout(1561);
        cast_highlight_cutout(1391);
        cast_highlight_cutout(777);
        cast_highlight_cutout(1166);
        cast_highlight_cutout(18);
    }
    if (marker_mode)
    {
        cast_highlight_cutout(1240);
    }
    if (array_length(inst_list) > 0)
    {
        for (var i = 0; i < array_length(inst_list); i++)
        {
            if (instance_exists(inst_list[i]))
            {
                cast_highlight_cutout(inst_list[i]);
            }
        }
    }
    if (array_length(cuthighlight_instances) > 0)
    {
        for (var i = 0; i < array_length(cuthighlight_instances); i++)
        {
            if (instance_exists(cuthighlight_instances[i]))
            {
                cast_highlight_cutout(cuthighlight_instances[i]);
            }
        }
    }
    if (array_length(highlight_instances) > 0)
    {
        for (var i = 0; i < array_length(highlight_instances); i++)
        {
            if (instance_exists(highlight_instances[i]))
            {
                cast_highlight_cutout(highlight_instances[i]);
            }
        }
    }
    if (subtract_highlights)
    {
        gpu_set_blendmode(bm_subtract);
        if (surface_exists(surf_static_cutout))
        {
            draw_surface(surf_static_cutout, -cx, -cy);
        }
        if (surface_exists(surf_static_hcutout))
        {
            draw_surface(surf_static_hcutout, -cx, -cy);
        }
        gpu_set_blendmode(bm_normal);
    }
    surface_reset_target();
}
surface_set_target(surf_dyna_shadows);
cast_shadow_self(1662, true);
cast_shadow_self(777, true);
cast_shadow_self(1166, true);
cast_shadow_self(18, true);
if (marker_mode)
{
    cast_shadow_self(1240, true);
}
if (array_length(inst_list) > 0)
{
    for (var i = 0; i < array_length(inst_list); i++)
    {
        if (instance_exists(inst_list[i]))
        {
            cast_shadow_self(inst_list[i], true);
        }
    }
}
surface_reset_target();
shader_replace_simple_set_hook(25);
shader_set_uniform_f(u_shadowblend, shadowblend_r, shadowblend_g, shadowblend_b, alpha_shadowblend);
draw_surface_ext(surf_dyna_shadows, cx, cy, 1, 1, 0, c_white, 1 * _shadow_alpha);
shader_replace_simple_reset_hook();
shader_replace_simple_set_hook(41);
if (highlight_mode == 0)
{
    if (global.darkzone == 0)
    {
    }
    else if (instance_exists(obj_parallax_cliffs))
    {
        if (obj_parallax_cliffs.sun_colour == 0)
        {
            shader_set_uniform_f(u_highlight, 1, 0.83, 0.36);
        }
        else if (obj_parallax_cliffs.sun_colour == 2)
        {
            shader_set_uniform_f(u_highlight, 0.43, 1, 0);
        }
        else if (obj_parallax_cliffs.sun_colour == 3)
        {
            shader_set_uniform_f(u_highlight, 0.349, 0.392, 1);
        }
        else if (obj_parallax_cliffs.sun_colour == 4)
        {
            shader_set_uniform_f(u_highlight, 1, 0.46, 0.32);
        }
        else if (obj_parallax_cliffs.sun_colour == 5)
        {
            shader_set_uniform_f(u_highlight, 0.09, 1, 1);
        }
        else if (obj_parallax_cliffs.sun_colour == 6)
        {
            shader_set_uniform_f(u_highlight, 1, 0.88, 0.125);
        }
        else if (obj_parallax_cliffs.sun_colour == 7)
        {
            shader_set_uniform_f(u_highlight, 1, 0.325, 0.678);
        }
    }
    else
    {
        shader_set_uniform_f(u_highlight, 1, 0.847, 0.435);
    }
}
else
{
    shader_set_uniform_f(u_highlight, 1, 0.4, 0);
}
if (global.darkzone)
{
    draw_surface_ext(surf_highlights, cx, cy, 1, 1, image_angle, image_blend, sunlight_alpha * 2);
}
shader_replace_simple_reset_hook();
