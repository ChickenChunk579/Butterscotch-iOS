function draw_shadowcast(arg0, arg1, arg2 = 0, arg3 = 1, arg4 = false, arg5 = 1, arg6 = false, arg7, arg8 = 0)
{
    if (arg0 == 0 || image_yscale == 0)
    {
        exit;
    }
    if (sprite_index == -4)
    {
        exit;
    }
    var _sx = x - camera_get_view_x(view_camera[0]);
    var _sy = y - camera_get_view_y(view_camera[0]);
    var _spritedata = undefined;
    if (array_length(arg7) > sprite_index)
    {
        _spritedata = arg7[sprite_index];
    }
    if (_spritedata == undefined || _spritedata == 0)
    {
        _spritedata = sprite_get_info(sprite_index);
        array_set(arg7, sprite_index, _spritedata);
    }
    var _frame = _spritedata.frames[scr_loop(floor(image_index), image_number)];
    var _width = _frame.w * image_xscale * arg5;
    var _yy = ((arg4 ? _sy : y) - sprite_yoffset) * arg5;
    var _height = _frame.h / abs(arg0);
    var _bottom = _yy + _height + arg2 + (_frame.y_offset * abs(arg0));
    var _top = _bottom - (_height * arg0);
    var _xx = (((arg4 ? _sx : x) - sprite_xoffset) + (_frame.x_offset * image_xscale)) * arg5;
    _top = floor(_top) - arg8;
    _bottom = floor(_bottom) - arg8;
    if (arg6)
    {
        arg1 = floor(lengthdir_x(floor(_height / sin(degtorad(arg1))), arg1));
    }
    draw_sprite_pos(sprite_index, image_index, _xx + arg1, _top, _xx + arg1 + _width, _top, _xx + _width, _bottom, _xx, _bottom, arg3);
}
