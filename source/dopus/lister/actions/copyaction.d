module dopus.lister.actions.copyaction;

import dopus.lister.actions;
import dopus;
import gtk.Box;
import gtk.Button;
import gtk.Container;
import gtk.Label;
import std.conv;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;
import std.experimental.logger;

static this()
{
    ListerActions.register!CopyAction;
}

class CopyTaskResult : TaskResult
{
    string[] listerPaths;
    string[] selection;
    string destinationPath;
    
    string[] results;
    this(string[] listerPaths, string[] selection, string destinationPath) {
        this.listerPaths = listerPaths;
        this.selection = selection;
        this.destinationPath = destinationPath;
    }
    
    void add(string msg)
    {
        results ~= msg;
    }

    override Container mount(Dopus app)
    {
        auto vBox = new Box(Orientation.VERTICAL, 0);
        auto label = new Label("%s in %s".format(toString, duration));
        vBox.add(label);
        foreach (s; results)
        {
            vBox.add(new Label(s));
        }

        auto redo = new Button("redo");
        redo.addOnClicked(delegate(Button) {
                app.enqueue(cast(shared) new CopyTask(listerPaths, selection, destinationPath));
        });
        vBox.add(redo);

        return vBox;
    }
}

class CopyTask : Task
{
    string[] selection;
    string destinationPath;
    this(string[] listerPaths, string[] selection, string destinationPath)
    {
        super(listerPaths);
        this.destinationPath = destinationPath;
        this.selection ~= selection;
    }

    public override TaskResult run(shared(Dopus) dopus) shared
    {
        return (cast() this).run(dopus);
    }

    public TaskResult run(shared(Dopus) dopus)
    {
        CopyTaskResult res = new CopyTaskResult(listerPaths, selection, destinationPath);
        auto msg = "Copy %s to %s".format(selection, destinationPath);
        writeln(msg);
        foreach (s; selection)
        {
            auto command = [
                "rsync", "--archive", "--verbose", s.unescape, destinationPath
            ];
            command.info;
            auto exitStatus = execute(command);
            if (exitStatus.status == 0)
            {
                res.add(msg ~ " OK");
            }
            else
            {
                "Problem working on: %s".format().error;
                exitStatus.output.error;
                res.add(msg ~ " NOK");
            }
        }
        dopus.progress(cast(shared) this, "copied %s files".format(selection.length));
        dopus.finish(cast(shared) this);
        return res;
    }
}

class CopyAction : SimpleAction
{
    this(Lister lister)
    {
        super("copy", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            auto destination = lister.listers.destination;
            if (destination is null)
            {
                return;
            }
            auto task = new CopyTask(
              [destination.navigationStack.path],
              lister.getSelectedFiles,
              destination.navigationStack.path
            );
            lister.app.enqueue(cast(shared) task);
        });
    }
}
