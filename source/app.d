module app;

import std.stdio;
import std.array;
import std.file;
import std.path;
import std.concurrency;
import std.format;

import core.thread;

import dlangui;

mixin APP_ENTRY_POINT;

struct Finished {
}

void listFiles(string path, Tid parent) {
  foreach (DirEntry dirEntry; dirEntries(path, SpanMode.shallow)) {
    parent.send(dirEntry);
  }
  Finished f;
  parent.send(f);
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
void collectFileInfo(string path) {
  writeln("collectFileInfo started for ", path);
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
  writeln("file info: ", res);
  writeln("collectFileInfo finished");
}
void showInfo(string path) {
  writeln("show info for ", path);
  spawn(&collectFileInfo, path);
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
        showInfo(h);
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
    
    lister = spawn(&mySpawn, &listFiles, absPath, cast(shared)&add);
  }

  void add(DirEntry entry) {
    window.executeInUiThread(delegate() {
        auto s = entry.name.baseName.to!dstring;
        if (entry.isDir) {
          s ~= "/"d;
        }
        adapter.add(s);
        window.invalidate();
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

void threadedStuff() {
  class Stuff {
    public int i;
  }
  class MyThread : Thread {
    TextWidget tw;
    Window w;
    this(TextWidget tw_, Window w_) {
      super(&run);
      tw = tw_;
      w = w_;
    }

    private void run() {
      Stuff s = new Stuff;
      s.i = 10;
      for (int i=0; i<10; i++) {
        s.i++;
        tw.executeInUiThread(delegate() {
            tw.text = "test"d ~ to!dstring(s.i);
            tw.invalidate();
            w.invalidate();
          });
        Thread.sleep(dur!("seconds")(2));
      }
    }
  }

  Window window = Platform.instance.createWindow(to!dstring("DlangUI example - HelloWorld"), null);
  TextWidget tw = new TextWidget("text1");
  tw.text = "test"d;
  new MyThread(tw, window).start();
  auto vl = new VerticalLayout("layout");
  vl.addChild(tw);
  window.mainWidget = vl;
  window.show();
}

void spawned(TextWidget tw, Window w) {
  (cast(TextWidget)tw).executeInUiThread(delegate() {
      (cast(TextWidget)tw).text = "test1"d;
      (cast(TextWidget)tw).invalidate();
      (cast(TextWidget)w).invalidate();
    });
}
//void spawnStuff() {
//  Window window = Platform.instance.createWindow(to!dstring("DlangUI example - HelloWorld"), null);
//  TextWidget tw = new TextWidget("text1");
//  tw.text = "test"d;
//
//  mySpawn(&spawned, tw, window);
//  window.show();
//}

extern (C) int UIAppMain(string[] args) {
  fileLister(args);
  //threadedStuff();
  //spawnStuff();
  return Platform.instance.enterMessageLoop();
}
