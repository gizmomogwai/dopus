module dopus.lister.actions.shownavigationstackaction;

import dopus.lister.actions;

static this()
{
    ListerActions.register(&factory!ShowNavigationStackAction);
}

class ShowNavigationStackAction : SimpleAction
{
    this(Lister lister)
    {
        super("showNavigationStack", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            import std.stdio;

            writeln(lister.navigationStack);
        });
    }
}
