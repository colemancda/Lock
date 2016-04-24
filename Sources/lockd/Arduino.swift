//
//  Arduino.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/24/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(Linux)
    import Glibc
    let DefaultArduinoSerialPort = "/dev/ttyACM0"
#elseif os(OSX)
    import Darwin
    let DefaultArduinoSerialPort = "/dev/tty.usbmodem1421"
#endif

func ArduinoSendByte(_ serialPort: String = DefaultArduinoSerialPort) -> Bool {
    
    let fd = open(serialPort, O_RDWR | O_NONBLOCK)
    
    guard fd != 1 else { return false }
    
    var tty = termios()
    
    guard tcgetattr(fd, &tty) == 0
        else { return false }
    
    cfsetospeed(&tty, speed_t(B9600))
    cfsetispeed(&tty, speed_t(B9600))
    
    /* 8 bits, no parity, no stop bits */
    tty.c_cflag = (tty.c_cflag & ~tcflag_t(PARENB))
    tty.c_cflag = (tty.c_cflag & ~tcflag_t(CSTOPB))
    tty.c_cflag = (tty.c_cflag & ~tcflag_t(CSIZE))
    tty.c_cflag = (tty.c_cflag | tcflag_t(CS8))
    
    tty.c_cflag = tty.c_cflag | tcflag_t(CREAD | CLOCAL)  // turn on READ & ignore ctrl lines
    tty.c_iflag = tty.c_cflag & ~tcflag_t(IXON | IXOFF | IXANY); // turn off s/w flow ctrl
    
    tty.c_lflag &= tty.c_cflag & ~tcflag_t(ICANON | ECHO | ECHOE | ISIG) // make raw
    tty.c_oflag &= tty.c_cflag & ~tcflag_t(OPOST); // make raw
    
    // see: http://unixwiz.net/techtips/termios-vmin-vtime.html
    //tty.c_cc[VMIN]  = 0;
    //tty.c_cc[VTIME] = 0;
    //toptions.c_cc[VTIME] = 20;
    
    //tty.c_cflag = tcflag_t(B9600 | CS8 | CLOCAL | CREAD | IGNPAR)
    tcsetattr(fd, TCSANOW, &tty)
    tcsetattr(fd, TCSAFLUSH, &tty)
    
    /* Wait for the Arduino to reset */
    //sleep(1)
    
    //tcflush(fd, TCIFLUSH)
    
    sleep(2); //required to make flush work, for some reason
    guard tcflush(fd, TCIOFLUSH) != -1
        else { return false }
    
    var bytes: [UInt8] = [0] // send a byte
    
    let writtenBytes = write(fd, &bytes, bytes.count)
    
    guard writtenBytes != -1
        else { return false }
    
    sleep(2); //required to make flush work, for some reason
    guard tcflush(fd, TCIOFLUSH) != -1
        else { return false }
    
    close(fd)
    return true
}
