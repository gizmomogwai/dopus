module dopus.tasks.filllistertask;

import dopus.lister;
import dopus.task;

import std.concurrency;
import std.format;
import std.file;
import std.stdio;
import std.experimental.logger;
import core.time;

void fillListerTask(string path, shared void delegate(string) clear,
        shared void delegate(DirEntry) add, shared void delegate() finished)
{
    auto task = new Task();
    clear(path);

    foreach (dirEntry; dirEntries(path, SpanMode.shallow))
    {
        add(dirEntry);

        if (task.wasCanceled())
        {
            break;
        }

    }
    finished();
}
/*
class FillListerTask : Task {
  private bool canceled = false;
  this(shared Lister lister, string path) {
    super(lister, path);
  }

  override protected void cancel() shared {
    canceled = true;
  }

  public override void backend() shared {
    register("FillListerBackgroundTask.run", thisTid);
    lister.clear(path);
    foreach (dirEntry; dirEntries(path, SpanMode.shallow)) {
      writeln("canceled: ", canceled);
      if (canceled) {
        break;
      }
      debugDelay();
      lister.add(dirEntry);
    }
    Task.Finished f;
    writeln("fill finished sending Finished back to ", ownerTid);
    send(ownerTid, f);
  }

  public override bool receiveMessages() shared {
    writeln("FillListerBackgroundtask.receiveMessages on ", thisTid);
    bool res = true;
    receive(
            (DirEntry e) {
              lister.add(e);
            },
            (Task.Cancel c) {
              writeln("fillister canceled");
              canceled = true;
            },
            (Task.Finished f) {
              writeln("filllister finished");
              res = false;
            }
            );
    return res;
  }
}
*/