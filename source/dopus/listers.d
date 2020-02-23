module dopus.listers;

import dopus.lister;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.CellRendererText;
import gtk.ListStore;
import gtk.ScrolledWindow;
import gtk.TreePath;
import gtk.TreeView;
import gtk.TreeViewColumn;

class Listers : ApplicationWindow
{
    Lister[] listers;
    ListStore store;

    this(Application app)
    {
        super(app);

        auto list = new TreeView();
        list.appendColumn(new TreeViewColumn("state", new CellRendererText(), "text", 0));
        list.appendColumn(new TreeViewColumn("lister", new CellRendererText(), "text", 1));

        store = new ListStore([GType.STRING, GType.STRING]);
        list.setModel(store);
        add(new ScrolledWindow(list));
        addOnDelete(delegate(Event, Widget) { hideOnDelete(); return true; });
        list.addOnRowActivated(delegate(TreePath path, TreeViewColumn, TreeView) {
            listers[path.getIndices[0]].present;
        });

    }

    Listers register(Lister lister)
    {
        listers ~= lister;
        return update(listers);
    }

    Listers unregister(Lister lister)
    {
        Lister[] newListers;
        foreach (l; listers)
        {
            if (l !is lister)
            {
                newListers ~= l;
            }
        }
        return update(newListers);
    }

    private Listers update(Lister[] newListers)
    {
        listers = newListers;
        prefixSourceAndDestination();
        store.clear();
        foreach (lister; listers)
        {
            auto i = store.createIter();
            store.setValue(i, 0, lister.isSource ? "SRC" : lister.isDestination ? "DST" : "");
            store.setValue(i, 1, lister.toString);
        }
        return this;
    }

    public Listers refresh()
    {
        return update(listers);
    }

    public Listers moveToFront(Lister lister)
    {
        Lister[] newListers;
        newListers ~= lister;
        foreach (l; listers)
        {
            if (l !is lister)
            {
                newListers ~= l;
            }
        }
        return update(newListers);
    }

    private Listers prefixSourceAndDestination()
    {
        foreach (idx, l; listers)
        {
            l.setSource(idx == 0);
            l.setDestination(idx == 1);
        }
        return this;
    }

    public auto size()
    {
        return listers.length;
    }

    public auto destination()
    {
        if (listers.length > 1)
        {
            return listers[1];
        }
        return null;
    }
}
