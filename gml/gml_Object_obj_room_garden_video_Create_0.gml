skip_timer = 0;
skip_video = false;
_video_enabled = false;
_vid_surface = -4;
_chroma_surface = -4;
var video_file = (global.lang == "ja") ? "ch5_intro_jp" : "ch5_intro_en";
video_open("vid/" + video_file + ".mp4");
video_enable_loop(false);
_mus_file = [];
_mus_file[0] = snd_init("ch5_intro_audio.ogg");
_mus_file[1] = mus_play(_mus_file[0]);
videochromasampler = -4;
var _format = video_get_format();
if (_format == 1)
{
    videochromasampler = shader_get_sampler_index(shd_video_yuv, "v_chroma");
}
_timer = 0;
_duration = video_get_duration();
_paused = false;
_screenshot = -4;
_overlay_alpha = 0;
_blackall = scr_dark_marker(-10, -10, spr_pixel_white);
_blackall.image_xscale = 999;
_blackall.image_yscale = 999;
_blackall.depth = -100;
_blackall.image_blend = c_black;
_blackall.image_alpha = 0;
if (global.is_console)
{
    _blackall.visible = false;
}

clean_up = function()
{
    snd_free(_mus_file[0]);
    if (os_type == os_ps4 || os_type == os_ps5)
    {
        var _status = video_get_status();
        if (_status != 0)
        {
            video_close();
        }
    }
    else
    {
        video_close();
    }
    if (sprite_exists(_screenshot))
    {
        sprite_delete(_screenshot);
    }
    if (surface_exists(_vid_surface))
    {
        surface_free(_vid_surface);
    }
    if (surface_exists(_chroma_surface))
    {
        surface_free(_chroma_surface);
    }
};

_init = true;
