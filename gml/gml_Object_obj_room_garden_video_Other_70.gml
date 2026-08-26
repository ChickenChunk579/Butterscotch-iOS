var _type = ds_map_find_value(async_load, "type");
if (_type == "video_start")
{
    _video_enabled = true;
}
else if (_type == "video_end")
{
    if (!_video_enabled)
    {
        exit;
    }
    _video_enabled = false;
    scr_set_video_ini_value(0);
    clean_up();
    global.tempflag[50] = 1;
    room_goto(room_dw_garden_meetflowery);
}
