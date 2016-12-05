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

/*
Rect toUiRect(tm.Rect r) {
  return Rect(cast(int)r.left(),
              cast(int)r.top(),
              cast(int)r.right(),
              cast(int)r.bottom());
}

class Node {
  string name;
  double size;
  Node[] childs;
  this(string name, double size) {
    this.name = name;
    this.size = size;
  }
  this(string name, Node[] childs) {
    this(name, childs.map!(v => v.size).sum);
    this.childs = childs;
  }
  override string toString() {
    return "Node { size: " ~ size.to!string ~ " }";
  }
}


class TreeMapWidget(Node) : Widget {
  interface OnTreeMapHandler {
    void onTreeMap(Node node);
  }

  tm.TreeMap!Node treeMap;
  Node currentFileNode;

  this(string id, Node rootNode) {
    super(id);
    this.treeMap = new tm.TreeMap!Node(rootNode);
  }

  public Signal!OnTreeMapHandler onTreeMapFocused;
  public auto addTreeMapFocusedListener(void delegate (Node) listener) {
    onTreeMapFocused.connect(listener);
    return this;
  }

  override bool onMouseEvent(MouseEvent me) {
    auto r = treeMap.findFor(me.pos.x, me.pos.y);
    r.tryVisit!(
      (Node node) { onTreeMapFocused(node); },
      () {},
    )();
    return true;
  }

  override void layout(Rect r) {
    StopWatch sw;
    sw.start();
    treeMap.layout(tm.Rect(0, 0, r.width, r.height));
    sw.stop();
    super.layout(r);
  }

  override void onDraw(DrawBuf buf) {
    super.onDraw(buf);
    if (visibility != Visibility.Visible) {
      return;
    }

    auto rc = _pos;
    auto saver = ClipRectSaver(buf, rc);

    auto font = FontManager.instance.getFont(25, FontWeight.Normal, false, FontFamily.SansSerif, "Arial");

    foreach(child; treeMap.rootNode.childs) {
      buf.drawFrame(treeMap.get(child).toUiRect(), 0xff00ff, Rect(1, 1, 1, 1), 0xa0a0a0);
    }
  }
}

auto doNodeExample(ref TextWidget text) {
  auto childs = [ 6.0, 6.0, 4.0, 3.0, 2.0, 2.0, 1.0 ].map!(v => new Node(v.to!string, v)).array();
  auto n = new Node("parent", childs);
  auto w = new TreeMapWidget!Node("treemap", n);
  w.addTreeMapFocusedListener((Node node) {
      text.text = node.name.to!dstring;
    });
  return w;
}

string humanize(ulong v) {
  auto units = ["", "k", "m", "g"];
  int idx = 0;
  while (v / 1024 > 0) {
    idx++;
    v /= 1024;
  }
  return v.to!string ~ units[idx];
}

auto doFileExample(string[] args, ref TextWidget text) {
  auto path = args.length == 2 ? args[1] : ".";
  StopWatch sw;
  sw.start();
  auto fileNode = calcFileNode(DirEntry(path.asAbsolutePath.asNormalizedPath.to!string));
  sw.stop();
  writeln("getting file infos took: ", sw.peek().msecs, "ms");
  auto w = new TreeMapWidget!FileNode("filemap", fileNode);
  w.addTreeMapFocusedListener((FileNode node) {
      text.text = node.getName().to!dstring ~ " (" ~ node.size.humanize.to!dstring ~ "Byte)";
    });
  return w;
}

extern (C) int UIAppMain(string[] args) {
  auto window = Platform.instance.createWindow(to!dstring("treemap"), null);

  auto vl = new VerticalLayout("vl");
  vl.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

  auto text = new TextWidget("label", "no selection".to!dstring);
  text.fontSize(32);

  //auto w = doNodeExample(text);
  auto w = doFileExample(args, text);

  vl.addChild(w);
  vl.addChild(text);
  w.backgroundColor(0x000000).layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(Rect(10, 10, 10, 10));

  window.mainWidget = vl;
  window.show();
  return Platform.instance.enterMessageLoop();
}

*/