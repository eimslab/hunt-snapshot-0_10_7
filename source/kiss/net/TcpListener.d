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

module kiss.net.TcpListener;

import kiss.event;
import kiss.net.core;

import std.socket;
import std.exception;
import kiss.logger;
import core.thread;
import core.time;

import kiss.core;
import kiss.net.TcpStream;

alias AcceptEventHandler = void delegate(TcpListener sender, TcpStream stream);
alias PeerCreateHandler = TcpStream delegate(TcpListener sender, Socket socket, size_t bufferSize);

/**
*/
class TcpListener : AbstractListener
{
    private bool isSslEnabled = false;
    private size_t _bufferSize = 4 * 1024;
    protected EventHandler _shutdownHandler;

    /// event handlers
    AcceptEventHandler acceptHandler;
    SimpleEventHandler closeHandler;
    PeerCreateHandler peerCreateHandler;

    this(EventLoop loop, AddressFamily family = AddressFamily.INET, size_t bufferSize = 4 * 1024)
    {
        _bufferSize = bufferSize;
        version (Windows)
            super(loop, family, bufferSize);
        else
            super(loop, family);
    }

    TcpListener onConnectionAccepted(AcceptEventHandler handler)
    {
        acceptHandler = handler;
        return this;
    }

    TcpListener onPeerCreating(PeerCreateHandler handler)
    {
        peerCreateHandler = handler;
        return this;
    }

    TcpListener onShutdown(EventHandler handler)
    {
        _shutdownHandler = handler;
        return this;
    }

    TcpListener bind(string ip, ushort port)
    {
        bind(parseAddress(ip, port));
        return this;
    }

    TcpListener bind(ushort port)
    {
        bind(createAddress(this.socket, port));
        return this;
    }

    TcpListener bind(Address addr)
    {
        this.socket.bind(addr);
        _localAddress = _socket.localAddress();
        return this;
    }

    Address bindingAddress()
    {
        return _localAddress;
    }

    TcpListener reusePort(bool use)
    {
        this.socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, use);

        version (Posix)
        {
            import core.sys.posix.sys.socket;

            this.socket.setOption(SocketOptionLevel.SOCKET, cast(SocketOption) SO_REUSEPORT, use);
        }
        else version (windows)
        {
            import core.sys.windows.winsock2;

            if (!use)
                this.socket.setOption(SocketOptionLevel.SOCKET,
                        cast(SocketOption) SO_EXCLUSIVEADDRUSE, true);
        }

        return this;
    }

    TcpListener listen(int backlog)
    {
        this.socket.listen(backlog);
        return this;
    }

    override void start()
    {
        _inLoop.register(this);
        _isRegistered = true;
        version (Windows)
            this.doAccept();
    }

    override void close()
    {
        if (closeHandler !is null)
            closeHandler();
        else if (_shutdownHandler !is null)
            _shutdownHandler(this, null);
        this.onClose();
    }

    protected override void onRead()
    {
        bool canRead = true;
        version (KissDebugMode)
            trace("start to listen");
        // while(canRead && this.isRegistered) // why??
        {
            version (KissDebugMode)
                trace("listening...");
            canRead = onAccept((Socket socket) {

                version (KissDebugMode)
                    infof("new connection from %s, fd=%d",
                        socket.remoteAddress.toString(), socket.handle());

                if (acceptHandler !is null)
                {
                    TcpStream stream;
                    if (peerCreateHandler is null)
                        stream = new TcpStream(_inLoop, socket, _bufferSize);
                    else
                        stream = peerCreateHandler(this, socket, _bufferSize);

                    acceptHandler(this, stream);
                    stream.start();
                }
            });

            if (this.isError)
            {
                canRead = false;
                error("listener error: ", this.erroString);
                this.close();
            }
        }
    }
}
