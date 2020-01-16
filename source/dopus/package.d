module dopus;

import gtk.application;
import dopus.lister;
import std.stdio;

class Dopus : Application
{
    Lister[] listers;
    this(string[] args)
    {
        super("com.flopcode.Dopus", ApplicationFlags.HANDLES_COMMAND_LINE);

        import gio.Application : GioApplication = Application;
        import gio.ApplicationCommandLine;

        addOnActivate(delegate(GioApplication gioApp) {
            writeln("onactivate");
            import gtk.MainWindow;
            import gtk.Button;
            import gtk.Box;

            foreach (dir; args[1 .. $])
            {
                listers ~= new Lister(this, dir);
            }
        });
        addOnCommandLine(delegate(Scoped!ApplicationCommandLine acl, GioApplication gioApp) {
            writeln("on Commandline");
            activate();
            return 0;
        });
    }
}
