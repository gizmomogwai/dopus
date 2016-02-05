module app;

import std.stdio;
import std.array;
import std.file;
import std.path;
import std.concurrency;
import std.format;

import dlangui;

mixin APP_ENTRY_POINT;

struct Finished {
}

void mySpawn(void function(string, Tid) f, string path, void delegate(DirEntry entry) forward) {
  auto child = spawn(f, path, thisTid());
  bool finished = false;
  while (!finished) {
    receive(
            forward,
            (Finished f) {
              writeln("finished");
              finished = true;
            });
  }
}

class FileInfo {
public:
  const ulong size;
  const ulong nrOfFiles;
  this(ulong size_=0, ulong nrOfFiles_=0) {
    size = size_;
    nrOfFiles = nrOfFiles_;
  }

  FileInfo add(ulong size_) {
    return new FileInfo(size + size_, nrOfFiles+1);
  }

  override string toString() {
    return "FileInfo { nrOfFiles=%s, size=%s }".format(nrOfFiles, size);
  }
}


shared class BackgroundTask {
  Tid task;

  shared FileLister fileLister;

  string path;

  this(shared FileLister fileLister_, string path_) {
    fileLister = fileLister_;
    path = path_;
  }

  private static void runBackgroundTask(shared BackgroundTask t) {
    t.run();
  }

  private static void waitForBackgroundTask(shared BackgroundTask t) {
    auto child = spawn(&runBackgroundTask, t);
    bool finished = false;
    while (!finished) {
      finished = t.receiveMessages();
    }
  }

  public void start() {
    spawn(&waitForBackgroundTask, cast(shared)this);
  }

  public bool receiveMessages() {
    receive(
            (Finished f) {
              writeln("finished");
              return true;}
            );
    return false;
  }

  public abstract void run() shared;
}

class FileInfoBackgroundTask : BackgroundTask {

  this(shared FileLister lister, string path) {
    super(lister, path);
  }

  public override void run() shared {
    auto fileInfo = collectFileInfo(path);
    writeln(fileInfo);
    ownerTid.send(Finished());
  }

  private FileInfo collectFileInfo(string path) shared {
    auto res = new FileInfo();
    if (path.isDir()) {
      foreach (DirEntry e; path.dirEntries(SpanMode.depth)) {
        if (e.isFile()) {
          res = res.add(e.getSize());
        }
      }
    } else {
      res = res.add(path.getSize());
    }
    return res;
  }
}

class FillListerBackgroundTask : BackgroundTask {
  this(shared FileLister lister, string path) {
    super(lister, path);
  }

  public override void run() shared {
    foreach (DirEntry dirEntry; dirEntries(path, SpanMode.shallow)) {
      ownerTid.send(dirEntry);
    }
    Finished f;
    ownerTid.send(f);
  }

  public override bool receiveMessages() {
    receive(
            (DirEntry e) {
              fileLister.add(e);
            },
            (Finished f) {
              writeln("filllister finished");
              return true;
            },
            );
    return false;
  }
}

class FileLister {
  Tid lister;
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
        new shared(FileInfoBackgroundTask)(cast(shared)this, h).start();
      } else if (e.text == "n"d) {
        visit(h);
      } else if (e.keyCode == 8 && e.action == KeyAction.KeyUp) {
        visit(dirName(path));
      }
      return true;
    };
    window.mainWidget = fileList;
    window.show();
    visit(path);
  }

  void visit(string path_) {
    writeln("read: ", path_);
    auto absPath = buildNormalizedPath(absolutePath(path_));
    writeln("absPath: ", absPath);
    path = absPath;

    window.windowCaption = path.to!dstring;
    fileList.selectedItemIndex = 0;
    adapter.clear();

    new shared(FillListerBackgroundTask)(cast(shared)this, absPath).start();
  }

  void add(DirEntry entry) shared {
    (cast(Window) window).executeInUiThread(delegate() {
        auto s = entry.name.baseName.to!dstring;
        if (entry.isDir) {
          s ~= "/"d;
        }
        (cast(StringListAdapter)adapter).add(s);
        (cast(Window)window).invalidate();
      });
  }
}

FileLister[string] listers;
void fileLister(string[] args) {
  foreach (string path; args[1..$]) {
    auto l = new FileLister(path);
    listers[path] = l;
  }
}

void spawned(TextWidget tw, Window w) {
  (cast(TextWidget)tw).executeInUiThread(delegate() {
      (cast(TextWidget)tw).text = "test1"d;
      (cast(TextWidget)tw).invalidate();
      (cast(TextWidget)w).invalidate();
    });
}

extern (C) int UIAppMain(string[] args) {
  fileLister(args);
  return Platform.instance.enterMessageLoop();
}
