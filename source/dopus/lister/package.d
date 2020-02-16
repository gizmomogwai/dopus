module dopus.lister;

import core.time;
import dopus;
import dopus.lister.actions;
import dopus.listers;
import dopus.navigationstack;
import dyaml;
import gdk.Event;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import gtk.AccelGroup;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Box;
import gtk.Button;
import gtk.CellRendererText;
import gtk.HeaderBar;
import gtk.Image;
import gtk.Label;
import gtk.ListStore;
import gtk.MainWindow;
import gtk.MenuButton;
import gtk.PopoverMenu;
import gtk.ScrolledWindow;
import gtk.SpinButton;
import gtk.Spinner;
import gtk.Table;
import gtk.TreeIter;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtkd.x.threads;
import std.array;
import std.concurrency;
import std.conv;
import std.experimental.logger;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;

string shorten(string input)
{
    import std.process : environment;

    return input.replace(environment["HOME"], "~");
}

void startProcess(shared(string[]) command, shared void delegate() start,
        shared void delegate(string) progress, shared void delegate() finished)
{
    start();

    auto pid = spawnProcess(cast(string[]) command);
    auto res = pid.tryWait();
    while (res.terminated == false)
    {
        import core.thread : Thread;
        import core.time : dur;

        Thread.sleep(dur!"seconds"(1));
        res = pid.tryWait();
    }
    progress("running '%s' finished with status '%d'".format(command, res.status));
    finished();
}

class Cancelled
{
}

void fillStoreTask(shared(ListStore) store, void delegate() done, string path,
        int depth, string base)
{
    class FillStoreTask
    {
        shared(Cancelled) cancelled;
        public void run(shared(ListStore) sharedStore, string path, int depth, string base)
        {
            auto store = cast() sharedStore;
            foreach (dirEntry; dirEntries(path, SpanMode.shallow))
            {
                receiveTimeout(-1.seconds, (shared(Cancelled) c) { cancelled = c; });

                auto s = dirEntry.name.replace(base ~ "/", "");
                if (dirEntry.isDir)
                {
                    s ~= "/";
                }
                store.setValue(store.createIter(), 0, s);
                if (dirEntry.isDir && depth > 1)
                {
                    run(sharedStore, dirEntry.name, depth - 1, base);
                }
                if (cancelled)
                {
                    break;
                }
            }
        }
    }

    scope (exit)
        done();
    new FillStoreTask().run(store, path, depth, base);
}

class Workers
{
    private bool busy;
    private Tid current;
    public void workStarted(Tid w)
    {
        current = w;
        busy = true;
    }

    public bool isBusy()
    {
        return busy;
    }

    public void cancel()
    {
        if (isBusy())
        {
            //      current.send(Task.Cancel());
        }
    }

    public void finish()
    {
        busy = false;
    }
}

/++
 + A Lister is a dopus list that shows usually file-like things.
 + Each lister has associated tasks that may run (even in parallel)
 + on the lister.
 + For this to work smoothly, the tasks must follow the following conventions:
 +  - they are not allowed to block
 +  - they are started in their on thread with spawnLinked
 +  - they should check from time to time for Cancel in the mailbox
 +  - to interact with the ui, they should take several delegates,
 +    that are then responsible to transport the data back to the ui thread if necessary
 +/

class Lister : ApplicationWindow
{
    Dopus app;
    Listers listers;
    NavigationStack navigationStack;
    SimpleActionGroup actions;

    bool isSource;
    bool isDestination;

    HeaderBar header;
    SpinButton depth;
    TreeView view;
    TreeViewColumn column;
    Status status;

    Workers workers;
    Tid currentListLoader;

    final Tid loadList()
    {
        currentListLoader.send(new shared Cancelled);
        status.working.start;
        auto store = new ListStore([GType.STRING]);
        shared done = delegate() {
            writeln("done");
            threadsAddIdleDelegate(delegate() {
                showAndSortStore(cast() store);
                status.working.stop;
                return false;
            });
        };
        return spawnLinked(&fillStoreTask, cast(shared) store, done,
                navigationStack.path, depth.getValueAsInt, navigationStack.path);
    }

    ListStore showAndSortStore(ListStore store)
    {
        view.setModel(store);
        store.setSortColumnId(0, SortType.ASCENDING);
        store.setSortFunc(0, &sortFunc, null, null);
        return store;
    }

    this(Dopus app, Listers listers_, string path_,
            NavigationStack navigationStack_ = new NavigationStack)
    {
        super(app);
        this.currentListLoader = thisTid;
        this.app = app;
        this.navigationStack = navigationStack_;
        this.listers = listers_;
        this.workers = new Workers();

        buildUi();

        visit(calculatePath(path_, "."));
    }

