module hunt.application.staticfile;

import core.time;
import std.conv;
import std.string;
import std.datetime;
import std.path;
import std.digest.md;
import std.algorithm.searching : canFind;
static import std.stdio;

import hunt;
import hunt.application.controller;
import hunt.application.config;
import hunt.utils.string;
import hunt.http.code;

alias OnStaticFilePathSegmentation = string function(const string, const string) nothrow;

class StaticfileController : Controller
{
    mixin MakeController;

    __gshared OnStaticFilePathSegmentation onStaticFilePathSegmentation;
    __gshared string staticFileMimetype = string.init;

    @Action
    void doStaticFile()
    {
        if (request.route.staticFilePath == string.init)
        {
            response.do404();

            return;
        }

        string staticFilename = mendPath(request.route.staticFilePath);

        if ((staticFilename == string.init) || (!std.file.exists(staticFilename)))
        {
            response.do404();

            return;
        }

        FileInfo fi;
        try
        {
            fi = makeFileInfo(staticFilename);
        }
        catch (Exception e)
        {
            response.doError(HTTPCodes.INTERNAL_SERVER_ERROR);

            return;
        }

        if (fi.isDirectory)
        {
            response.do404();

            return;
        }

        auto lastModified = toRFC822DateTimeString(fi.timeModified.toUTC());
        auto etag = "\"" ~ hexDigest!MD5(staticFilename ~ ":" ~ lastModified ~ ":" ~ to!string(fi.size)).idup ~ "\"";

        response.setHeader(HTTPHeaderCode.LAST_MODIFIED, lastModified);
        response.setHeader(HTTPHeaderCode.ETAG, etag);

        if (Config.app.application.staticFileCacheMinutes > 0)
        {
            auto expireTime = Clock.currTime(UTC()) + dur!"minutes"(Config.app.application.staticFileCacheMinutes);
            response.setHeader(HTTPHeaderCode.EXPIRES, toRFC822DateTimeString(expireTime));
            response.setHeader(HTTPHeaderCode.CACHE_CONTROL, "max-age=" ~ to!string(Config.app.application.staticFileCacheMinutes * 60));
        }

        if ((request.headerExists(HTTPHeaderCode.IF_MODIFIED_SINCE) && (request.header(HTTPHeaderCode.IF_MODIFIED_SINCE) == lastModified)) ||
            (request.headerExists(HTTPHeaderCode.IF_NONE_MATCH) && (request.header(HTTPHeaderCode.IF_NONE_MATCH) == etag)))
        {
            response.setHttpStatusCode(HTTPCodes.NOT_MODIFIED);

            return;
        }

        auto mimetype = ((staticFileMimetype == string.init) ? getMimeContentTypeForFile(staticFilename) : staticFileMimetype);
        response.setHeader(HTTPHeaderCode.CONTENT_TYPE, mimetype ~ ";charset=utf-8");

        response.setHeader(HTTPHeaderCode.ACCEPT_RANGES, "bytes");
        ulong rangeStart = 0;
        ulong rangeEnd = 0;

        if (request.headerExists(HTTPHeaderCode.RANGE))
        {
            // https://tools.ietf.org/html/rfc7233
            // Range can be in form "-\d", "\d-" or "\d-\d"
            auto range = request.header(HTTPHeaderCode.RANGE).chompPrefix("bytes=");
            if (range.canFind(','))
            {
                response.doError(HTTPCodes.NOT_IMPLEMENTED);

                return;
            }
            auto s = range.split("-");

            if (s.length != 2)
            {
                response.doError(HTTPCodes.BAD_REQUEST);

                return;
            }

            try
            {
                if (s[0].length)
                {
                    rangeStart = s[0].to!ulong;
                    rangeEnd = s[1].length ? s[1].to!ulong : fi.size;
                }
                else if (s[1].length)
                {
                    rangeEnd = fi.size;
                    auto len = s[1].to!ulong;

                    if (len >= rangeEnd)
                    {
                        rangeStart = 0;
                    }
                    else
                    {
                        rangeStart = rangeEnd - len;
                    }
                }
                else
                {
                    response.doError(HTTPCodes.BAD_REQUEST);

                    return;
                }
            }
            catch (ConvException e)
            {
                response.doError(HTTPCodes.BAD_REQUEST, e.msg);

                return;
            }

            if (rangeEnd > fi.size)
            {
                rangeEnd = fi.size;
            }

            if (rangeStart > rangeEnd)
            {
                rangeStart = rangeEnd;
            }

            if (rangeEnd)
            {
                rangeEnd--; // End is inclusive, so one less than length
            }
            // potential integer overflow with rangeEnd - rangeStart == size_t.max is intended. This only happens with empty files, the + 1 will then put it back to 0

            response.setHeader(HTTPHeaderCode.CONTENT_LENGTH, to!string(rangeEnd - rangeStart + 1));
            response.setHeader(HTTPHeaderCode.CONTENT_RANGE, "bytes %s-%s/%s".format(rangeStart < rangeEnd ? rangeStart : rangeEnd, rangeEnd, fi.size));
            response.setHttpStatusCode(HTTPCodes.PARTIAL_CONTENT);
        }
        else
        {
            rangeEnd = fi.size - 1;
            response.setHeader(HTTPHeaderCode.CONTENT_LENGTH, fi.size.to!string);
        }

        // write out the file contents
        auto f = std.stdio.File(staticFilename, "r");
        scope(exit) f.close();

        f.seek(rangeStart);
        auto buf = f.rawRead(new ubyte[rangeEnd.to!uint - rangeStart.to!uint + 1]);
        response.setContext(buf);
    }

private:

    string mendPath(string path)
    {
        if (!path.startsWith(".") && !isAbsolute(path))
        {
            path = "./" ~ path;
        }

        if (!path.endsWith("/"))
        {
            path ~= "/";
        }

        string name = chompPrefix(request.path, request.route.getPattern());
        
        if (onStaticFilePathSegmentation !is null)
        {
            return onStaticFilePathSegmentation(path, name);
        }

        return path ~ name;
    }

    struct FileInfo {
        string name;
        ulong size;
        SysTime timeModified;
        SysTime timeCreated;
        bool isSymlink;
        bool isDirectory;
    }

    FileInfo makeFileInfo(string fileName)
    {
        FileInfo fi;
        fi.name = baseName(fileName);
        auto ent = DirEntry(fileName);
        fi.size = ent.size;
        fi.timeModified = ent.timeLastModified;
        version(Windows) fi.timeCreated = ent.timeCreated;
        else fi.timeCreated = ent.timeLastModified;
        fi.isSymlink = ent.isSymlink;
        fi.isDirectory = ent.isDir;

        return fi;
    }

    bool isCompressedFormat(string mimetype)
    {
        switch (mimetype)
        {
            case "application/gzip", "application/x-compress", "application/png", "application/zip",
                    "audio/x-mpeg", "image/png", "image/jpeg",
                    "video/mpeg", "video/quicktime", "video/x-msvideo",
                    "application/font-woff", "application/x-font-woff", "font/woff":
                return true;
            default: return false;
        }
    }
}
