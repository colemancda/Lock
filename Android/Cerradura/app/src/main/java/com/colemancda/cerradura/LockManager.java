package com.colemancda.cerradura;

import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.content.Context;
import android.os.IBinder;
import android.util.Log;
import java.util.ArrayList;
import java.util.Date;
import java.util.UUID;

/**
 * Created by coleman on 6/15/16.
 */
public final class LockManager extends Service implements BluetoothAdapter.LeScanCallback {

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

    private final ArrayList<BluetoothDevice> scanResults = new ArrayList();

    private boolean runningAsyncOperation = true;

    private Exception asyncError;

    /**
     * Methods
     */

    public void scan(int duration) throws Exception {

        Log.v(TAG, "Scanning");

        // reset variables
        scanResults.clear();

        if (!adapter.startLeScan(this)) throw new LockManagerError("Could not start scan");

        isScanning = true;

        synchronized (this) {

            wait(duration);
        }

        adapter.stopLeScan(this);

        isScanning = false;

        Log.v(TAG, "Finished scanning");

        // connect to peripherals and detect if lock

        for (BluetoothDevice peripheral : scanResults) {

            BluetoothGatt bluetoothGatt;

            try { bluetoothGatt = connect(peripheral, 5); }

            catch (Exception e) { Log.v(TAG, "Cound not connect to " + peripheral.getAddress().toString() + ": " + e.toString()); continue; }

            // discover services, detect lock

            // disconnect
            bluetoothGatt.disconnect();
        }
    }

    private BluetoothGatt connect(BluetoothDevice peripheral, int timeout) throws Exception {

        BluetoothGatt bluetoothGatt = peripheral.connectGatt(this, false, gattCallback);

        wait(timeout);

        return bluetoothGatt;
    }

    private void wait(int timeout) throws Exception {

        assert runningAsyncOperation == false;

        runningAsyncOperation = true;

        long waitTime = System.currentTimeMillis();

        long timeoutMiliseconds = timeout * 1000;

        while (runningAsyncOperation) {

            long now = System.currentTimeMillis();

            if (timeout > 0) {

                if (now - waitTime >= timeoutMiliseconds) {

                    break;
                }
            }
        }

        Exception error = asyncError;

        asyncError = null;

        if (error != null) {

            throw error;
        }
    }

    private void stopWaiting(Exception error) {

        asyncError = error;
        runningAsyncOperation = false;
    }

    /**
     * Callbacks
     */
    public void onLeScan (BluetoothDevice device,
                   int rssi,
                   byte[] scanRecord) {

        Log.v(TAG, "Discovered peripheral " + device.getAddress().toString());

        scanResults.add(device);
    }

    // Implements callback methods for GATT events that the app cares about.  For example,
    // connection change and services discovered.
    private final BluetoothGattCallback gattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {

            if (newState == BluetoothProfile.STATE_CONNECTED) {

                Log.i(TAG, "Connected to " + gatt.getDevice().getAddress().toString());

                stopWaiting(null);
            }

            /*
            String intentAction;
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                intentAction = ACTION_GATT_CONNECTED;
                mConnectionState = STATE_CONNECTED;
                broadcastUpdate(intentAction);
                Log.i(TAG, "Connected to GATT server.");
                // Attempts to discover services after successful connection.
                Log.i(TAG, "Attempting to start service discovery:" +
                        mBluetoothGatt.discoverServices());

            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                intentAction = ACTION_GATT_DISCONNECTED;
                mConnectionState = STATE_DISCONNECTED;
                Log.i(TAG, "Disconnected from GATT server.");
                broadcastUpdate(intentAction);
            }*/
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {

            /*
            if (status == BluetoothGatt.GATT_SUCCESS) {
                broadcastUpdate(ACTION_GATT_SERVICES_DISCOVERED);
            } else {
                Log.w(TAG, "onServicesDiscovered received: " + status);
            }*/
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt,
                                         BluetoothGattCharacteristic characteristic,
                                         int status) {

            /*
            if (status == BluetoothGatt.GATT_SUCCESS) {
                broadcastUpdate(ACTION_DATA_AVAILABLE, characteristic);
            }*/
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt,
                                            BluetoothGattCharacteristic characteristic) {

            /*
            broadcastUpdate(ACTION_DATA_AVAILABLE, characteristic);
            */
        }
    };

    public IBinder onBind(android.content.Intent intent) {

        return null;
    }

    /**
     * Supporting Types.
     */

    public final class Lock {

        public UUID uuid;
    }

    public final class LockManagerError extends Exception {

        private LockManagerError(String text) {

            this.text = text;
        }

        public String text;
    }

    public final class LockManagerTimeoutError extends Exception {

        private LockManagerTimeoutError() { }
    }
}

/**
 * Private
 */

