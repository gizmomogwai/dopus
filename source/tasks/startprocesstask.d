module tasks.startprocesstask;
import lister;
import task;
import std.process;
import std.string;

void startProcess(string path,
                  shared void delegate(string) clear,
                  shared void delegate(string) progress,
                  shared void delegate() finished) {
  clear(path);
  auto task = new Task();

  version (OSX) {
    auto openCommand = "open";
  } else {
    auto openCommand = "xdg-open";
  }
  auto pid = spawnProcess([openCommand, path]);
  auto res = pid.tryWait();
  while (res.terminated == false) {
    if (task.wasCanceled()) {
      break;
    }
    import core.thread;
    Thread.sleep(dur!"seconds"(1));
    res = pid.tryWait();
  }
  progress("running '%s' finished with status '%d'".format(path, res.status));
  finished();
}
