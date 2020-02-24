module dopus.lister.actions.infoaction;

import dopus;
import dopus.lister.actions;
import gtk.Box;
import gtk.Button;
import gtk.Container;
import gtk.Label;
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

    this(string[] input)
    {
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

    override Container mount(Dopus app)
    {
        auto box = new Box(Orientation.HORIZONTAL, 0);
        auto label = new Label("%s in %s".format(toString, duration));
        box.add(label);
        auto redo = new Button("redo");
        redo.addOnClicked(delegate(Button) {
                app.enqueue(cast(shared) new InfoTask(input));
        });
        box.add(redo);
        return box;
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
        super([]);
        this.selection ~= selection;
    }

    public override TaskResult run(shared(Dopus) dopus) shared
    {
        auto res = new InfoTaskResult((cast() this).selection);
        foreach (s; selection)
        {
            if (s.isDir)
            {
                res.add;
                foreach (e; s.dirEntries(SpanMode.breadth))
                {
                    if (e.isFile)
                    {
                        res.add(e.getSize);
                    }
                    else
                    {
                        res.add;
                    }
                    if (res.nrOfFiles % 10_000 == 0)
                    {
                        dopus.progress(cast(shared) this, "scanned %s files".format(res.nrOfFiles));
                    }
                }
            }
            else
            {
                res.add(s.getSize);
                if (res.nrOfFiles % 10_000 == 0)
                {
                    dopus.progress(cast(shared) this, "scanned %s files".format(res.nrOfFiles));
                }
            }
        }
        dopus.progress(cast(shared) this, "scanned %s files".format(res.nrOfFiles));
        dopus.finish(cast(shared) this);
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
