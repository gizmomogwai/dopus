module dopus.listers;

import dopus.lister;

import gtk.ApplicationWindow;
import gtk.Application;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.ListStore;
import gtk.ScrolledWindow;
import gtk.CellRendererText;

class Listers : ApplicationWindow {

    Lister[] listers;
    ListStore store;

    this(Application app) {
        super(app);

        auto list = new TreeView();
        list.appendColumn(new TreeViewColumn("lister", new CellRendererText(), "text", 0));
        store = new ListStore([GType.STRING]);
        list.setModel(store);
        add(new ScrolledWindow(list));
        showAll();
    }

    Listers register(Lister lister) {
        listers ~= lister;
        return updateStore();
    }

    Listers unregister(Lister lister) {
        Lister[] newListers;
        foreach (l; listers) {
            if (l != lister) {
                newListers ~= l;
            }
        }
        listers = newListers;
        return updateStore();
    }

    private Listers updateStore() {
        store.clear();
        foreach (lister; listers) {
            store.setValue(store.createIter(), 0, lister.path);
        }
        return this;
    }
}
