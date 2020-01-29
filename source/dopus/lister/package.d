module dopus.lister;

//import tasks.fileinfotask;
//import tasks.testarchivetask;
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
import gtk.ListStore;
import gtk.MainWindow;
import gtk.ScrolledWindow;
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

void fillListerTask(shared(Lister) lister, string path)
{
    lister.clear();
    foreach (dirEntry; dirEntries(path, SpanMode.shallow))
    {
        lister.addEntry(dirEntry);
    }
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

class Status : Button
{
    Lister lister;
    this(Lister lister)
    {
        super("status");
        this.lister = lister;
        addOnClicked(delegate(Button) { writeln("Clicked"); });
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

    TreeView view;
    TreeViewColumn column;
    ListStore store;

    Workers workers;

    this(Dopus app, Listers listers_, string path_,
            NavigationStack navigationStack_ = new NavigationStack)
    {
        super(app);
        this.app = app;
        navigationStack = navigationStack_;
        listers = listers_;
        workers = new Workers();

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
        store = new ListStore([GType.STRING]);
        store.setSortColumnId(0, SortType.ASCENDING);
        store.setSortFunc(0, &sortFunc, null, null);

        view.setModel(store);
        auto box = new Box(Orientation.VERTICAL, 5);
        box.packStart(new ScrolledWindow(view), true, true, 0);
        box.packStart(new Status(this), false, true, 0);
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

        visit(calculatePath(path_, "."));
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
        setTitle("%s - %s".format(state, navigationStack.path.shorten));
        return this;
    }

    /+
    fileList.keyEvent = (Widget w, KeyEvent e) {
      // info("keyEvent: ", e.action.to!string, ", ", e.keyCode.to!string, ", ", e.text);
      auto h = path ~ "/" ~ adapter.items.get((cast(ListWidget)w).selectedItemIndex).to!string;
      switch (e.text) {
      case "c"d:
          workers.cancel();
          break;
      case "i"d:
          fileInfo(h);
          break;
      case "n"d:
          window.executeInUiThread({
                  new Lister(h);
              });
          break;
      case "t"d:
          testArchive(h);
          break;
      case "x"d:
          h(visitg);
          break;
      default:
          break;
      }

      if (e.keyCode == 8 && e.action== KeyAction.KeyUp) {
          visit(path.dirName);
      }

      return true;
    };
+/
    /*
  void treeView(string path) {
    if (path.isDir) {
      auto window = Platform.instance.createWindow("treemap '%s'".format(path).to!dstring, null);
      auto vl = new VerticalLayout("vl");
      vl.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

      auto text = new TextWidget("label", "no selection".to!dstring);
      text.fontSize(32);
      auto treemap = treeMapTaskInit(path);
      treemap.backgroundColor(0x000000).layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(Rect(10, 10, 10, 10));
      auto treeViewClear = delegate(string s) {
      };
      auto treeViewProgress = delegate(FileTreeMap treeMap, string s) {
        //text.text = s.to!dstring;
      };
      auto treeViewFinished = delegate() {
        info("finished");
      };
      auto task = treeMapTask(path,
                                 cast(shared)treeViewClear,
                                 cast(shared)treeViewProgress,
                                 cast(shared)treeViewFinished);

      vl.addChild(treemap);
      vl.addChild(text);

      window.mainWidget = vl;
      window.show();
    }
  }
  */
    /+
  void testArchive(string path) {
    if (path.isFile) {
      auto testArchiveClear = delegate(string path) {
        infof("testing '%s'", path);
      };

      auto testArchiveProgress = delegate(string msg) {
        info(msg);
      };
      auto testArchiveFinished= delegate() {
        infof("testing '%s' finished", path);
      };
      auto task = spawnLinked(&testArchiveTask, path,
                              cast(shared)testArchiveClear,
                              cast(shared)testArchiveProgress,
                              cast(shared)testArchiveFinished);
      workers.workStarted(task);
    }
  }
+/
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

            spawnLinked(&fillListerTask, cast(shared) this, navigationStack.path);
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
    /+
  void fileInfo(string path) {
    //if (workers.isBusy()) {
    //workers.cancel();
    //}

    auto fileInfoClear = delegate(string path) {
      info("info for '", path, "'");
    };
    auto fileInfoProgress = delegate(string msg) {
      info("Result of fileInfo: ", msg);
    };
    auto fileInfoFinished = delegate() {
      workers.finish();
//      window.invalidate();
    };

    auto task = spawnLinked(&fileInfoTask, path,
                            cast(shared)fileInfoClear,
                            cast(shared)fileInfoProgress,
                            cast(shared)fileInfoFinished);
    workers.workStarted(task);
  }
+/

    shared(Lister) clear() shared
    {
        threadsAddIdleDelegate(delegate() { (cast() store).clear(); return false; });
        return this;
    }

    void clear(string path)
    {
        path = null;
    }

    shared(Lister) addEntry(DirEntry entry) shared
    {
        threadsAddIdleDelegate(delegate() {
            (cast() this).addEntry(entry);
            return false;
        });
        return this;
    }

    Lister addEntry(DirEntry entry)
    {
        auto s = entry.name.baseName;
        if (entry.isDir)
        {
            s ~= "/";
        }
        store.setValue(store.createIter(), 0, s);
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
