package com.colemancda.cerradura;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Queue;

/**
 * Dispatch Queue for Java
 */
public final class Async {

    private static final Thread thread = new Thread(Async.queueTask);

    private static final Runnable queueTask = new Runnable() {
        @Override
        public void run() {

            while (true) {

                synchronized (Async.queue) {

                    Runnable task = Async.queue.getFirst();

                    if (task != null) {

                        task.run();
                    }

                    // remove from queue
                    Async.queue.removeFirst();
                }
            }
        }
    };

    private static ArrayDeque<Runnable> queue = new ArrayDeque<Runnable>();

    public static void run(Runnable task) {

        synchronized (queue) {

            if (thread.getState() == Thread.State.NEW) {

                thread.start();
            }

            // add to queue
            queue.addLast(task);
        }
    }
}