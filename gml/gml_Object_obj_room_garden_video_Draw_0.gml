
draw_enable_alphablend(true);
draw_set_color(c_white); 
draw_set_alpha(1.0);
draw_text(_cam_x + 20, _cam_y + 20, "asdge");

if (global.is_console)
{
    exit;
}
var _text = _video_enabled ? "Video: Enabled" : "Video: Disabled";
var _cam_x = camerax();
var _cam_y = cameray();
var _cam_w = view_wport[0];

if (_video_enabled)
{
    var _video_data = video_draw();
    var _video_status = _video_data[0];
    if (_video_status == 0)
    {
        texture_set_interpolation(true);
        switch (video_get_format())
        {
            case 0:
                _vid_surface = _video_data[1];
                draw_surface_ext(_vid_surface, 0, 60, 0.5, 0.5, 0, c_white, 1);
                break;
        }
        texture_set_interpolation(false);
    }

    if (_paused)
    {
        if (_screenshot == -4)
        {
            _screenshot = sprite_create_from_surface(application_surface, 0, 0, view_wport[0], view_hport[0], false, true, 0, 0);
        }
        draw_enable_alphablend(false);
        draw_sprite_ext(_screenshot, 0, camerax(), cameray(), 1, 1, 0, c_white, 1);
        draw_enable_alphablend(true);
    }
}

draw_enable_alphablend(true);
draw_set_color(c_white); 
draw_set_alpha(1.0); // Force full opacity
draw_text(_cam_x + 20, _cam_y + 20, _text);