module dopus.lister.actions.focusnextaction;

import dopus.lister.actions;

static this()
{
    ListerActions.register!FocusNextAction;
}

class FocusNextAction : SimpleAction
{
    this(Lister lister)
    {
        super("focusNext", null);
        addOnActivate(delegate(Variant, SimpleAction) {
                import std.stdio : writeln;

            writeln("focusNext");
        });
    }
}
