module dopus.lister;

import std.concurrency;
import std.file;
import std.path;
import core.time;
import std.stdio;
import std.string;

import dopus.task;
import dopus.listers;

//import tasks.fileinfotask;
import dopus.tasks.filllistertask;

//import tasks.testarchivetask;
//import tasks.startprocesstask;
import std.experimental.logger;
import std.conv;
import std.string;

import gtk.MainWindow;
import gtk.Widget;

import gtk.Button;
import gtk.Box;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.ListStore;
import gtk.CellRendererText;
import gtk.ScrolledWindow;

import gio.SimpleAction;
import gio.SimpleActionGroup;
import gtk.AccelGroup;
import gtk.ApplicationWindow;
import gtk.Application;

import gtkd.x.threads;
import gtkd.x.treeselection;

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
    Listers listers;
    string path;
    bool isSource;
    bool isDestination;
    Workers workers;

    TreeView view;
    TreeViewColumn column;
    ListStore store;
    static int count = 0;
    int id;
    string[] history;
    this(Application app, Listers listers_, string path_)
    {
        super(app);
        id = count++;
        listers = listers_;
        workers = new Workers();

        auto accelGroup = new AccelGroup();
        addAccelGroup(accelGroup);
        addOnDestroy(&quitLister);
        view = new TreeView();
        view.setRulesHint(true);

        auto actions = new SimpleActionGroup();
        insertActionGroup("lister", actions);

        view.getSelection.setMode(SelectionMode.MULTIPLE);
        auto textCellRenderer = new CellRendererText();
        column = new TreeViewColumn("name", textCellRenderer, "text", 0);
        view.appendColumn(column);
        store = new ListStore([GType.STRING]);
        view.setModel(store);

        addNewAction(app, listers, actions);
        addExecuteAction(app, listers, actions);
        addParentAction(app, listers, actions);
        addShowHistoryAction(app, listers, actions);

        auto newInSubfolderAction = new SimpleAction("newInSubfolder", null);
        newInSubfolderAction.addOnActivate(delegate(Variant, SimpleAction) {
            import std.file;

            foreach (file; view.getSelection.getSelection)
            {
                auto newPath = buildNormalizedPath("%s/%s".format(path, file));
                writeln(1);
                if (newPath.isDir)
                {
                    new Lister(app, listers, newPath);
                }
            }
        });
        actions.insert(newInSubfolderAction);
        app.setAccelsForAction("lister.newInSubfolder", ["<Control><Shift>n"]);

        add(new ScrolledWindow(view));
        visit(calculatePath(path_, "."));
        showAll();
        listers.register(this);
        addOnSetFocus(delegate(Widget, Window) {
            writeln("widget focused ", this);
            writeln("lister: ", this);
            listers.moveToFront(this);
        });
    }

    private void addNewAction(Application app, Listers listers, SimpleActionGroup actions)
    {
        auto newAction = new SimpleAction("new", null);
        newAction.addOnActivate(delegate(Variant, SimpleAction) {
            new Lister(app, listers, path);
        });
        actions.insert(newAction);
        app.setAccelsForAction("lister.new", ["<Control>n"]);
    }

    private string calculatePath(string path, string file)
    {
        return "%s/%s".format(path, file).absolutePath.buildNormalizedPath;

    }

    private void addExecuteAction(Application app, Listers listers, SimpleActionGroup actions)
    {
        auto action = new SimpleAction("execute", null);
        action.addOnActivate(delegate(Variant, SimpleAction) {
            foreach (file; view.getSelection.getSelection)
            {
                import std.algorithm.searching;

                if (file.endsWith("/"))
                {
                    file = file[0 .. $ - 1];
                }
                file = calculatePath(path, file);
                writeln(2);
                if (file.isDir)
                {
                    visit(file);
                    break;
                }
                else
                {
                    visit(file);
                }
            }
        });
        actions.insert(action);
        app.setAccelsForAction("lister.execute", ["Return"]);
    }

    private void addParentAction(Application app, Listers listers, SimpleActionGroup actions)
    {
        auto action = new SimpleAction("parent", null);
        action.addOnActivate(delegate(Variant, SimpleAction) {
            auto file = calculatePath(path, "..");
            visit(file);
        });
        actions.insert(action);
        app.setAccelsForAction("lister.parent", ["<Control>p"]);
    }

    private void addShowHistoryAction(Application app, Listers listers, SimpleActionGroup actions)
    {
        auto action = new SimpleAction("history", null);
        action.addOnActivate(delegate(Variant, SimpleAction) {
            foreach (idx, entry; history)
            {
                writeln(idx, ": ", entry);
            }
        });
        actions.insert(action);
        app.setAccelsForAction("lister.history", ["<Control>h"]);

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
        return "%s Lister(path=%s)".format(state, path);
    }

    string state()
    {
        return isSource ? "SRC" : isDestination ? "DST" : "";
    }

    Lister setPath(string path_)
    {
        path = path_;
        history ~= path;
        return updateTitle();
    }

    Lister updateTitle()
    {
        setTitle("%s - %s".format(state, path));
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
    void visit(string path_)
    {
        writeln("visiting ", path_);
        /+
      writeln("1");
      Cancellable cancellable = new Cancellable;
      writeln("2");
      Task t = new Task(this, cancellable, &visitCallback, cast(void*)this);
      writeln("3");
      t.runInThread(&visitThread);
+/
        writeln(3);
        if (path_.isDir)
        {
            setPath(path_);
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
            auto task = spawnLinked(&fillListerTask, path, cast(shared) fillListerClear,
                    cast(shared) fillListerProgress, cast(shared) fillListerFinished);
            //      workers.workStarted(task);
        }
        else
        {
            auto startProcessClear = delegate(string path) {
                infof("starting '%s'", path);
            };
            auto startProcessProgress = delegate(string msg) { info(msg); };
            auto startProcessFinished = delegate() {
                workers.finish();
                info("startProcess finished");
            };
            //      auto task = spawnLinked(&startProcess, absPath,
            //                            cast(shared)startProcessClear,
            //                              cast(shared)startProcessProgress,
            //                              cast(shared)startProcessFinished);
            //      workers.workStarted(task);
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
        writeln(4);
        if (entry.isDir)
        {
            s ~= "/";
        }
        writeln("adding ", s);
        store.setValue(store.createIter(), 0, s);
    }
}
