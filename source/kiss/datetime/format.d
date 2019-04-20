/*
 * Kiss - A refined core library for D programming language.
 *
 * Copyright (C) 2015-2018  Shanghai Putao Technology Co., Ltd
 *
 * Developer: HuntLabs.cn
 *
 * Licensed under the Apache-2.0 License.
 *
 */

module kiss.datetime.format;

import std.datetime : Month;

// return unix timestamp
int time()
{
    import core.stdc.time : time;

    return cast(int)time(null);
}

short monthToShort(Month month)
{
    short resultMonth;
    switch(month)
    {
        case Month.jan:
            resultMonth = 1;
            break;
        case Month.feb:
            resultMonth = 2;
            break;
        case Month.mar:
            resultMonth = 3;
            break;
        case Month.apr:
            resultMonth = 4;
            break;
        case Month.may:
            resultMonth = 5;
            break;
        case Month.jun:
            resultMonth = 6;
            break;
        case Month.jul:
            resultMonth = 7;
            break;
        case Month.aug:
            resultMonth = 8;
            break;
        case Month.sep:
            resultMonth = 9;
            break;
        case Month.oct:
            resultMonth = 10;
            break;
        case Month.nov:
            resultMonth = 11;
            break;
        case Month.dec:
            resultMonth = 12;
            break;
        default:
            resultMonth = 0;
            break;
    }
    
    return resultMonth;
}

// return formated time string from timestamp
string date(string format, long timestamp = 0)
{
    import std.datetime : SysTime;
    import std.conv : to;

    long newTimestamp = timestamp > 0 ? timestamp : time();

    string timeString;

    SysTime st = SysTime.fromUnixTime(newTimestamp);

    // format to ubyte
    foreach(c; format)
    {
        switch(c)
        {
        case 'Y':
            timeString ~= st.year.to!string;
            break;
        case 'y':
            timeString ~= (st.year.to!string)[2..$];
            break;
        case 'm':
            short month = monthToShort(st.month);
            timeString ~= month < 10 ? "0" ~ month.to!string : month.to!string;
            break;
        case 'd':
            timeString ~= st.day < 10 ? "0" ~ st.day.to!string : st.day.to!string;
            break;
        case 'H':
            timeString ~= st.hour < 10 ? "0" ~ st.hour.to!string : st.hour.to!string;
            break;
        case 'i':
            timeString ~= st.minute < 10 ? "0" ~ st.minute.to!string : st.minute.to!string;
            break;
        case 's':
            timeString ~= st.second < 10 ? "0" ~ st.second.to!string : st.second.to!string;
            break;
        default:
            timeString ~= c;
            break;
        }
    }

    return timeString;
}
