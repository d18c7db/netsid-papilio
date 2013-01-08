import serial
import struct
import time
import sys

# delay high, delay low, address, value
#data = struct.pack( '!BBBB', 1, 0, int(sys.argv[1]), int(sys.argv[2]) )

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
#    ser.write( data )
#ch1
#220Hz 0E6b
    ser.write( struct.pack( '!BBBB', 1, 0, 0x00, 0x6b) )
    ser.write( struct.pack( '!BBBB', 1, 0, 0x01, 0x0e) )
#pulse width
    ser.write( struct.pack( '!BBBB', 1, 0, 0x02, 0x00) )
    ser.write( struct.pack( '!BBBB', 1, 0, 0x03, 0x08) )
#wave+gate
    ser.write( struct.pack( '!BBBB', 1, 0, 0x04, 0x41) )
#ad
    ser.write( struct.pack( '!BBBB', 1, 0, 0x05, 0x00) )
#sr 
    ser.write( struct.pack( '!BBBB', 1, 0, 0x06, 0xf0) )

#ch2
#440Hz 1cd6
    ser.write( struct.pack( '!BBBB', 1, 0, 0x07, 0xd6) )
    ser.write( struct.pack( '!BBBB', 1, 0, 0x08, 0x1c) )
#pulse width
    ser.write( struct.pack( '!BBBB', 1, 0, 0x09, 0x00) )
    ser.write( struct.pack( '!BBBB', 1, 0, 0x0a, 0x08) )
#wave+gate
    ser.write( struct.pack( '!BBBB', 1, 0, 0x0b, 0x41) )
#ad
    ser.write( struct.pack( '!BBBB', 1, 0, 0x0c, 0x00) )
#sr 
    ser.write( struct.pack( '!BBBB', 1, 0, 0x0d, 0xf0) )

#ch3
#880Hz 39ac
    ser.write( struct.pack( '!BBBB', 1, 0, 0x0e, 0xac) )
    ser.write( struct.pack( '!BBBB', 1, 0, 0x0f, 0x39) )
#pulse width
    ser.write( struct.pack( '!BBBB', 1, 0, 0x10, 0x00) )
    ser.write( struct.pack( '!BBBB', 1, 0, 0x11, 0x08) )
#wave+gate
    ser.write( struct.pack( '!BBBB', 1, 0, 0x12, 0x41) )
#ad
    ser.write( struct.pack( '!BBBB', 1, 0, 0x13, 0x00) )
#sr 
    ser.write( struct.pack( '!BBBB', 1, 0, 0x14, 0xf0) )

#FC lo/hi FC=f/47
    ser.write( struct.pack( '!BBBB', 1, 0, 0x15, 0x00) )
    ser.write( struct.pack( '!BBBB', 1, 0, 0x16, 0x14) )
##res/filt
    ser.write( struct.pack( '!BBBB', 1, 0, 0x17, 0x07) )
#mode/vol
    ser.write( struct.pack( '!BBBB', 1, 0, 0x18, 0x1f) )

    ser.write( struct.pack( '!BBBB', 1, 0, 0x0f, 0x00) )
    status = ser.read()

except serial.serialutil.SerialTimeoutException:
    conn.close()
    s.close()
    ser = None
    print 'serial device removed'
    time.sleep( 1 )
