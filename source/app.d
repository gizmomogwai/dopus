module app;

import std.stdio;
import std.array;
import std.file;
import std.path;
import std.concurrency;

import core.thread;

import dlangui;

mixin APP_ENTRY_POINT;

class UpdateList : Thread {
  Window w;
  ListWidget lw;
  StringListAdapter adapter;
  this(Window w, ListWidget lw, StringListAdapter adapter) {
    super(&run);
    this.w = w;
    this.lw = lw;
    this.adapter = adapter;
  }
  private void run() {
    int i=0;
    while (true) {
      auto h = "teststring: "d ~ (i++).to!dstring;
      sleep(dur!("seconds")( 1 ));
      //      lw.executeInUiThread(delegate() {
      writeln(h);
      adapter.add(h);
      w.invalidate();
      //   });
    }
  }
}

struct Finished {
}

void collectFiles(string path, Tid parent) {
  foreach (DirEntry dirEntry; dirEntries(path, SpanMode.shallow)) {
    parent.send(dirEntry);
  }
  Finished f;
  parent.send(f);
}

void collectAndWaitForFinish(string path, shared Lister lister) {
  spawn(&collectFiles, path, thisTid());
  bool finished = false;
  while (!finished) {
    receive(

            (DirEntry entry) {
              lister.add(entry);
            },

            (Finished f)  {
              writeln("scan finished" ~ to!string(f));
              finished = true;
            }

            );
  }
}

class Lister {
  Tid lister;
  Window window;
  StringListAdapter adapter;

  this(string path) {
    window = Platform.instance.createWindow(to!dstring("Lister: " ~ path), null);
    adapter = new StringListAdapter();
    auto fileList = new ListWidget("filelist", Orientation.Vertical);
    fileList.adapter = adapter;
    window.mainWidget = fileList;
    window.show();
    lister = spawn(&collectAndWaitForFinish, path, cast(shared)this);
  }

  void add(DirEntry entry) shared {
    window.executeInUiThread(delegate() {
        writeln(entry.name);
        (cast(StringListAdapter)adapter).add(entry.name.baseName.to!dstring);
        (cast(Window)window).invalidate();
      });
  }
}

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {
  Lister[string] listers;
  //  Window[] w;
  foreach (string path; args[1..$]) {
    Lister l = new Lister(path);
    listers[path] = l;
    //    auto window = Platform.instance.createWindow(to!dstring("Lister: " ~ path), null);
    //  window.show();
    //  w ~= window;
    //Thread.sleep(dur!("seconds")(5));
  }
  /+
   for (int i=0; i<10; i++) {
   Window window = Platform.instance.createWindow(to!dstring("DlangUI example - HelloWorld" ~ to!string(i)), null);
   auto lw = new ListWidget("list1", Orientation.Vertical);
   window.mainWidget = lw;
   StringListAdapter stringList = new StringListAdapter();
   lw.adapter = stringList;
   stringList.add(to!dstring("test" ~ to!string(i)));
   window.show();
   }
   +/
  return Platform.instance.enterMessageLoop();
}
