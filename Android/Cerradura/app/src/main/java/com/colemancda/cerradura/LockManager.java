package com.colemancda.cerradura;

import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;
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

            wait(duration * 1000);
        }

        adapter.stopLeScan(this);

        Log.v(TAG, "Finished scanning");

        // connect to peripherals and detect if lock

        ArrayList<Lock> foundLocks = new ArrayList<Lock>();

        for (BluetoothDevice device : scanResults) {

            BluetoothGatt peripheral;

            try { peripheral = connect(device, 3); }

            catch (Exception e) { Log.v(TAG, "Cound not connect to " + device.getAddress().toString() + ": " + e.toString()); continue; }

            assert peripheral != null;

            // discover services, detect lock
            try { discoverServices(peripheral); }

            catch (Exception e) { peripheral.disconnect(); continue; }

            BluetoothGattService service = peripheral.getService(LockService.UUID);

            if (service != null) {

                // try to extract lock info from Lock
                try {

                    LockManager.Lock lock = foundLock(peripheral, service);

                    foundLocks.add(lock);
                }

                catch (Exception e) {
                    Log.v(TAG, "Error discovering lock " + device.getAddress().toString() + ": " + e.toString());
                    peripheral.disconnect();
                    continue;
                }
            }

            // disconnect
            peripheral.disconnect();
        }

        isScanning = false;
    }

    private BluetoothGatt connect(BluetoothDevice peripheral, int timeout) throws Exception {

        BluetoothGatt bluetoothGatt = peripheral.connectGatt(this, false, gattCallback);

        waitForOperation(timeout);

        return bluetoothGatt;
    }

    private void discoverServices(BluetoothGatt peripheral) throws Exception {

        peripheral.discoverServices();

        waitForOperation(5);
    }

    /*
    private void discoverCharacteristics(BluetoothGattService serviceUUID, BluetoothGatt peripheral) throws Exception {

        peripheral.
    }*/

    private LockManager.Lock foundLock(BluetoothGatt peripheral, BluetoothGattService lockService) throws Exception {

        Log.v(TAG, "Found lock peripheral " + peripheral.getDevice().getAddress().toString());

        // get lock status

        BluetoothGattCharacteristic statusCharacteristic = lockService.getCharacteristic(LockIdentifier.UUID);
        if (statusCharacteristic == null) { throw new LockManagerMissingCharacteristicError(LockIdentifier.UUID); }



        BluetoothGattCharacteristic identifierCharacteristic = lockService.getCharacteristic(LockIdentifier.UUID);
        if (identifierCharacteristic == null) { throw new LockManagerMissingCharacteristicError(LockIdentifier.UUID); }


    }

    private void waitForOperation(int timeout) throws Exception {

        //assert (!runningAsyncOperation);

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

        if (!scanResults.contains(device)) {

            Log.v(TAG, "Discovered peripheral " + device.getAddress().toString());

            scanResults.add(device);
        }
    }

    // Implements callback methods for GATT events that the app cares about.  For example,
    // connection change and services discovered.
    private final BluetoothGattCallback gattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {

            if (status != BluetoothGatt.GATT_SUCCESS) {

                if (runningAsyncOperation) {

                    stopWaiting(new LockManagerGATTError(status));
                }

                Log.w(TAG, "Error connecting to " + gatt.getDevice().getAddress().toString());

                return;
            }

            if (newState == BluetoothProfile.STATE_CONNECTED) {

                Log.v(TAG, "Connected to " + gatt.getDevice().getAddress().toString());

                stopWaiting(null);

            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {

                Log.v(TAG, "Disconnected from " + gatt.getDevice().getAddress().toString());
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {

            if (status == BluetoothGatt.GATT_SUCCESS) {

                Log.v(TAG, "Discovered " + gatt.getServices().size() + " services for " + gatt.getDevice().getAddress().toString());

                stopWaiting(null);

            } else {

                Log.w(TAG, "Could not discover services for " + gatt.getDevice().getAddress().toString());

                stopWaiting(new LockManagerGATTError(status));
            }
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt,
                                         BluetoothGattCharacteristic characteristic,
                                         int status) {


            if (status == BluetoothGatt.GATT_SUCCESS) {

                Log.v(TAG, "Read characteristic" + characteristic.getUuid().toString());

                stopWaiting(null);

            } else {

                Log.w(TAG, "Could not read characteristic" + characteristic.getUuid().toString());

                stopWaiting(new LockManagerGATTError(status));
            }
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

        public final String text;

        public final String toString() {

            return text;
        }
    }

    public final class LockManagerTimeoutError extends Exception {

        private LockManagerTimeoutError() { }
    }

    public final class LockManagerMissingCharacteristicError extends Exception  {

        public final UUID UUID;

        private LockManagerMissingCharacteristicError(UUID uuid) {

            this.UUID = uuid;
        }
    }

    public final class LockManagerGATTError extends  Exception {

        public final int status;

        private LockManagerGATTError(int status) {

            this.status = status;
        }
    }
}

/**
 * Private
 */

