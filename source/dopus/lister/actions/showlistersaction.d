module dopus.lister.actions.showlistersaction;

import dopus.lister.actions;

static this()
{
    ListerActions.register!ShowListersAction;
}

class ShowListersAction : SimpleAction
{
    this(Lister lister)
    {
        super("showListers", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            lister.listers.showAll();
        });
    }
}
