module treemap;

import std.file;
import std.stdio;
import std.format;
import std.conv;
import std.algorithm;
import std.range;

struct FileNode {
  DirEntry entry;
  ulong size;
  FileNode[] childs;
  this(DirEntry entry) {
    this(entry, entry.size, null);
  }
  this(DirEntry entry, ulong size, FileNode[] childs) {
    this.entry = entry;
    this.size = size;
    this.childs = childs;
  }
  ulong getSize() {
    return size;
  }
  string getName() {
    return entry.name;
  }
  string toString() {
    import std.conv;
    return "{ name: \"" ~getName() ~ "\" , size: " ~ getSize().to!string ~ " }";
  }
}

FileNode calcFileNode(DirEntry entry) {
  if (entry.isDir) {
    auto childs = dirEntries(entry.name, SpanMode.shallow, false)
      .map!(v => calcFileNode(v))
      .array();
    auto childSize = 0L.reduce!((sum, v) => sum + v.getSize)(childs);
    return FileNode(entry, childSize, childs);
  } else {
    return FileNode(entry);
  }
}

/*
unittest {
  auto res = calcFileNode(DirEntry("."));
  writeln(res);
}
*/
size_t calcSize(DirEntry entry) {
  if (entry.isDir) {
    size_t res = 0;
    foreach (DirEntry e; dirEntries(entry.name, SpanMode.shallow, false)) {
      res += calcSize(e);
    }
    return res;
  } else {
    return entry.size;
  }
}

size_t calcSize(string file) {
  return calcSize(DirEntry(file));
}

unittest {
  writeln(calcSize("."));
}

struct Rect {
  double x;
  double y;
  double width;
  double height;
  this(double x, double y, double width, double height) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }
  double area() {
    return width * height;
  }
  string toString() {
    return "Rect { " ~ x.to!string ~ ", " ~ y.to!string ~ ", " ~ width.to!string ~ ", " ~ height.to!string ~ ", " ~ area.to!string ~ " }";
  }
  int left() {
    return cast(int)x;
  }
  int right() {
    return cast(int)(x+width);
  }
  int top() {
    return cast(int)y;
  }
  int bottom() {
    return cast(int)(y+height);
  }
}
double size(Node[] nodes) {
  return nodes.map!(v => v.size).sum;
}

class Node {
  double size;
  Rect rect;
  Node[] childs;
  this(double size) {
    this.size = size;
  }
  this(Node[] childs) {
    this.childs = childs;
    this.size = childs.size();//;map!(v => v.size).sum;
  }
  Node setRect(Rect rect) {
    this.rect = rect;
    return this;
  }
  Rect getRect() {
    return this.rect;
  }
  double aspectRatio(double sharedLength, double l2) {
    double l1 = sharedLength * size;

    return max(l1/l2, l2/l1);
  }
  override string toString() {
    return "Node { size: " ~ size.to!string /+ ~ " rect: " ~ rect.to!string+/ ~ " }";
  }

  void layout() {
    Row row = Row(getRect(), size);
    Node[] rest = childs;
    while (rest.length > 0) {
      Node child = rest.front();
      Row newRow = row.add(child);

      if (newRow.worstAspectRatio > row.worstAspectRatio) {
        new Node(rest).setRect(row.imprint()).layout();
        return;
      }

      row = newRow;
      rest.popFront();
    }
    row.imprint();
  }
}

/++
 + A Row collects childnodes and provides means to layout them.
 + To find the best rectangular treemap layout it also can find
 + the child with the worst aspect ratio. The layouting performed in
 + TreeMap is a two step process:
 + - first the best row to fill the area is searched (this is done
 +   incrementally child Node by child Node.
 + - second the found Row is imprinted (which means the layout
 +   coordinates are added to the child Nodes).
 +/
struct Row {
  /// the total area that the row could take
  Rect rect;
  /// the total size that corresponds to the total area
  double size;

  double fixedLength;
  double variableLength;

  Node[] childs;
  double worstAspectRatio;
  double area;

  public this(Rect rect, double size) {
    this.rect = rect;
    this.size = size;
    this.fixedLength = min(rect.width, rect.height);
    this.variableLength = 0;
    this.worstAspectRatio = double.max;
    this.area = 0;
  }

  public this(Rect rect, Node[] childs, double size) {
    this(rect, size);
    this.childs = childs;
    double sizeOfAllChilds = childs.size();
    double percentageOfTotalArea = sizeOfAllChilds / size;
    this.variableLength = max(rect.width, rect.height) * percentageOfTotalArea;
    double height = min(rect.width, rect.height);
    this.worstAspectRatio = childs.map!(n => n.aspectRatio(height / sizeOfAllChilds, variableLength)).reduce!max;
  }

  public Row add(Node n) {
    Node[] tmp = childs ~ n;
    return Row(rect, childs~n, size);
  }

  public Rect imprint() {
    if (rect.height < rect.width) {
      return imprintLeft();
    } else {
      return imprintTop();
    }
  }

  private Rect imprintLeft() {
    double offset = 0;
    foreach (Node child; childs) {
      double percentage = child.size / childs.size();
      double height = percentage * rect.height;
      child.setRect(Rect(rect.x, rect.y+offset, variableLength, height));
      offset += height;
    }
    return Rect(rect.x+variableLength, rect.y, rect.width-variableLength, rect.height);
  }

  private Rect imprintTop() {
    double offset = 0;
    foreach(Node child; childs) {
      double percentage = child.size / childs.size();
      double width = percentage * rect.width;
      child.setRect(Rect(rect.x+offset, rect.y+0, width, variableLength));
      offset += width;
    }
    return Rect(rect.x, rect.y+variableLength, rect.width, rect.height-variableLength);
  }
}

@("Node.layout")
unittest {
  import std.math : approxEqual;
  import std.algorithm : equal;
  import unit_threaded;

  void shouldEqual(Rect r1, Rect r2) {
    r1.x.shouldEqual(r2.x);
    r1.y.shouldEqual(r2.y);
    r1.width.shouldEqual(r2.width);
    r1.height.shouldEqual(r2.height);
  }

  auto childs = [ 6, 6, 4, 3, 2, 2, 1 ].map!(v => new Node(v)).array;
  auto n = new Node(childs);
  n.setRect(Rect(0, 0, 600, 400));
  n.layout();

  n.childs[0].rect.shouldEqual(Rect(0, 0, 300, 200));
  n.childs[1].rect.shouldEqual(Rect(0, 200, 300, 200));

  shouldEqual(n.childs[2].rect, Rect(300, 0, 171, 233));
  shouldEqual(n.childs[3].rect, Rect(471, 0, 129, 233));

  shouldEqual(n.childs[4].rect, Rect(300, 233, 120, 166));
  shouldEqual(n.childs[5].rect, Rect(420, 233, 120, 166));
  shouldEqual(n.childs[6].rect, Rect(540, 233, 60, 166));
}
