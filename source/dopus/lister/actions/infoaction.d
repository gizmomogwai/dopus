module dopus.lister.actions.infoaction;

import dopus;
import dopus.lister.actions;
import gtk.Box;
import gtk.Button;
import gtk.TextView;
import gtk.Window;
import gtkd.x.treeselection;
import std.file;
import std.stdio;
import std.string;

static this()
{
    ListerActions.register!InfoAction;
}

class InfoTaskResult : TaskResult
{
    string[] input;
    ulong nrOfDirectories;
    ulong nrOfFiles;
    ulong size;

    this(string[] input) {
        this.input = input;
    }
    auto add()
    {
        this.nrOfDirectories++;
        return this;
    }

    auto add(ulong size)
    {
        this.size += size;
        this.nrOfFiles++;
        return this;
    }

    override void mount(Dopus app, Window window) {
        auto textView = new TextView();
        textView.getBuffer().setText("%s in %s".format(toString, duration));
        auto box = new Box(Orientation.VERTICAL, 0);
        box.add(textView);
        auto redo = new Button("redo");
        redo.addOnClicked(delegate(Button) {
                app.enqueue(cast(shared)new InfoTask(input));
            });
        box.add(redo);
        window.add(box);
    }
    override string toString() const
    {
        return "Result { nrOfDirectories=%s, nrOfFiles=%s, size=%s }".format(nrOfDirectories,
                nrOfFiles, size);
    }
}

class InfoTask : Task
{
    string[] selection;
    this(string[] selection)
    {
        this.selection ~= selection;
    }

    public override TaskResult run() shared
    {
        auto res = new InfoTaskResult((cast()this).selection);
        foreach (s; selection)
        {
            if (s.isDir)
            {
                res.add;
                foreach (e; s.dirEntries(SpanMode.depth))
                {
                    if (e.isFile)
                    {
                        res.add(e.getSize);
                    }
                    else
                    {
                        res.add;
                    }
                }
            }
            else
            {
                res.add(s.getSize);
            }
        }
        return res;
    }
}
/+
        auto task = new Task();
        auto res = new Result(0, 0, false);
        if (path.isDir())
        {
            foreach (e; path.dirEntries(SpanMode.depth))
            {
                if (e.isFile())
                {
                    res = res.add(e.getSize());
                }
                if (task.wasCanceled())
                {
                    res = res.cancel();
                    return res;
                }
            }
            return res;
        }
        else
        {
            return res.add(path.getSize());
        }
    }
+/

class InfoAction : SimpleAction
{
    this(Lister lister)
    {
        super("info", null);
        addOnActivate(delegate(Variant, SimpleAction) {
            writeln("info");
            string[] res;
            foreach (s; lister.view.getSelection.getSelection)
            {
                res ~= (lister.navigationStack.path ~ "/" ~ s);
            }
            auto task = new InfoTask(res);
            lister.app.enqueue(cast(shared) task);
        });
    }
}
