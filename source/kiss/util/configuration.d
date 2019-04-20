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

module kiss.util.configuration;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.format;
import std.path;
import std.stdio;
import std.string;
import std.traits;

import kiss.logger;

/**
*/
struct Configuration
{
    string name;

    this(string str)
    {
        name = str;
    }
}

/**
*/
struct Value
{
    this(bool opt)
    {
        optional = opt;
    }

    this(string str, bool opt = false)
    {
        name = str;
        optional = opt;
    }

    string name;
    bool optional = false;
}

class BadFormatException : Exception
{
    mixin basicExceptionCtors;
}

class EmptyValueException : Exception
{
    mixin basicExceptionCtors;
}

/**
*/
T as(T)(string value, T iv = T.init)
{
    static if (is(T == bool))
    {
        if (value.length == 0 || value == "false" || value == "0")
            return false;
        else
            return true;
    }
    else static if (std.traits.isNumeric!(T))
    {
        if (value.length == 0)
            return iv;
        else
            return to!T(value);
    }
    else
    {
        if (value.length == 0)
            return iv;
        else
            return cast(T) value;
    }
}

/**
*/
class ConfigurationItem
{
    ConfigurationItem parent;

    this(string name, string parentPath = "")
    {
        _name = name;
    }

    @property ConfigurationItem subItem(string name)
    {
        auto v = _map.get(name, null);
        if (v is null)
        {
            string path = this.fullPath();
            if (path.empty)
                path = name;
            else
                path = path ~ "." ~ name;
            throw new EmptyValueException(format("The item of '%s' is not defined! ", path));
        }
        return v;
    }

    @property bool exists(string name)
    {
        auto v = _map.get(name, null);
        return (v !is null);
    }

    string currentName()
    {
        return _name;
    }

    string fullPath()
    {
        return _fullPath;
    }

    @property string value()
    {
        return _value;
    }

    ConfigurationItem opDispatch(string s)()
    {
        return subItem(s);
    }

    ConfigurationItem opIndex(string s)
    {
        return subItem(s);
    }

    T as(T = string)(T iv = T.init)
    {
        static if (is(T == bool))
        {
            if (_value.length == 0 || _value == "false" || _value == "0")
                return false;
            else
                return true;
        }
        else static if (std.traits.isNumeric!(T))
        {
            if (_value.length == 0)
                return iv;
            else
                return to!T(_value);
        }
        else
        {
            if (_value.length == 0)
                return iv;
            else
                return cast(T) _value;
        }
    }

    void apppendChildNode(string key, ConfigurationItem subItem)
    {
        subItem.parent = this;
        _map[key] = subItem;
    }

    override string toString()
    {
        return _fullPath;
    }

    // string buildFullPath()
    // {
    //     string r = name;
    //     ConfigurationItem cur = parent;
    //     while (cur !is null && !cur.name.empty)
    //     {
    //         r = cur.name ~ "." ~ r;
    //         cur = cur.parent;
    //     }
    //     return r;
    // }

private:
    string _value;
    string _name;
    string _fullPath;
    ConfigurationItem[string] _map;
}

// dfmt off
__gshared const string[] reservedWords = [
    "abstract", "alias", "align", "asm", "assert", "auto", "body", "bool",
    "break", "byte", "case", "cast", "catch", "cdouble", "cent", "cfloat", 
    "char", "class","const", "continue", "creal", "dchar", "debug", "default", 
    "delegate", "delete", "deprecated", "do", "double", "else", "enum", "export", 
    "extern", "false", "final", "finally", "float", "for", "foreach", "foreach_reverse",
    "function", "goto", "idouble", "if", "ifloat", "immutable", "import", "in", "inout", 
    "int", "interface", "invariant", "ireal", "is", "lazy", "long",
    "macro", "mixin", "module", "new", "nothrow", "null", "out", "override", "package",
    "pragma", "private", "protected", "public", "pure", "real", "ref", "return", "scope", 
    "shared", "short", "static", "struct", "super", "switch", "synchronized", "template", 
    "this", "throw", "true", "try", "typedef", "typeid", "typeof", "ubyte", "ucent", 
    "uint", "ulong", "union", "unittest", "ushort", "version", "void", "volatile", "wchar",
    "while", "with", "__FILE__", "__FILE_FULL_PATH__", "__MODULE__", "__LINE__", 
    "__FUNCTION__", "__PRETTY_FUNCTION__", "__gshared", "__traits", "__vector", "__parameters",
    "subItem", "rootItem"
];
// dfmt on

/**
*/
class ConfigBuilder
{
    this(string filename, string section = "")
    {
        if (!exists(filename) || isDir(filename))
            throw new Exception("The config file does not exist: " ~ filename);
        _section = section;
        loadConfig(filename);
    }

    ConfigurationItem subItem(string name)
    {
        return _value.subItem(name);
    }

    @property ConfigurationItem rootItem()
    {
        return _value;
    }

    ConfigurationItem opDispatch(string s)()
    {
        return _value.opDispatch!(s)();
    }

    ConfigurationItem opIndex(string s)
    {
        return _value.subItem(s);
    }

