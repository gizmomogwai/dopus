module tasks.treemaptask;

import dlangui;
import filenode;
import std.algorithm;
import std.datetime;
import std.experimental.logger;
import std.file;
import std.path;
import std.string;
import std.variant;
import tm = treemap;
import treemapwidget;

alias FileTreeMap = TreeMapWidget!FileNode;
auto treeMapTaskInit(string)
{
    auto res = new FileTreeMap("filemap", 3);
    res.addTreeMapFocusedListener((FileTreeMap.Maybe maybeNode) {
        maybeNode.visit!((FileNode node) {
            info("selected node %s".format(node));
            progress("%s".format(node.getName()));
            //          text.text = ("%s (Byte)".format(node.getName())).to!dstring;//, node.getWeight().humanize)).to!dstring;
        }, (typeof(null)) { progress("nothing focused"); })();
    });
    return res;
}

void treeMapTask(string, shared void delegate(string),
        shared void delegate(FileNode, string), shared void delegate())
{

    /++
  clear(path);
//  StopWatch sw;
//  sw.start();
  auto fileNode = calcFileNode(DirEntry(path.asAbsolutePath.asNormalizedPath.to!string));
//  progress
//  sw.stop();
  //info("getting file infos took: ", sw.peek().msecs, "ms");
  finished();
  return res;
++/
}
