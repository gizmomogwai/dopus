module dopus.lister.actions;

import dopus.lister;
import dopus.listers;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import gtk.Application;

class ListerActions
{
    static SimpleAction function(Application app, Lister lister)[] factories;
    public static void register(T)(T factory)
    {
        factories ~= factory;
    }

    public static void registerActions(Application app, Lister lister, SimpleActionGroup actions)
    {
        foreach (factory; factories)
        {
            auto action = factory(app, lister);
            actions.insert(action);
        }
    }
}
