module dopus.lister.actions.flipsourceanddestinationaction;

import dopus.lister.actions;

static this() {
    ListerActions.register!FlipSourceAndDestinationAction;
}

class FlipSourceAndDestinationAction : SimpleAction {
    this(Lister lister) {
        super("flipSourceAndDestination", null);
        addOnActivate(delegate(Variant, SimpleAction) {
                if (lister.listers.size > 1) {
                    auto l = lister.listers.listers[1];
                    lister.listers.moveToFront(l);
                    l.present;
                }
            });

    }
}
