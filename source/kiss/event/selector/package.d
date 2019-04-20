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
 
module kiss.event.selector;

import kiss.core;
import kiss.event.core;
import std.conv;


version (linux)
{
    public import kiss.event.selector.epoll;

    // alias KissSelector = AbstractSelector;

}
else version (Kqueue)
{

    // alias KissSelector = KqueueLoop;

    public import kiss.event.selector.kqueue;

}
else version (Windows)
{
    public import kiss.event.selector.iocp;

    // alias KissSelector = IocpSelector;

}
else
{
    static assert(false, "unsupported platform");
}
