module dopus.tasks.fileinfotask;

import dopus.lister;
import dopus.task;
import std.concurrency;
import std.file;
import std.format;
import std.stdio;

void fileInfoTask(string path, shared void delegate(string) clear,
        shared void delegate(string) progress, shared void delegate() finished)
{
    class Result
    {
    public:
        const ulong size;
        const ulong nrOfFiles;
        const bool canceled;
        this(ulong size_, ulong nrOfFiles_, bool canceled_)
        {
            size = size_;
            nrOfFiles = nrOfFiles_;
            canceled = canceled_;
        }

        Result cancel()
        {
            return new Result(size, nrOfFiles, true);
        }

        Result add(ulong size_)
        {
            return new Result(size + size_, nrOfFiles + 1, canceled);
        }

        override string toString() const
        {
            return canceled ? "FileInfo got canceled" : "FileInfo { nrOfFiles=%s, size=%s }".format(nrOfFiles,
                    size);
        }
    }

    Result collectFileInfo(string path)
    {
        auto task = new Task();
        auto res = new Result(0, 0, false);
        if (path.isDir())
        {
            foreach (e; path.dirEntries(SpanMode.depth))
            {
                if (e.isFile())
                {
                    res = res.add(e.getSize());
                }
                if (task.wasCanceled())
                {
                    res = res.cancel();
                    return res;
                }
            }
            return res;
        }
        else
        {
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
