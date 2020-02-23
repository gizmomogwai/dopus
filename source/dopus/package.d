module dopus;

import dopus.lister;
import dopus.listers;
import dopus.results;
import dopus.tasks;
import gtk.Application;
import gtk.Container;
import gtk.Window;
import gtkd.x.threads;
import std.concurrency;
import std.datetime.stopwatch;
import std.stdio;
import std.string;

string unescape(string file)
{
    if (file.endsWith("/"))
    {
        return file[0 .. $ - 1];
    }
    return file;
}

class Layout
{
    int x;
    Layout layout(Window w)
    {
        w.resize(300, 300);
        w.setResizable(true);
        w.move(x, 0);
        x += 300;
        return this;
    }
}

void runTask(shared(Task) t, shared(Dopus) dopus)
{
    auto sw = StopWatch(AutoStart.yes);
    auto taskResult = t.run(dopus);
    sw.stop();
    taskResult.duration = sw.peek;

    dopus.addTaskResult(taskResult);
}

class TaskResult
{
    Duration duration;
    abstract Container mount(Dopus app);
}

abstract class Task
{
    Lister[] listers;
    this(Lister[] listers)
    {
        this.listers = listers;
    }
    //Tid tid;
    public abstract TaskResult run(shared(Dopus)) shared;
}

class Dopus : Application
{
    Listers listers;
    Results results;
    Tasks tasks;
    this(string[] args)
    {
        super("com.flopcode.Dopus", ApplicationFlags.HANDLES_COMMAND_LINE);
        auto layout = new Layout;
        import gio.Application : GioApplication = Application;
        import gio.ApplicationCommandLine : ApplicationCommandLine;

        addOnActivate(delegate(GioAppliocation) {
            listers = new Listers(this);
            results = new Results(this);
            tasks = new Tasks(this);
            layout.layout(listers);
            foreach (dir; args[1 .. $])
            {
                layout.layout(new Lister(this, listers, dir));
            }
        });
        addOnCommandLine(delegate(Scoped!ApplicationCommandLine, GioApplication) {
            activate();
            return 0;
        });
    }

    auto enqueue(shared(Task) t)
    {
        tasks.add(t);
        spawnLinked(&runTask, t, cast(shared) this);
        return this;
    }

    void addTaskResult(TaskResult result) shared
    {
        threadsAddIdleDelegate!(bool delegate())(delegate() {
            (cast() this).results.add(result);
            return false;
        });
    }

    void progress(shared(Task) task, string s) shared
    {
        threadsAddIdleDelegate!(bool delegate())(delegate() {
            (cast() this).tasks.update(task, s);
            return false;
        });
    }

    void finish(shared(Task) task) shared
    {
        threadsAddIdleDelegate!(bool delegate())(delegate() {
            (cast() this).tasks.finish(task);
            foreach (l; (cast() task).listers)
            {
                l.refresh;
            }
            return false;
        });
    }

    void layout(Window window)
    {
        string s = window.getTitle();
        writeln("Layouting: ", s);
        window.resize(400, 200);
    }
}
