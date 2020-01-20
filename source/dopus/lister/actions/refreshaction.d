module dopus.lister.actions.refreshaction;

import dopus.lister.actions;

static this()
{
    ListerActions.register!RefreshAction;
}

class RefreshAction : SimpleAction
{
    this(Lister lister)
    {
        super("refresh", null);
        addOnActivate(delegate(Variant, SimpleAction) { lister.refresh(); });
    }
}
