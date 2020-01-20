module dopus.lister.actions;

public import dopus.lister;
public import dopus.navigationstack;
public import gio.SimpleAction;
public import gio.SimpleActionGroup;
public import gtk.Application;

SimpleAction factory(T)(Lister lister)
{
    return new T(lister);
}

class ListerActions
{
    static SimpleAction function(Lister lister)[] factories;
    public static void register(T)()
    {
        factories ~= function(Lister lister) { return new T(lister); };
    }

    public static void registerActions(Lister lister)
    {
        foreach (factory; factories)
        {
            auto action = factory(lister);
            lister.actions.insert(action);
        }
    }
}