    T build(T, string nodeName = "")()
    {
        static if (!nodeName.empty)
        {
            pragma(msg, "node name: " ~ nodeName);
            return buildItem!(T)(this.subItem(nodeName));
        }
        else static if (hasUDA!(T, Configuration))
        {
            enum name = getUDAs!(T, Configuration)[0].name;
            // pragma(msg,  "node name: " ~ name);
            static if (name.length > 0)
            {
                return buildItem!(T)(this.subItem(name));
            }
            else
            {
                return buildItem!(T)(this.rootItem);
            }
        }
        else
        {
            return buildItem!(T)(this.rootItem);
        }
    }

    static private T buildItem(T)(ConfigurationItem item)
    {
        T creatT(T)()
        {
            static if (is(T == struct))
            {
                return T();
            }
            else static if (is(T == class))
            {
                return new T();
            }
            else
            {
                static assert(false, T.stringof ~ " is not supported!");
            }
        }

        auto r = creatT!T();
        enum generatedCode = buildSetFunction!(T, r.stringof, item.stringof)();
        // pragma(msg, generatedCode);
        mixin(generatedCode);
        return r;
    }

    static private string buildSetFunction(T, string returnParameter, string incomingParameter)()
    {
        import std.format;

        string str = "import kiss.logger;";
        foreach (memberName; __traits(allMembers, T)) // TODO: // foreach (memberName; __traits(derivedMembers, T))
        {
            enum memberProtection = __traits(getProtection, __traits(getMember, T, memberName));
            static if (memberProtection == "private"
                    || memberProtection == "protected" || memberProtection == "export")
            {
                version (KissDebugMode) pragma(msg, "skip private member: " ~ memberName);
            }
            else static if (isType!(__traits(getMember, T, memberName)))
            {
                version (KissDebugMode) pragma(msg, "skip inner type member: " ~ memberName);
            }
            else static if (__traits(isStaticFunction, __traits(getMember, T, memberName)))
            {
                version (KissDebugMode) pragma(msg, "skip static member: " ~ memberName);
            }
            else
            {
                alias memberType = typeof(__traits(getMember, T, memberName));
                enum memberTypeString = memberType.stringof;

                static if (hasUDA!(__traits(getMember, T, memberName), Value))
                {
                    enum item = getUDAs!((__traits(getMember, T, memberName)), Value)[0];
                    enum settingItemName = item.name.empty ? memberName : item.name;
                }
                else
                {
                    enum settingItemName = memberName;
                }

                // 
                static if (is(memberType == interface))
                {
                    pragma(msg, "interface (unsupported): " ~ memberName);
                }
                else static if (is(memberType == struct) || is(memberType == class))
                {
                    str ~= setClassMemeber!(memberType, settingItemName,
                            memberName, returnParameter, incomingParameter)();
                }
                else static if (isFunction!(memberType))
                {
                    enum r = setFunctionMemeber!(memberType, settingItemName,
                                memberName, returnParameter, incomingParameter)();
                    if (!r.empty)
                        str ~= r;
                }
                else
                {
                    version (KissDebugMode) pragma(msg,
                            "setting " ~ memberName ~ " with item " ~ settingItemName);
                    str ~= q{
                        if(%5$s.exists("%1$s")) {
                            %4$s.%2$s = %5$s.subItem("%1$s").as!(%3$s)();
                        }
                        else {
                            version (KissDebugMode) warningf("Undefined item: %%s.%1$s" , %5$s.fullPath);
                        }
                        
                        version (KissDebugMode) tracef("%4$s.%2$s=%%s", %4$s.%2$s);
                    }.format(settingItemName, memberName,
                            memberTypeString, returnParameter, incomingParameter);
                }
            }
        }
        return str;
    }

    private static string setFunctionMemeber(memberType, string settingItemName,
            string memberName, string returnParameter, string incomingParameter)()
    {
        string r = "";
        alias memeberParameters = Parameters!(memberType);
        static if (memeberParameters.length == 1)
        {
            alias parameterType = memeberParameters[0];

            static if (is(parameterType == struct) || is(parameterType == class)
                    || is(parameterType == interface))
            {
                version (KissDebugMode) pragma(msg, "skip method with class: " ~ memberName);
            }
            else
            {
                version (KissDebugMode) pragma(msg, "method: " ~ memberName);

                r = q{
                            if(%5$s.exists("%1$s")) {
                                %4$s.%2$s(%5$s.subItem("%1$s").as!(%3$s)());
                            }
                            else {
                                version (KissDebugMode) warningf("Undefined item: %%s.%1$s" , %5$s.fullPath);
                            }
                            
                            version (KissDebugMode) tracef("%4$s.%2$s=%%s", %4$s.%2$s);
                            }.format(settingItemName, memberName,
                        parameterType.stringof, returnParameter, incomingParameter);
            }
        }
        else
        {
            version (KissDebugMode) pragma(msg, "skip method: " ~ memberName);
        }

        return r;
    }

