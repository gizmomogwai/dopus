module dopus.results;

import dopus;
import gtk.ApplicationWindow;
import gtk.Box;
import gtk.Button;
import gtk.Container;
import gtk.ScrolledWindow;

class Results
{
    Dopus app;
    Box box;
    Container[TaskResult] results;
    this(Dopus app)
    {
        this.app = app;
        auto window = new ApplicationWindow(app);
        window.setTitle("Results");
        auto all = new Box(Orientation.VERTICAL, 0);
        box = new Box(Orientation.VERTICAL, 0);
        all.packStart(new ScrolledWindow(box), true, true, 0);
        window.add(all);
        window.resize(400, 200);
        window.showAll();
    }

    void add(TaskResult r)
    {
        auto taskUi = r.mount(app);
        results[r] = taskUi;
        auto remove = new Button("X");
        remove.addOnClicked(delegate(Button) {
            box.remove(results[r]);
            results.remove(r);
        });
        taskUi.add(remove);
        taskUi.showAll;
        box.add(taskUi);
    }
}
