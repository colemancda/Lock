package com.colemancda.cerradura;

import java.util.UUID;
import java.nio.ByteBuffer;

/**
 * Created by coleman on 6/16/16.
 */

interface GATTProfileService {

    static UUID UUID = null;
}

interface GATTProfileCharacteristic {

    static UUID UUID = null;
}

final class LockService implements GATTProfileService {

    static final UUID UUID = java.util.UUID.fromString("D5373D28-044C-11E6-B3C2-09AB70D5A8C7");
}

final class LockIdentifier implements GATTProfileCharacteristic {

    static final UUID UUID = java.util.UUID.fromString("EB1BA354-044C-11E6-BDFD-09AB70D5A8C7");

    final UUID value;

    LockIdentifier(byte[] bytes) {

        ByteBuffer buffer = ByteBuffer.wrap(bytes);

        long msb = buffer.getLong();
        long lsb = buffer.getLong();

        this.value = new UUID(msb, lsb);
    }
}

final class LockStatus implements GATTProfileCharacteristic {

    static final UUID UUID = java.util.UUID.fromString("F868B290-044C-11E6-BD3B-09AB70D5A8C7");
}

final class LockModel implements GATTProfileCharacteristic {

    static final UUID UUID = java.util.UUID.fromString("AD96F330-0497-11E6-9EB3-E72D62A5198D");
}

final class LockVersion implements GATTProfileCharacteristic {

    static final UUID UUID = java.util.UUID.fromString("F28A0E1E-044C-11E6-9032-09AB70D5A8C7");
}

final class LockSetup implements GATTProfileCharacteristic {

    static final UUID UUID = java.util.UUID.fromString("129E401C-044D-11E6-8FA9-09AB70D5A8C7");
}
