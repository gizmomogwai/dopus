module dopus.lister.actions.openterminalaction;

import dopus.lister.actions;
import std.process;

static this()
{
    ListerActions.register!OpenTerminalAction;
}

class OpenTerminalAction : SimpleAction
{
    this(Lister lister)
    {
        super("openTerminalHere", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            auto pid = spawnProcess([
                    "open", "-a", "terminal", lister.navigationStack.path
                ]);
        });
    }
}
