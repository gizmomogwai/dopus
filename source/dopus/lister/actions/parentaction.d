module dopus.lister.actions.parentaction;

import dopus.lister.actions;

static this()
{
    ListerActions.register!ParentAction;
}

class ParentAction : SimpleAction
{
    this(Lister lister)
    {
        super("parent", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            auto file = Lister.calculatePath(lister.navigationStack.path, "..");
            lister.visit(file);
        });
    }
}
