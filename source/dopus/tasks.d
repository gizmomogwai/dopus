module dopus.tasks;

import dopus;
import gtk.ApplicationWindow;
import gtk.Box;
import gtk.Label;
import gtk.ScrolledWindow;

class Tasks
{
    Dopus app;
    Box box;
    Label[shared(Task)] labels;

    this(Dopus app)
    {
        this.app = app;
        auto window = new ApplicationWindow(app);
        window.setTitle("Tasks");
        auto all = new Box(Orientation.VERTICAL, 0);
        box = new Box(Orientation.VERTICAL, 0);
        all.packStart(new ScrolledWindow(box), true, true, 0);
        window.add(all);
        window.resize(400, 200);
        window.showAll();
    }

    void add(shared(Task) t)
    {
        auto label = new Label("");
        labels[t] = label;
        label.showAll;
        box.add(label);
    }

    void update(shared(Task) t, string msg)
    {
        labels[t].setText(msg);
    }

    void finish(shared(Task) t)
    {
        box.remove(labels[t]);
        labels.remove(t);
    }
}