    private void buildUi()
    {
        header = new HeaderBar();
        header.setShowCloseButton(true);
        depth = new SpinButton(1, 100, 1);
        depth.setDigits(0);
        depth.setValue(1);
        depth.addOnValueChanged(delegate(SpinButton) {
            currentListLoader = loadList();
        });

        auto configButton = new MenuButton();
        configButton.setFocusOnClick(false);
        configButton.add(new Image("open-menu-symbolic", IconSize.MENU));
        auto popover = new PopoverMenu();
        auto table = new Table(2, 2, false);
        table.attach(new Label("depth"));
        table.attach(depth);
        table.attach(new Label("sort"));
        table.showAll;
        popover.add(table);
        configButton.setPopover(popover);
        header.packEnd(configButton);
        setTitlebar(header);

        auto accelGroup = new AccelGroup();
        addAccelGroup(accelGroup);
        addOnDestroy(&quitLister);
        view = new TreeView();
        view.setRulesHint(true);
        view.addOnStartInteractiveSearch(delegate(TreeView) {
            writeln("onStartinteractiveSearch");
            return false;
        });
        actions = new SimpleActionGroup();
        insertActionGroup("lister", actions);

        view.getSelection.setMode(SelectionMode.MULTIPLE);
        auto textCellRenderer = new CellRendererText();
        column = new TreeViewColumn("name", textCellRenderer, "text", 0);
        view.appendColumn(column);
        showAndSortStore(new ListStore([GType.STRING]));

        auto box = new Box(Orientation.VERTICAL, 5);
        box.packStart(new ScrolledWindow(view), true, true, 0);
        status = new Status(this);
        box.packStart(status, false, true, 0);
        add(box);
        showAll();
        listers.register(this);

        addOnFocusIn(delegate(Event event, Widget widget) {
            event = null;
            widget = null;
            listers.moveToFront(this);
            return false;
        });

        ListerActions.registerActions(this);

        wireShortcuts(app);
    }

    Lister refresh()
    {
        visit(navigationStack.path, false);
        return this;
    }

    private void wireShortcuts(Application app)
    {
        auto config = Loader.fromFile(".dopus.yaml").load();
        foreach (ref Node key, ref Node accelerators; config)
        {
            auto a = appender!(string[]);
            foreach (ref Node accelerator; accelerators)
            {
                a.put(accelerator.as!string);
            }
            app.setAccelsForAction(key.as!string, a.array);
        }
    }

    static string calculatePath(string path, string file)
    {
        return "%s/%s".format(path, file).absolutePath.buildNormalizedPath;
    }

    Lister setSource(bool source)
    {
        this.isSource = source;
        return updateTitle();
    }

    Lister setDestination(bool destination)
    {
        this.isDestination = destination;
        return updateTitle();
    }

    ~this()
    {
        writeln("~Lister");
    }

    void quitLister(Widget)
    {
        writeln("Bye Lister.");
        listers.unregister(this);
        close();
    }

    override string toString() const
    {
        return "Lister(path=%s)".format(navigationStack.path.shorten);
    }

    string state()
    {
        return isSource ? "[S]" : isDestination ? "[D]" : "[ ]";
    }

    Lister setPath(string path_, bool putToNavigationStack)
    {
        if (putToNavigationStack)
        {
            navigationStack.visit(path_);
        }
        updateTitle();
        listers.refresh();
        return this;
    }

    Lister updateTitle()
    {
        header.setTitle("%s - %s".format(state, navigationStack.path.shorten));
        return this;
    }

    final void visit(string path_, bool putToNavigationStack = true)
    {
        if (path_.isDir)
        {
            setPath(path_, putToNavigationStack);
            if (workers.isBusy())
            {
                info("workers busy ... cancelling current job");
                workers.cancel();
            }

            currentListLoader = loadList();
        }
        else
        {
            version (OSX)
            {
                const openCommand = "open";
            }
            else
            {
                const openCommand = "xdg-open";
            }

            auto command = [openCommand, path_];
            auto start = delegate() { infof("spawning process '%s'", command); };
            auto progress = delegate(string msg) { info(msg); };
            auto finished = delegate() {
                workers.finish();
                infof("process '%s' finished", command);
            };

            auto task = spawnLinked(&startProcess, cast(shared) command,
                    cast(shared) start, cast(shared) progress, cast(shared) finished);
            workers.workStarted(task);
        }
    }

    int getDepth() {
        return depth.getValueAsInt;
    }
    Lister setDepth(int d) {
        depth.setValue(d);
        return this;
    }
}

string getString(GtkTreeModel* model, GtkTreeIter* i, int column)
{
    auto iter = new TreeIter(i);
    iter.setModel(model);
    return iter.getValueString(column);
}

bool looksLikeDir(string a)
{
    return a.endsWith("/");
}

int compare(string a, string b)
{
    enum aIsSmallerThanB = -1;
    auto helper = function(string a, string b) {
        if (a == b)
        {
            return 0;
        }
        else if (a < b)
        {
            return aIsSmallerThanB;
        }
        else
        {
            return -aIsSmallerThanB;
        }
    };
    if (a.looksLikeDir)
    {
        if (b.looksLikeDir)
        {
            return helper(a, b);
        }
        else
        {
            return aIsSmallerThanB;
        }
    }
    else
    {
        if (b.looksLikeDir)
        {
            return -aIsSmallerThanB;
        }
        else
        {
            return helper(a, b);
        }
    }
}

extern (C) int sortFunc(GtkTreeModel* model, GtkTreeIter* a, GtkTreeIter* b, void* userData)
{
    return compare(model.getString(a, 0), model.getString(b, 0));
}

class Status : Box
{
    Lister lister;
    Spinner working;
    this(Lister lister)
    {
        super(Orientation.HORIZONTAL, 5);
        this.lister = lister;
        working = new Spinner();
        packStart(working, true, true, 0);
    }
}
