module app;

import std.stdio;
import dlangui;

mixin APP_ENTRY_POINT;

import lister;
import tm = treemap;
import std.algorithm;
import std.range;

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

class TreeMapWidget : Widget {
  tm.Node node;
  this(string ID, tm.Node n) {
    super(ID);
    this.node = n;
  }

  override void onDraw(DrawBuf buf) {
    super.onDraw(buf);
    if (visibility != Visibility.Visible)
      return;
    auto rc = _pos;

    auto saver = ClipRectSaver(buf, rc);

    writeln("parent: ", node.getRect());
    //buf.fillRect(Rect(20, 20, 100, 200), 0xff00ff);

    FontRef font = FontManager.instance.getFont(25, FontWeight.Normal, false, FontFamily.SansSerif, "Arial");

    foreach(tm.Node child; node.childs) {
      auto r = child.getRect().toUiRect();
      writeln("  child: ", r);
      //buf.fillRect(child.getRect().toUiRect(), 0xff00ff);
      buf.drawFrame(child.getRect().toUiRect(), 0xff00ff, Rect(1, 1, 1, 1), 0xa0a0a0);
      font.drawText(buf,
                    cast(int)child.getRect().x,
                    cast(int)child.getRect().y,
                    child.size.to!dstring,
                    0xff0000);
    }
  }
}

extern (C) int UIAppMain(string[] args) {
  auto childs = [ 6.0, 6.0, 4.0, 3.0, 2.0, 2.0, 1.0 ].map!(v => new tm.Node(v)).array();
  auto n = new tm.Node(childs);
  n = n.setRect(tm.Rect(0, 0, 600, 400));
  n.layout();
  auto window = Platform.instance.createWindow(to!dstring("treemap"), null);
  auto w = new TreeMapWidget("treemap", n).backgroundColor(0x000000).layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(Rect(10,10,10,10));
  window.mainWidget = w;
  window.show();
  return Platform.instance.enterMessageLoop();
}
