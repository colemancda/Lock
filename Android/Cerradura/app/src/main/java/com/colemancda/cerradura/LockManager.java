package com.colemancda.cerradura;

import android.bluetooth.*;
import android.bluetooth.le.*;
import android.util.Log;

import java.util.ArrayList;
import java.util.UUID;
import java.util.concurrent.locks.Lock;

/**
 * Created by coleman on 6/15/16.
 */
public final class LockManager implements BluetoothAdapter.LeScanCallback {

    /**
     * Singleton
     */
    private static LockManager shared = new LockManager();

    private LockManager() {

        Log.v(TAG, "Initialized LockManager");
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

    private static String TAG = "LockManager";

    /**
     * Methods
     */

    public void scan(Integer duration) throws Exception {

        Log.v(TAG, "Scanning");

        adapter.startLeScan(this);

        synchronized (this) {

            wait(duration * 1000);
        }

        //adapter.stopLeScan(this);

        Log.v(TAG, "Finished scanning");


    }

    /**
     * Callbacks
     */
    public void onLeScan (BluetoothDevice device,
                   int rssi,
                   byte[] scanRecord) {

        Log.i(TAG, "Discovered peripheral " + device.getAddress().toString());
    }

    /**
     * Supporting Types.
     */

    public final class Lock {

        public UUID uuid;
    }
}

/**
 * Private
 */

