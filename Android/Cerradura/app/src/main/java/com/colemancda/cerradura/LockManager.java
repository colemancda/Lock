package com.colemancda.cerradura;

import android.bluetooth.BluetoothAdapter;

import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.UUID;

/**
 * Created by coleman on 6/15/16.
 */
public final class LockManager {

    /**
     * Singleton
     */
    private static LockManager shared = new LockManager();

    private LockManager() {

        System.console().printf("Initialized LockManager");
    }

    public static LockManager shared() {

        assert shared.adapter != null;

        return shared;
    }

    /**
     * Properties
     */

    public BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();

    public ArrayList<Lock> foundLocks = new ArrayList<Lock>();

    /**
     * Methods
     */

    public void scan() throws Exception {

        System.console().printf("Scanning");


    }


    /**
     * Supporting Types.
     */

    public final class Lock {

        public UUID uuid;
    }
}
