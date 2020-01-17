module gtkd.x.treeselection;

private import std.array;
private import gtk.TreeSelection;

extern (C) void treeSelectionSelectedForeach(GtkTreeModel* model,
        GtkTreePath* path, GtkTreeIter* iter, void* data)
{
    import gtk.TreeModel;
    import gtk.TreeIter;

    TreeModel m = new TreeModel(model);
    auto res = cast(Appender!(string[])*) data;
    res.put(m.getValueString(new TreeIter(iter), 0));
}


string[] getSelection(TreeSelection selection)
{
    auto res = appender!(string[]);
    selection.selectedForeach(&treeSelectionSelectedForeach, &res);
    return res.data;
}
