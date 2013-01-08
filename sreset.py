import serial
import struct
import time
import sys

# delay high, delay low, address, value
BAUD = 115200
COMPORT = 7

class ACID64Closed:
    pass

ser = None
while ser is None:
    try:
        ser = serial.Serial( 'COM%s' % COMPORT, timeout=0, baudrate=BAUD)
        print 'using COM%s' % COMPORT
        break
    except serial.serialutil.SerialException:
        pass
    else:
        print 'no serial device found'
        time.sleep( 0.5 )
try:
    status = ""
    addr = 0
    while addr < 32 :
        data = struct.pack( '!BBBB', 0, 1, addr, 0)
        addr = addr + 1
        ser.write( data )
    status = ser.read()

except serial.serialutil.SerialTimeoutException:
    conn.close()
    s.close()
    ser = None
    print 'serial device removed'
    time.sleep( 1 )
