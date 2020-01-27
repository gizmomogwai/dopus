module dopus.tasks.testarchivetask;

import dopus.lister;
import dopus.task;
import std.bitmanip;
import std.concurrency;
import std.digest.crc;
import std.experimental.logger;
import std.file;
import std.format;
import std.zip;

void testArchiveTask(string path, shared void delegate(string) clear,
        shared void delegate(string) progress, shared void delegate() finished)
{
    auto task = new Task();
    clear(path);
    auto zip = new ZipArchive(read(path));
    foreach (member; zip.directory.byValue())
    {
        auto data = zip.expand(member);
        CRC32 crc;
        crc.put(data);
        ubyte[] h = crc.finish().dup;
        auto uncompressedCrc = h.read!(uint, Endian.littleEndian)();
        auto expectedCrc = member.crc32;
        if (uncompressedCrc != expectedCrc)
        {
            progress("%s BROKEN".format(member.name));
            progress("expectedcrc: %x vs. actualcrc: %x".format(expectedCrc, uncompressedCrc));
            break;
        }
        //progress("%s OK".format(member.name));
        if (task.wasCanceled())
        {
            break;
        }
    }
    finished();
}
