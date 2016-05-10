module app;

import std.stdio;
import dlangui;

mixin APP_ENTRY_POINT;

import lister;

Lister[string] listers;

extern (C) int UIAppMain(string[] args) {
  if (args.length == 1) {
    writeln("Usage dopus dirname");
    return 1;
  }
  foreach (path; args[1..$]) {
    auto l = new Lister(path);
    listers[path] = l;
  }
  return Platform.instance.enterMessageLoop();
}
