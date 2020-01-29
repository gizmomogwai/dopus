module gtkd.x.treeselection;

private import gtk.TreeIter;
private import gtk.TreeModel;
private import gtk.TreeSelection;
private import std.array;

extern (C) void treeSelectionSelectedForeach(GtkTreeModel* model,
        GtkTreePath* path, GtkTreeIter* iter, void* data)
{
    auto m = new TreeModel(model);
    auto res = cast(Appender!(string[])*) data;
    res.put(m.getValueString(new TreeIter(iter), 0));
}

string[] getSelection(TreeSelection selection)
{
    auto res = appender!(string[]);
    selection.selectedForeach(&treeSelectionSelectedForeach, &res);
    return res.data;
}
