module lister;
import std.concurrency;
import dlangui;
import std.file;
import std.path;
import core.time;
import std.stdio;
import task;
import tasks.fileinfotask;
import tasks.filllistertask;

bool waitForFinished() {
  while (true) {
    bool received = receiveTimeout(dur!"msecs"(100), (Task.Finished f) {});
    if (received) {
      return true;
    }
    writeln("waiting another timeout for the old task to finish");
  }
}

Task waitOrCancel(Tid backgroundTask) {
  bool finished = false;
  Task res = null;
  while (!finished) {
    writeln("waitOrCancel receiving");
    receive((Task.Finished f) {
        writeln("waitOrCancel finished");
        ownerTid.send(f);
        finished = true;
      },
      (Task.Cancel c) {
        writeln("sending cancel to backgroundtask");
        send(backgroundTask, c);
        finished = waitForFinished();
      },
      (Task t) {
        send(backgroundTask, Task.Cancel());
        finished = waitForFinished();
        res = t;
      });
  }
  return res;
}

class Blub {
  Tid tid;
  bool set = false;
  public bool isSet() {
    return set;
  }
  public void setTid(Tid tid_) {
    tid = tid_;
    set = true;
  }
  public Tid get() {
    assert(isSet());
    return tid;
  }
  public void clear() {
    set = false;
  }
}

import std.variant;

void listerWorker() {
  register("listerWorker", thisTid);
  writeln("lister is running on ", thisTid);
  Blub activeTask = new Blub();
  while (true) {
    if (activeTask.isSet()) {
      writeln("running mode");
      auto t = waitOrCancel(activeTask.get());
      activeTask.clear();
      if (t) {
        activeTask.setTid((cast(shared)t).start());
      }
    } else {
      writeln("idle mode");
      receive((shared Task t) {
          writeln("got a new task");
          activeTask.setTid(t.start());
        });
    }
  }
}

class Lister {

Tid worker;
  Window window;
  ListWidget fileList;
  StringListAdapter adapter;
  string path;
  this(string path_) {
    path = path_;
    window = Platform.instance.createWindow(to!dstring("Lister: " ~ path), null);
    adapter = new StringListAdapter();
    fileList = new ListWidget("filelist", Orientation.Vertical);
    fileList.adapter = adapter;
    fileList.itemClick = delegate(Widget src, int itemIndex) {
      writeln("itemClick: ");
      return true;
    };
    fileList.click = delegate(Widget w) {
      writeln("click: ");
      return true;
    };
    fileList.keyEvent = delegate(Widget w, KeyEvent e) {
      writeln("keyEvent: ", e.action.to!string, ", ", e.keyCode.to!string, ", ", e.text);
      auto h = path ~ "/" ~ adapter.items.get((cast(ListWidget)w).selectedItemIndex).to!string;
      if (e.text == "i"d) {
        send(worker, cast(shared)new FileInfoTask(cast(shared)this, h));
      } else if (e.text == "n"d) {
        visit(h);
      } else if (e.text == "c"d) {
        send(worker, Task.Cancel());
      } else if (e.keyCode == 8 && e.action == KeyAction.KeyUp) {
        writeln("parent dir");
        visit(path.dirName);
      }
      return true;
    };
    window.mainWidget = fileList;
    window.show();
    worker = spawn(&listerWorker);

    visit(path);
  }

  void visit(string path_) {
    if (path_.isDir) {
      auto absPath = buildNormalizedPath(absolutePath(path_));
      path = absPath;
      send(worker, cast(shared)new FillListerTask(cast(shared)this, absPath));
    } else {
      writeln("not a directory");
    }
  }

  void clear(string path) shared {
    (cast(Window)window).executeInUiThread({
        (cast(Window)window).windowCaption = path.to!dstring;
        (cast(ListWidget)fileList).selectedItemIndex = 0;
        (cast(StringListAdapter)adapter).clear();
      });
  }


  void add(DirEntry entry) shared {
    (cast(Window) window).executeInUiThread({
        auto s = entry.name.baseName.to!dstring;
        if (entry.isDir) {
          s ~= "/"d;
        }
        (cast(StringListAdapter)adapter).add(s);
        (cast(Window)window).invalidate();
      });
  }
}
