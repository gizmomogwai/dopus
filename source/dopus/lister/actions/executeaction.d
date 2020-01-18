module dopus.lister.actions.executeaction;

import dopus.lister.actions;
import gtkd.x.treeselection;
import std.file;

static this()
{
    ListerActions.register(&factory!ExecuteAction);
}

class ExecuteAction : SimpleAction
{
    this(Lister lister)
    {
        super("execute", null);

        addOnActivate(delegate(Variant, SimpleAction) {
            foreach (file; lister.view.getSelection.getSelection)
            {
                import std.algorithm.searching;

                if (file.endsWith("/"))
                {
                    file = file[0 .. $ - 1];
                }

                file = Lister.calculatePath(lister.navigationStack.path, file);
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
