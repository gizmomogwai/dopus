module dopus.lister.actions.newlistersinsubfoldersaction;

import dopus.lister.actions;
import dopus.lister;
import dopus.navigationstack;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import gtk.Application;
import gtkd.x.treeselection;
import std.path;
import std.string;

static this()
{
    ListerActions.register!NewListersInSubfoldersAction;
}

class NewListersInSubfoldersAction : SimpleAction
{
    this(Lister lister)
    {
        super("newInSubfolders", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            import std.file;

            foreach (file; lister.view.getSelection.getSelection)
            {
                auto newPath = buildNormalizedPath("%s/%s".format(lister.navigationStack.path,
                    file));
                if (newPath.isDir)
                {
                    new Lister(lister.app, lister.listers, newPath,
                        new NavigationStack(lister.navigationStack).pop);
                }
            }
        });
    }

}
