module dopus.navigationstack;

import std.format;

/++
 + A NavigationStack is a history of paths.
 + You can move back and forward in this list.
 + If you move back some steps and then visit another path you cannot move forward anymore.
 + You cannot move farther back then the beginning.
 + A better implementation would be something like the undotree of emacs.
 +/
class NavigationStack
{

    string[] history;
    int idx = -1;

    this()
    {
    }

    this(NavigationStack other)
    {
        idx = other.idx;
        history = other.history.dup;
    }

    NavigationStack visit(string path)
    {
        string[] newHistory;
        foreach (i, h; history)
        {
            if (i <= idx)
            {
                newHistory ~= h;
            }
            else
            {
                break;
            }
        }
        history = newHistory;
        history ~= path;
        ++idx;
        return this;
    }

    bool back()
    {
        if (idx > 0)
        {
            --idx;
            return true;
        }
        return false;
    }

    NavigationStack pop()
    {
        if (idx > 0)
        {
            --idx;
            history = history[0 .. $ - 1];
        }
        return this;
    }

    bool forward()
    {
        if (idx + 1 < history.length)
        {
            ++idx;
            return true;
        }
        return false;
    }

    string path() const
    {
        if (idx == -1)
        {
            return null;
        }
        if (idx >= history.length)
        {
            return null;
        }
        return history[idx];
    }

    override string toString() const
    {
        import std.array : appender;

        auto res = appender!string;
        res.put("NavigationStack {\n");
        foreach (i, h; history)
        {
            if (i == idx)
            {
                res.put("-> %s\n".format(h));
            }
            else
            {
                res.put("   %s\n".format(h));
            }
        }
        res.put("}");
        return res.data;
    }
}

unittest
{
    auto ns = new NavigationStack();
    assert(ns.path == null);
    ns.visit("1");
    assert(ns.path == "1");
    ns.visit("2");
    assert(ns.path == "2");
    assert(ns.back);
    assert(ns.path == "1");
    assert(!ns.back);
    assert(ns.path == "1");
    assert(ns.forward);
    assert(ns.path == "2");
    assert(!ns.forward);
    assert(ns.path == "2");
    assert(ns.back);
    ns.visit("3");
    assert(ns.path == "3");
    assert(ns.back);
    assert(ns.path == "1");
    assert(ns.forward);
    assert(ns.path == "3");
    ns.pop;
    assert(ns.path == "1");
    assert(!ns.forward);
}
