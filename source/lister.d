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
import std.experimental.logger;

class Workers {
  private bool busy;
  private Tid current;
  public void workStarted(Tid w) {
    current = w;
    busy = true;
  }
  public bool isBusy() {
    return busy;
  }
  public void cancel() {
    if (isBusy()) {
      current.send(Task.Cancel());
    }
  }
  public void finish() {
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
 +/
class Lister {
  Window window;
  ListWidget fileList;
  StringListAdapter adapter;
  string path;

  Workers workers;

  this(string path_) {
    path = path_;
    workers = new Workers();
    window = Platform.instance.createWindow(to!dstring("Lister: " ~ path), null);
    adapter = new StringListAdapter();
    fileList = new ListWidget("filelist", Orientation.Vertical);
    fileList.adapter = adapter;
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
      if (e.text == "i"d) {
        fileInfo(h);
      } else if (e.text == "n"d) {
        visit(h);
      } else if (e.text == "c"d) {
        workers.cancel();
      } else if (e.keyCode == 8 && e.action == KeyAction.KeyUp) {
        visit(path.dirName);
      }
      return true;
    };
    window.mainWidget = fileList;
    window.show();

    visit(path);
  }

  void visit(string path_) {
    if (path_.isDir) {
      if (workers.isBusy()) {
        info("workers busy ... cancelling current job");
        workers.cancel();
      }

      auto absPath = buildNormalizedPath(absolutePath(path_));
      path = absPath;
      auto fillListerClear = (string path) {
        clear(path);
      };
      auto fillListerProgress = (DirEntry entry) {
        add(entry);
      };
      auto fillListerFinished = () {
        workers.finish();
      };
      auto task = spawnLinked(&fillListerTask, absPath,
                              cast(shared)fillListerClear,
                              cast(shared)fillListerProgress,
                              cast(shared)fillListerFinished);
      workers.workStarted(task);
    } else {
      info("not a directory");
    }
  }

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
    };

    auto task = spawnLinked(&fileInfoTask, path,
                            cast(shared)fileInfoClear,
                            cast(shared)fileInfoProgress,
                            cast(shared)fileInfoFinished);
    workers.workStarted(task);
  }

  void clear(string path) {
    window.executeInUiThread({
        window.windowCaption = path.to!dstring;
        fileList.selectedItemIndex = 0;
        adapter.clear();
      });
  }

  void add(DirEntry entry) {
    window.executeInUiThread({
        auto s = entry.name.baseName.to!dstring;
        if (entry.isDir) {
          s ~= "/"d;
        }
        adapter.add(s);
        window.invalidate();
      });
  }
}