    private static setClassMemeber(memberType, string settingItemName, string memberName, string returnParameter, string incomingParameter)()
    {
        enum fullTypeName = fullyQualifiedName!(memberType);
        enum memberModuleName = moduleName!(memberType);

        static if (settingItemName == memberName && hasUDA!(memberType, Configuration))
        {
            // try to get the ItemName from the UDA Configuration in a class or struct
            enum newSettingItemName = getUDAs!(memberType, Configuration)[0].name;
        }
        else
        {
            enum newSettingItemName = settingItemName;
        }

        version (KissDebugMode)
        {
            pragma(msg, "module name: " ~ memberModuleName);
            pragma(msg, "full type name: " ~ fullTypeName);
            pragma(msg, "setting " ~ memberName ~ " with item " ~ newSettingItemName);
        }

        string r = q{
            import %1$s;
            
            tracef("%5$s.%3$s is a class/struct.");
            if(%6$s.exists("%2$s")) {
                %5$s.%3$s = buildItem!(%4$s)(%6$s.subItem("%2$s"));
            }
            else {
                version (KissDebugMode) warningf("Undefined item: %%s.%2$s" , %6$s.fullPath);
            }
        }.format(memberModuleName, newSettingItemName,
                memberName, fullTypeName, returnParameter, incomingParameter);
        return r;
    }

private:
    void loadConfig(string filename)
    {
        _value = new ConfigurationItem("");

        if (!exists(filename))
            return;

        auto f = File(filename, "r");
        if (!f.isOpen())
            return;
        scope (exit)
            f.close();
        string section = "";
        int line = 1;
        while (!f.eof())
        {
            scope (exit)
                line += 1;
            string str = f.readln();
            str = strip(str);
            if (str.length == 0)
                continue;
            if (str[0] == '#' || str[0] == ';')
                continue;
            auto len = str.length - 1;
            if (str[0] == '[' && str[len] == ']')
            {
                section = str[1 .. len].strip;
                continue;
            }
            if (section != _section && section != "")
                continue;

            str = stripInlineComment(str);
            auto site = str.indexOf("=");
            enforce!BadFormatException((site > 0),
                    format("Bad format in file %s, at line %d", filename, line));
            string key = str[0 .. site].strip;
            setValue(key, str[site + 1 .. $].strip);
        }
    }

    string stripInlineComment(string line)
    {
        ptrdiff_t index = indexOf(line, "# ");

        if (index == -1)
            return line;
        else
            return line[0 .. index];
    }

    void setValue(string key, string value)
    {
        string currentPath;
        string[] list = split(key, '.');
        auto cvalue = _value;
        foreach (str; list)
        {
            if (str.length == 0)
                continue;

            if (canFind(reservedWords, str))
            {
                warningf("Found a reserved word: %s. It may cause some errors to use it.", str);
            }

            if (currentPath.empty)
                currentPath = str;
            else
                currentPath = currentPath ~ "." ~ str;

            // version (KissDebugMode)
            //     tracef("checking node: path=%s", currentPath);
            auto tvalue = cvalue._map.get(str, null);
            if (tvalue is null)
            {
                tvalue = new ConfigurationItem(str);
                tvalue._fullPath = currentPath;
                cvalue.apppendChildNode(str, tvalue);
                // version (KissDebugMode)
                //     tracef("new node: parent=%s, node=%s, value=%s", cvalue.fullPath, str, value);
            }
            cvalue = tvalue;
        }

        if (cvalue !is _value)
            cvalue._value = value;
    }

    string _section;
    ConfigurationItem _value;
}

version (unittest)
{
    import kiss.util.configuration;

    @Configuration("app")
    class TestConfig
    {
        string test;
        double time;

        TestHttpConfig http;

        @Value("optial", true)
        int optial = 500;

        @Value(true)
        int optial2 = 500;

        // mixin ReadConfig!TestConfig;
    }

    @Configuration("http")
    struct TestHttpConfig
    {
        @Value("listen")
        int value;
        string addr;

        // mixin ReadConfig!TestHttpConfig;
    }
}

unittest
{
    import std.stdio;
    import FE = std.file;

    FE.write("test.config", `app.http.listen = 100
    http.listen = 100
    app.test = 
    app.time = 0.25 
    # this is  
     ; start dev
    [dev]
    app.test = dev`);

    auto conf = new ConfigBuilder("test.config");
    assert(conf.http.listen.value.as!long() == 100);
    assert(conf.app.test.value() == "");

    auto confdev = new ConfigBuilder("test.config", "dev");
    long tv = confdev.http.listen.value.as!long;
    assert(tv == 100);
    assert(confdev.http.listen.value.as!long() == 100);
    writeln("----------", confdev.app.test.value());
    string tvstr = cast(string) confdev.app.test.value;

    assert(tvstr == "dev");
    assert(confdev.app.test.value() == "dev");
    bool tvBool = confdev.app.test.value.as!bool;
    assert(tvBool);

    assertThrown!(EmptyValueException)(confdev.app.host.value());

    TestConfig test = confdev.build!(TestConfig)();
    assert(test.test == "dev");
    assert(test.time == 0.25);
    assert(test.http.value == 100);
    assert(test.optial == 500);
    assert(test.optial2 == 500);
}
