module dopus.lister;

//import tasks.fileinfotask;
//import tasks.testarchivetask;
import core.time;
import dopus.lister.actions;
import dopus.listers;
import dopus.navigationstack;
import dopus.task;
import dopus.tasks.filllistertask;
import dopus.tasks.startprocesstask;
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

import dopus.navigationstack;

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
    Application app;
    Listers listers;
    NavigationStack navigationStack;
    SimpleActionGroup actions;

    bool isSource;
    bool isDestination;

    TreeView view;
    TreeViewColumn column;
    ListStore store;

    Workers workers;

    this(Application app, Listers listers_, string path_,
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
        view.setModel(store);
        add(new ScrolledWindow(view));
        visit(calculatePath(path_, "."));
        showAll();
        listers.register(this);
        addOnActivateFocus(delegate(Window) { writeln("onActivateFocus");listers.moveToFront(this); });
        addOnSetFocusChild(delegate(Widget, Window) { writeln("onSetFocusChild");});
        addOnFocusIn(delegate(Event e, Widget w) { writeln("onFocusIn", e, w); listers.moveToFront(this); return false;});
        view.addOnSetFocusChild(delegate(Widget, Window) { writeln("onSetFocusChild");});

        ListerActions.registerActions(this);

        wireShortcuts(app);
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

    void quitLister(Widget widget)
    {
        writeln("Bye Lister.");
        listers.unregister(this);
        close();
    }

    override string toString()
    {
        return "%s Lister(path=%s)".format(state, navigationStack.path);
    }

    string state()
    {
        return isSource ? "SRC" : isDestination ? "DST" : "   ";
    }

    Lister setPath(string path_, bool putToNavigationStack)
    {
        if (putToNavigationStack)
        {
            navigationStack.visit(path_);
        }
        return updateTitle();
    }

    Lister updateTitle()
    {
        setTitle("%s - %s".format(state, navigationStack.path));
        return this;
    }

    /+
    fileList.itemClick = (Widget src, int itemIndex) {
      info("itemClick: ");
      return true;
    };
    fileList.click = (Widget w) {
      info("click: ");
      return true;
    };
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
    void visit(string path_, bool putToNavigationStack = true)
    {
        /+
      Cancellable cancellable = new Cancellable;
      Task t = new Task(this, cancellable, &visitCallback, cast(void*)this);
      t.runInThread(&visitThread);
+/
        if (path_.isDir)
        {
            setPath(path_, putToNavigationStack);
            if (workers.isBusy())
            {
                info("workers busy ... cancelling current job");
                workers.cancel();
            }

            auto fillListerClear = (string path) {
                threadsAddIdleDelegate(delegate() { store.clear(); return false; });
            };
            auto fillListerProgress = (DirEntry entry) {
                threadsAddIdleDelegate(delegate() {
                    addEntry(entry);
                    return false;
                });
            };
            auto fillListerFinished = () {
                workers.finish();
                //        window.invalidate();
            };
            auto task = spawnLinked(&fillListerTask, navigationStack.path, cast(shared) fillListerClear,
                    cast(shared) fillListerProgress, cast(shared) fillListerFinished);
            //      workers.workStarted(task);
        }
        else
        {
            version (OSX)
            {
                auto openCommand = "open";
            }
            else
            {
                auto openCommand = "xdg-open";
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
    void clear(string path)
    {
        /+
    window.executeInUiThread({
        window.windowCaption = path.to!dstring;
        fileList.selectedItemIndex = 0;
        adapter.clear();
      });
+/

    }

    void addEntry(DirEntry entry)
    {
        auto s = entry.name.baseName;
        if (entry.isDir)
        {
            s ~= "/";
        }
        store.setValue(store.createIter(), 0, s);
    }
}
