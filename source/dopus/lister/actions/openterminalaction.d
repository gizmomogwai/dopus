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
            version (OSX)
            {
                auto command = [
                    "open", "-a", "terminal", lister.navigationStack.path
                ];
            }

            version (linux)
            {
                import std.string;

                auto command = [
                    "gnome-terminal",
                    format!"--working-directory=%s"(lister.navigationStack.path)
                ];
            }
            auto pid = spawnProcess(command);
        });
    }
}
