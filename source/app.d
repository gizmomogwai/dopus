module app;

import std.file;
import std.variant;
import std.path;
import std.stdio;
import dlangui;
import std.algorithm;
import std.range;

mixin APP_ENTRY_POINT;

import lister;
import tm = treemap;
import filenode;
import std.datetime;

Lister[string] listers;
/*
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

*/
Rect toUiRect(tm.Rect r) {
  return Rect(r.left(), r.top(), r.right(), r.bottom());
}

class Node {
  double size;
  Node[] childs;
  this(double size) {
    this.size = size;
  }
  this(Node[] childs) {
    this.childs = childs;
    this.size = childs.map!(v => v.size).sum;
  }
  override string toString() {
    return "Node { size: " ~ size.to!string ~ " }";
  }
}

interface OnTreeMapHandler {
  void onTreeMap(string name);
}

class FileNodeTreeMapWidget : Widget {
  FileNode rootNode;
  tm.TreeMap!FileNode treeMap = new tm.TreeMap!FileNode();
  FileNode currentFileNode;

  this(string id, FileNode rootNode) {
    super(id);
    this.rootNode = rootNode;
  }

  public Signal!OnTreeMapHandler onTreeMapFocused;
  public FileNodeTreeMapWidget addTreeMapFocusedListener(void delegate (string) listener) {
    onTreeMapFocused.connect(listener);
    return this;
  }

  override bool onMouseEvent(MouseEvent me) {
    auto r = treeMap.findFor(me.pos.x, me.pos.y);
    r.tryVisit!(
      (FileNode fileNode) { onTreeMapFocused(fileNode.getName()); },
      () {},
    )();
    return true;
  }

  override void layout(Rect r) {
    treeMap.layout(rootNode, tm.Rect(0, 0, r.width, r.height));
    super.layout(r);
  }

  override void onDraw(DrawBuf buf) {
    super.onDraw(buf);
    if (visibility != Visibility.Visible)
      return;

    auto rc = _pos;
    auto saver = ClipRectSaver(buf, rc);

    StopWatch sw;
    sw.start();
    //treeMap.layout(rootNode, tm.Rect(0, 0, width, height));
    sw.stop();

    auto font = FontManager.instance.getFont(25, FontWeight.Normal, false, FontFamily.SansSerif, "Arial");

    foreach(child; rootNode.childs) {
      auto r = treeMap.get(child).toUiRect();
      buf.drawFrame(r, 0xff00ff, Rect(1, 1, 1, 1), 0xa0a0a0);
      /+
      auto text = child.getName().to!dstring;
      auto textSize = font.textSize(text);
      buf.drawFrame(Rect(r.middlex-textSize.x/2, r.middley-textSize.y/2, r.middlex+textSize.x-textSize.x/2, r.middley+textSize.y-textSize.y/2),
                    0x606060,
                    Rect(1,1,1,1),
                    0xa0a0a0);
+/
      /+
      font.drawText(buf,
                    r.middlex-textSize.x/2,
                    r.middley-textSize.y/2,
                    text,
                    0xff0000);
+/
    }
  }
}
class NodeTreeMapWidget : Widget {
  Node node;
  this(string ID, Node n) {
    super(ID);
    this.node = n;
  }

  override void onDraw(DrawBuf buf) {
    super.onDraw(buf);
    if (visibility != Visibility.Visible)
      return;

    auto rc = _pos;
    auto saver = ClipRectSaver(buf, rc);

    StopWatch sw;
    sw.start();
    //  auto rects = new tm.TreeMap!Node().layout(node, tm.Rect(0, 0, width, height));
    sw.stop();
    auto font = FontManager.instance.getFont(25, FontWeight.Normal, false, FontFamily.SansSerif, "Arial");
/+
    foreach(Node child; node.childs) {
      auto r = rects[child].toUiRect();
      buf.drawFrame(r, 0xff00ff, Rect(1, 1, 1, 1), 0xa0a0a0);
      font.drawText(buf,
                    r.middlex,
                    r.middley,
                    child.size.to!dstring,
                    0xff0000);
    }
+/
  }
}

extern (C) int UIAppMain(string[] args) {
  auto window = Platform.instance.createWindow(to!dstring("treemap"), null);
  /*
  auto childs = [ 6.0, 6.0, 4.0, 3.0, 2.0, 2.0, 1.0 ].map!(v => new Node(v)).array();
  auto n = new Node(childs);
  auto w = new NodeTreeMapWidget("treemap", n).backgroundColor(0x000000).layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(Rect(10,10,10,10));
  */

  string path = args.length == 2 ? args[1] : ".";

  StopWatch sw;
  sw.start();
  auto fileNode = calcFileNode(DirEntry(path.asAbsolutePath.asNormalizedPath.to!string));
  sw.stop();
  writeln("getting file infos took: ", sw.peek().msecs, "ms");

  auto vl = new VerticalLayout("vl");
  vl.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
  auto w = new FileNodeTreeMapWidget("filemap", fileNode);
  auto text = new TextWidget("label", "no selection".to!dstring);
  text.fontSize(32);
  vl.addChild(w);
  vl.addChild(text);
  w.backgroundColor(0x000000).layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(Rect(10, 10, 10, 10));
  //  w.addTreeMapFocusedListener(delegate void(string name) {writeln(name);});
  w.addTreeMapFocusedListener(delegate void(string name) {
      text.text = name.to!dstring;
    });

  window.mainWidget = vl;
  window.show();
  return Platform.instance.enterMessageLoop();
}

