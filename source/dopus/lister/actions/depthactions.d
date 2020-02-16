module dopus.lister.actions.depthactions;

import dopus.lister.actions;
import std.algorithm;

static this()
{
    ListerActions.register!IncreaseDepthAction;
    ListerActions.register!DecreaseDepthAction;
}

class IncreaseDepthAction : SimpleAction
{
    this(Lister lister)
    {
        super("increaseDepth", null);

        addOnActivate(delegate(Variant, SimpleAction) {
            lister.setDepth(lister.getDepth() + 1);
        });
    }
}

class DecreaseDepthAction : SimpleAction
{
    this(Lister lister)
    {
        super("decreaseDepth", null);

        addOnActivate(delegate(Variant, SimpleAction) {
            lister.setDepth(max(1, lister.getDepth - 1));
        });
    }
}
