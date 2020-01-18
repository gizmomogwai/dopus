module dopus.lister.actions.newlisteraction;

import dopus.lister.actions;
import dopus.lister;
import dopus.listers;
import dopus.navigationstack;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import gtk.Application;

SimpleAction n(Application app, Lister lister)
{
    return new NewListerAction(app, lister);
}

static this()
{
    ListerActions.register(&n);
}

class NewListerAction : SimpleAction
{
    this(Application app, Lister lister)
    {
        super("new", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            new Lister(app, lister.listers, lister.navigationStack.path,
                new NavigationStack(lister.navigationStack).pop);
        });
    }
}
