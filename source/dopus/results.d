module dopus.results;

import dopus;
import gtk.ApplicationWindow;

class Results
{
    Dopus app;
    TaskResult[] results;
    this(Dopus app)
    {
        this.app = app;
    }

    void add(TaskResult r)
    {
        results ~= r;
        showResultWindow(r);
    }

    void showResultWindow(TaskResult r) {
        auto window = new ApplicationWindow(app);
        r.mount(app, window);
        window.showAll();
    }
}
