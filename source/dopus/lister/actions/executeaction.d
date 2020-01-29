module dopus.lister.actions.executeaction;

import dopus.lister.actions;
import gtkd.x.treeselection;
import std.file;

static this()
{
    ListerActions.register!ExecuteAction;
}

class ExecuteAction : SimpleAction
{
    this(Lister lister)
    {
        super("execute", null);

        addOnActivate(delegate(Variant, SimpleAction) {
            foreach (file; lister.view.getSelection.getSelection)
            {
                import dopus : unescape;

                file = Lister.calculatePath(lister.navigationStack.path, file.unescape);
                if (file.isDir)
                {
                    lister.visit(file);
                    break;
                }
                else
                {
                    lister.visit(file);
                }
            }
        });
    }
}
