function scr_addtosunshadows(arg0, arg1 = draw_self, arg2 = false)
{
    if (i_ex(obj_sunshadows))
    {
        _shadowdraw_func = arg1;
        __cast_shadow = arg2;
        with (obj_sunshadows)
        {
            array_push(inst_list, arg0);
        }
    }
}
