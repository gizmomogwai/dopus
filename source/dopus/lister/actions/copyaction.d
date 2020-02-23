module dopus.lister.actions.copyaction;

import dopus.lister.actions;
import dopus;
import gtk.Box;
import gtk.Container;
import gtk.Label;
import gtkd.x.treeselection;
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

class CopyTaskResult : TaskResult {
    string[] results;
    void add(string msg) {
        results ~= msg;
    }
    override Container mount(Dopus app)
    {
        auto vBox = new Box(Orientation.VERTICAL, 0);
        auto label = new Label("%s in %s".format(toString, duration));
        vBox.add(label);
        foreach (s; results) {
            vBox.add(new Label(s));
        }
        /*
        auto redo = new Button("redo");
        redo.addOnClicked(delegate(Button) {
            app.enqueue(cast(shared) new InfoTask(input));
        });
        box.add(redo);
        */
        return vBox;
    }

}

class CopyTask : Task
{
    string[] selection;
    string to;
    this(string[] selection, string to)
    {
        this.selection ~= selection;
        this.to = to;
    }

    public override TaskResult run(shared(Dopus) dopus) shared
    {
        writeln("1");
        return (cast()this).run(dopus);
    }
    public TaskResult run(shared(Dopus) dopus) {
        CopyTaskResult res = new CopyTaskResult;
        auto msg = "Copy %s to %s".format(selection, to);
        writeln(msg);
        foreach (s; selection)
        {
            if (s.endsWith("/")) {
                s = s[0..$-1];
            }
            auto command = ["rsync", "--archive", "--verbose", s, to];
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
                if (destination is null) {
                    return;
                }
                string[] res;
                foreach (s; lister.view.getSelection.getSelection)
                {
                    res ~= (lister.navigationStack.path ~ "/" ~ s);
                }
                auto task = new CopyTask(res, lister.listers.destination.navigationStack.path);
                lister.app.enqueue(cast(shared) task);
            }
        );
    }
}
