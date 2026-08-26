if (scr_debug())
{
    if (keyboard_check_pressed(vk_space))
    {
        _status = video_get_status();
        if (_status == 2)
        {
            video_pause();
            audio_pause_sound(_mus_file[1]);
        }
        else if (_status == 3)
        {
            video_resume();
            audio_resume_sound(_mus_file[1]);
        }
    }
    if (!skip_video)
    {
        if (button2_h() || button3_h())
        {
            skip_timer++;
            if (skip_timer >= 30)
            {
                skip_video = true;
                video_close();
                scr_set_video_ini_value(0);
                global.tempflag[50] = 1;
                room_goto(room_dw_garden_meetflowery);
            }
        }
        else if (skip_timer > 0)
        {
            skip_timer = 0;
        }
    }
}
if (_paused)
{
    exit;
}
var _status = video_get_status();
if (_status == 2)
{
    _timer++;
    var video_pos = video_get_position() / video_get_duration();
    var mus_pos = audio_sound_get_track_position(_mus_file[1]) / audio_sound_length(_mus_file[1]);
    var mus_offset = abs((round(video_pos * 100) / 100) - (round(mus_pos * 100) / 100));
    if (mus_offset >= 0.03)
    {
        audio_sound_set_track_position(_mus_file[1], video_pos * audio_sound_length(_mus_file[1]));
    }
    if (_timer == 830)
    {
        if (global.is_console)
        {
            scr_lerpvar("_overlay_alpha", 0, 1, 120);
        }
        else
        {
            with (_blackall)
            {
                scr_lerpvar("image_alpha", 0, 1, 100);
            }
        }
    }
    if (_timer == 890)
    {
        _paused = true;
        video_pause();
        scr_script_delayed(video_resume, 90);
    }
}
