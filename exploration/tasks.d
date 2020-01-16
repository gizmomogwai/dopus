//module tasks;
//
//import lister;
//import task;
//import std.concurrency;
//import std.format;
//import std.file;
//import std.stdio;
//import delay;
//
// class FileInfo {
// public:
//   const ulong size;
//   const ulong nrOfFiles;
//   this(ulong size_=0, ulong nrOfFiles_=0) {
//     size = size_;
//     nrOfFiles = nrOfFiles_;
//   }

//   FileInfo add(ulong size_) {
//     return new FileInfo(size + size_, nrOfFiles+1);
//   }

//   override string toString() {
//     return "FileInfo { nrOfFiles=%s, size=%s }".format(nrOfFiles, size);
//   }
// }

// class FileInfoTask : Task {
//   bool canceled = false;
//   this(shared Lister lister, string path) {
//     super(lister, path);
//   }

//   override protected void cancel() shared {
//     canceled = true;
//   }

//   override protected void backend() shared {
//     auto fileInfo = collectFileInfo(path);
//     writeln(fileInfo ? fileInfo.toString() : "FileInfo got canceld");
//     ownerTid.send(Finished());
//   }

//   private FileInfo collectFileInfo(string path) shared {
//     auto res = new FileInfo();
//     if (path.isDir()) {
//       foreach (e; path.dirEntries(SpanMode.depth)) {
//         debugDelay();
//         if (canceled) {
//           return null;
//         }
//         if (e.isFile()) {
//           res = res.add(e.getSize());
//         }
//       }
//     } else {
//       res = res.add(path.getSize());
//     }
//     return res;
//   }
// }
