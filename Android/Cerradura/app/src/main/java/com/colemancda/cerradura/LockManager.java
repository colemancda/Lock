package com.colemancda.cerradura;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.content.Context;
import android.util.Log;
import java.util.ArrayList;
import java.util.Date;
import java.util.UUID;

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

    private final static String TAG = "LockManager";

    public final BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();

    public final ArrayList<Lock> foundLocks = new ArrayList<Lock>();

    private Boolean isScanning = false;

    public final Boolean getIsScanning() { return isScanning;  }


    /**
     * Methods
     */

    public void scan(Integer duration) throws Exception {

        Log.v(TAG, "Scanning");

        if (!adapter.startLeScan(this)) throw new LockManagerError("Could not start scan");

        isScanning = true;

        Long scanDate = System.currentTimeMillis();

        while (true) {

            synchronized (this) {

                wait(1000);
            }

            long interval = System.currentTimeMillis() - scanDate;

            if (interval >= duration * 1000) {

                break;
            }
        }

        adapter.stopLeScan(this);

        isScanning = false;

        Log.v(TAG, "Finished scanning");
    }

    /**
     * Callbacks
     */
    public void onLeScan (BluetoothDevice device,
                   int rssi,
                   byte[] scanRecord) {

        Log.v(TAG, "Discovered peripheral " + device.getAddress().toString());


    }

    /**
     * Supporting Types.
     */

    public final class Lock {

        public UUID uuid;
    }

    public final class LockManagerError extends Exception {

        public LockManagerError(String text) {

            this.text = text;
        }

        public String text;
    }
}

/**
 * Private
 */

