module dopus.lister.actions.backforwardaction;

import dopus.lister.actions;

static this()
{
    ListerActions.register!BackAction;
    ListerActions.register!ForwardAction;
}

class BackAction : SimpleAction
{
    this(Lister lister)
    {
        super("back", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            if (lister.navigationStack.back)
            {
                lister.visit(lister.navigationStack.path, false);
            }
        });
    }
}

class ForwardAction : SimpleAction
{
    this(Lister lister)
    {
        super("forward", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            if (lister.navigationStack.forward)
            {
                lister.visit(lister.navigationStack.path, false);
            }
        });
    }
}
