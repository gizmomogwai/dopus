module dopus.listers;

import dopus.lister;

import gtk.ApplicationWindow;
import gtk.Application;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.ListStore;
import gtk.ScrolledWindow;
import gtk.CellRendererText;

class Listers : ApplicationWindow
{

    Lister[] listers;
    ListStore store;

    this(Application app)
    {
        super(app);

        auto list = new TreeView();
        list.appendColumn(new TreeViewColumn("lister", new CellRendererText(), "text", 0));
        store = new ListStore([GType.STRING]);
        list.setModel(store);
        add(new ScrolledWindow(list));
    }

    Listers register(Lister lister)
    {
        listers ~= lister;
        return updateStore();
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
        listers = newListers;
        return updateStore();
    }

    private Listers updateStore()
    {
        import std.stdio;
        writeln("number of listers: ", listers.length);
        store.clear();
        foreach (lister; listers)
        {
            store.setValue(store.createIter(), 0, lister.toString);
        }
        return this;
    }
    public Listers moveToFront(Lister lister) {
        Lister[] newListers;
        newListers ~= lister;
        foreach (l; listers) {
            if (l !is lister) {
                newListers ~= l;
            }
        }

        foreach (idx, l; newListers) {
            l.setSource(idx == 0);
            l.setDestination(idx == 1);
        }

        listers = newListers;
        return updateStore();
    }
}
