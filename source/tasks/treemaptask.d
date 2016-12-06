module tasks.treemaptask;

import dlangui;
import std.algorithm;
import std.datetime;
import std.experimental.logger;
import std.file;
import std.path;
import std.variant;
import std.string;
import tm = treemap;
import treemapwidget;
import filenode;

auto treeMapTask(string path,
                 shared void delegate(string) clear,
                 shared void delegate(string) progress,
                 shared void delegate() finished) {
  clear(path);
  StopWatch sw;
  sw.start();
  auto fileNode = calcFileNode(DirEntry(path.asAbsolutePath.asNormalizedPath.to!string));
  sw.stop();
  info("getting file infos took: ", sw.peek().msecs, "ms");
  alias FileTreeMap = TreeMapWidget!FileNode;
  auto res = new FileTreeMap("filemap", fileNode, 3);
  res.addTreeMapFocusedListener((FileTreeMap.Maybe maybeNode) {
      maybeNode.visit!(
        (FileNode node) {
          info("selected node %s".format(node));
          progress("%s".format(node.getName()));
          //          text.text = ("%s (Byte)".format(node.getName())).to!dstring;//, node.getWeight().humanize)).to!dstring;
        },
        (typeof(null)) {
          progress("nothing focused");
        }
      )();
    });
  finished();
  return res;
}
