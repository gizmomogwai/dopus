module delay;

void debugDelay()
{
    import core.thread : Thread;
    import core.time : dur;

    Thread.sleep(dur!("msecs")(50));
}
