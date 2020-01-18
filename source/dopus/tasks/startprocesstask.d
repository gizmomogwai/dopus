module dopus.tasks.startprocesstask;

import dopus.lister;
import dopus.task;

import std.process;
import std.string;

void startProcess(shared(string[]) command, shared void delegate() start,
        shared void delegate(string) progress, shared void delegate() finished)
{
    start();
    auto task = new Task();

    auto pid = spawnProcess(cast(string[]) command);
    auto res = pid.tryWait();
    while (res.terminated == false)
    {
        if (task.wasCanceled())
        {
            break;
        }
        import core.thread;

        Thread.sleep(dur!"seconds"(1));
        res = pid.tryWait();
    }
    progress("running '%s' finished with status '%d'".format(command, res.status));
    finished();
}
