module dopus.lister.actions.deleteaction;

import dopus.lister.actions;
import gtkd.x.treeselection;
import std.file;

static this()
{
    ListerActions.register(&factory!DeleteAction);
}

class DeleteAction : SimpleAction
{
    this(Lister lister)
    {
        super("delete", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            foreach (file; lister.view.getSelection.getSelection)
            {
                import std.file;

                file.remove;
            }
        });
    }
}
