import std.stdio;
import std.array;
import std.file;

void main(string[] args) {
  writeln(args.join("\n"));
  foreach (DirEntry e; dirEntries(args[1], SpanMode.shallow)) {
    writeln(e.name, "\t", e.timeLastAccessed);
  }
}
