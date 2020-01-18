module dopus.lister.actions.newlisteraction;

import dopus.lister.actions;

static this()
{
    ListerActions.register(&factory!NewListerAction);
}

class NewListerAction : SimpleAction
{
    this(Lister lister)
    {
        super("new", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            new Lister(lister.app, lister.listers, lister.navigationStack.path,
                new NavigationStack(lister.navigationStack).pop);
        });
    }
}
