module delay;

void debugDelay()
{
    import core.thread;

    Thread.sleep(dur!("msecs")(50));
}
