module dopus.tasks.filllistertask;

import core.time;
import dopus.lister;
import dopus.task;
import std.concurrency;
import std.experimental.logger;
import std.file;
import std.format;
import std.stdio;

void fillListerTask(shared(Lister) lister, string path)
{
    lister.clear();
    foreach (dirEntry; dirEntries(path, SpanMode.shallow))
    {
        lister.addEntry(dirEntry);
    }
}
