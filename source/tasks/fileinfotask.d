module tasks.fileinfotask;

import lister;
import task;
import std.concurrency;
import std.format;
import std.file;
import std.stdio;
import delay;
import core.time;


void fileInfoTask(string path, shared void delegate(string) clear, shared void delegate(string) progress, shared void delegate() finished) {
  class Result {
  public:
    const ulong size;
    const ulong nrOfFiles;
    const bool canceled;
    public this(ulong size_, ulong nrOfFiles_, bool canceled_) {
      size = size_;
      nrOfFiles = nrOfFiles_;
      canceled = canceled_;
    }
    Result cancel() {
      return new Result(size, nrOfFiles, true);
    }
    Result add(ulong size_) {
      return new Result(size + size_, nrOfFiles + 1, canceled);
    }
    override
    string toString() {
      return canceled ? "FileInfo got canceled" : "FileInfo { nrOfFiles=%s, size=%s }".format(nrOfFiles, size);
    }
  }

  Result collectFileInfo(string path) {
    auto res = new Result(0, 0, false);
    if (path.isDir()) {
      foreach (e; path.dirEntries(SpanMode.depth)) {
        bool canceled = false;
        if (e.isFile()) {
          res = res.add(e.getSize());
        }
        receiveTimeout(dur!("msecs")(-1), (Task.Cancel c) {
            res = res.cancel();
          });
        if (res.canceled) {
          return res;
        }
      }
      return res;
    } else {
      return res.add(path.getSize());
    }
  }

  clear(path);




  auto fileInfo = collectFileInfo(path);
  progress(fileInfo.toString());
  finished();
}


/*
class FileInfoTask : Task {
  bool canceled = false;
  this(shared Lister lister, string path) {
    super(lister, path);
  }

  override protected void cancel() shared {
    canceled = true;
  }

  override protected void backend() shared {
    auto fileInfo = collectFileInfo(path);
    writeln(fileInfo ? fileInfo.toString() : "FileInfo got canceld");
    ownerTid.send(Finished());
  }

  private FileInfo collectFileInfo(string path) shared {
    auto res = new FileInfo();
    if (path.isDir()) {
      foreach (e; path.dirEntries(SpanMode.depth)) {
        debugDelay();
        if (canceled) {
          return null;
        }
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
*/