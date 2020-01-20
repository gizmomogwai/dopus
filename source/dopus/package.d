module dopus;

import gtk.Application;

import dopus.listers;
import dopus.lister;
import gtk.Window;
import std.stdio;

class Layout
{
    int x;
    Layout layout(Window w)
    {
        w.resize(300, 300);
        w.move(x, 0);
        x += 300;
        return this;
    }
}

class Dopus : Application
{
    Listers listers;
    this(string[] args)
    {
        super("com.flopcode.Dopus", ApplicationFlags.HANDLES_COMMAND_LINE);
        auto layout = new Layout;
        import gio.Application : GioApplication = Application;
        import gio.ApplicationCommandLine;

        addOnActivate(delegate(GioApplication gioApp) {
            import gtk.MainWindow;
            import gtk.Button;
            import gtk.Box;

            listers = new Listers(this);
            layout.layout(listers);
            foreach (dir; args[1 .. $])
            {
                layout.layout(new Lister(this, listers, dir));
            }
            listers.showAll();
        });
        addOnCommandLine(delegate(Scoped!ApplicationCommandLine acl, GioApplication gioApp) {
            activate();
            return 0;
        });
    }
}
