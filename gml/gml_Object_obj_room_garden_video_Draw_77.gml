if (!global.is_console)
{
    exit;
}
if (!_video_enabled)
{
    exit;
}
var _video_data = video_draw();
var _video_status = _video_data[0];
var ww = window_get_width();
var wh = window_get_height();
if (_video_status == 0)
{
    texture_set_interpolation(true);
    switch (video_get_format())
    {
        case 1:
            _vid_surface = _video_data[1];
            _chroma_surface = _video_data[2];
            if (surface_exists(_vid_surface) && surface_exists(_chroma_surface))
            {
                shader_replace_simple_set_hook(63);
                var _tex_id = surface_get_texture(_vid_surface);
                var _chroma_tex_id = surface_get_texture(_chroma_surface);
                texture_set_stage(videochromasampler, _chroma_tex_id);
                gpu_set_texfilter(false);
                draw_primitive_begin_texture(pr_trianglestrip, _tex_id);
                draw_vertex_texture(0, 0, 0, 0);
                draw_vertex_texture(ww, 0, 1, 0);
                draw_vertex_texture(0, wh, 0, 1);
                draw_vertex_texture(ww, wh, 1, 1);
                draw_primitive_end();
                gpu_set_texfilter(true);
                shader_replace_simple_reset_hook();
            }
            break;
    }
    texture_set_interpolation(false);
}
draw_set_color(c_black);
draw_set_alpha(_overlay_alpha);
ossafe_fill_rectangle(0, 0, ww - 1, wh - 1);
draw_set_alpha(1);
draw_set_color(c_white);
