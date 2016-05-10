module task;
import std.concurrency;

import lister;

/**
 * ListerTask runs in the background of a lister.
 * It is splitted into two parts:
 * - frontend - handles the communication from and to the lister
 * - backend - the task specific operation.
 */
class Task {
  public static struct Finished {}
  public static struct Cancel {}

  shared Lister lister;
  string path;

  this(shared Lister lister, string path) {
    this.lister = lister;
    this.path = path;
  }

  Tid start() shared {
    Tid backendTid = spawn((shared Task t){t.backend();}, this);
    Tid frontendTid = spawn((shared Task t){t.frontend();}, this);
    return frontendTid;
  }

  protected void frontend() shared {
    while (receiveMessages()) {}
    Task.Finished f;
    ownerTid.send(f);
  }

  protected abstract void cancel() shared;

  protected bool receiveMessages() shared {
    bool res = true;
    receive((Task.Finished f) {
        res = false;
      },
      (Task.Cancel c) {
        cancel();
      });
    return res;
  }

  protected abstract void backend() shared;

}