using Toybox.System as Sys;
using Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Lang;


class TreadmillProfile
{

    // BLE profile variables
    var inst_power;

    var cumul_crank_rev = 0;
    var last_crank_evt = 0;
    var first_crank_angle = 0;

    var inst_torque_mag_array;
    var f_mag_array;

    var committed_torque_mag_array;
    var committed_force_mag_array;

    // BLE variables
    hidden var _device;
    hidden var _bleDelegate;
    hidden var scanForUuid = null;
    hidden var writeBusy = false;

    hidden var _profileManagerStuff;
    hidden var _pendingNotifies;
    hidden var _isConnected = false;


    public function wordToUuid(uuid)
    {

        return Ble.longToUuid(0x0000000000001000l + ((uuid & 0xffff).toLong() << 32), 0x800000805f9b34fbl);
    }


    public const FITNESS_MACHINE_SERVICE                = wordToUuid(0x1818);
    public const POWER_MEASUREMENT_CHARACTERISTIC       = wordToUuid(0x2a63);
    public const POWER_VECTOR_CHARACTERISTIC            = wordToUuid(0x2a64);
    public const TREADMILL_CONTROL_POINT                = wordToUuid(0x2a66);


    function isConnected()
    {
        return _isConnected;
    }

    private const _fitnessProfileDef =
    {
        :uuid => FITNESS_MACHINE_SERVICE,
        :characteristics => [
        {
            :uuid => POWER_MEASUREMENT_CHARACTERISTIC,
            :descriptors => [
                Ble.cccdUuid()
            ]
        },
        {
            :uuid => POWER_VECTOR_CHARACTERISTIC,
            :descriptors => [
                Ble.cccdUuid()
            ]

        }]
    };

    function unpair()
    {
        Ble.unpairDevice( _device );
        _device = null;
        System.println("Unpaired");
    }

    function scanFor (serviceToScanFor)
    {
        System.println("ScanMenuDelegate.starting scan");
        scanForUuid = serviceToScanFor;
        Ble.setScanState( Ble.SCAN_STATE_SCANNING );
    }

    function initialize (  )
    {
        Ble.registerProfile( _fitnessProfileDef );
        _bleDelegate = new TreadmillDelegate(self);  //pass it this
        Ble.setDelegate( _bleDelegate );

        inst_power = 0;

        cumul_crank_rev = 0;
        last_crank_evt = 0;
        first_crank_angle = 10;

        inst_torque_mag_array = [];
        f_mag_array = [];

        committed_torque_mag_array = [50, 60, 70, 90];
        committed_force_mag_array = [];
    }

    private function activateNextNotification() {
        if( _pendingNotifies.size() == 0 ) {
            return;
        }

        var char = _pendingNotifies[0];
        var cccd = char.getDescriptor(Ble.cccdUuid());
        cccd.requestWrite([0x01, 0x00]b);
    }

    private function processCccdWrite( status ) {
        if( _pendingNotifies.size() > 1 ) {

            System.println("processCccdWrite");
            _pendingNotifies = _pendingNotifies.slice(
                1,
                _pendingNotifies.size() );

            activateNextNotification();
        }
        else {
            _pendingNotifies = [];
        }
    }

    function onCharacteristicRead(char, value)
    {
        var ch = char;
        var v = value;

    }

    function onCharacteristicChanged(char, value)
    {
        var name = _device.getName();
        var cu = char.getUuid();

        if (cu.equals(POWER_MEASUREMENT_CHARACTERISTIC))
        {
            //System.println("POWER_MEASUREMENT_CHARACTERISTIC");

            var offset = 0;
            var flags = value.decodeNumber( Lang.NUMBER_FORMAT_UINT16, { :offset => offset });
            offset+=2;

            inst_power = value.decodeNumber( Lang.NUMBER_FORMAT_SINT16, { :offset => offset });
            offset+=2;

        }

        if (cu.equals(POWER_VECTOR_CHARACTERISTIC))
        {
            var order_refresh = 0;
            var offset = 0;
            var flags = value.decodeNumber( Lang.NUMBER_FORMAT_UINT8, { :offset => offset });
            offset+=1;

            System.println("POWER_VECTOR_CHARACTERISTIC flags:" + flags);

            if (flags & 0x1)
            {

                committed_torque_mag_array = [];
                committed_force_mag_array = [];

                // commit temporary arrays
                committed_torque_mag_array.addAll(inst_torque_mag_array);
                committed_force_mag_array.addAll(f_mag_array);

                System.println("Commiting array size: " + inst_torque_mag_array.size());

                // order a refresh later
                order_refresh = 1;

                // reset temporary arrays
                inst_torque_mag_array = [];
                f_mag_array = [];

                cumul_crank_rev = value.decodeNumber( Lang.NUMBER_FORMAT_UINT16, { :offset => offset });
                offset+=2;

                last_crank_evt = value.decodeNumber( Lang.NUMBER_FORMAT_UINT16, { :offset => offset });
                offset+=2;
            }

            if (flags & 0x2)
            {
                first_crank_angle = value.decodeNumber( Lang.NUMBER_FORMAT_UINT16, { :offset => offset });
                offset+=2;
            }

            while (flags & 0x4 && offset < value.size())
            {
                var tmp = value.decodeNumber( Lang.NUMBER_FORMAT_SINT16, { :offset => offset });
                offset+=2;

                f_mag_array.add( tmp );
            }

            while (flags & 0x8 && offset < value.size())
            {
                var tmp = value.decodeNumber( Lang.NUMBER_FORMAT_SINT16, { :offset => offset });
                offset+=2;

                inst_torque_mag_array.add( tmp );
            }

            if (order_refresh > 0)
            {
                WatchUi.requestUpdate();
            }

        }


    }

    function onConnectedStateChanged( device, state )
    {
        if( device != _device ) {
            // Not our device
            return;
        }

        if (device.isConnected())
        {
            _isConnected = true;
            WatchUi.requestUpdate();
            _device = device;
            System.println("Ble.CONNECTION_STATE_CONNECTED");

            var service = device.getService(FITNESS_MACHINE_SERVICE);

            _pendingNotifies = [];

            if ( service != null )
            {
                // get char1
                var characteristic = service.getCharacteristic(POWER_MEASUREMENT_CHARACTERISTIC);
                if ( null != characteristic )
                {
                    System.println("Subscribed to POWER_VECTOR_CHARACTERISTIC");
                    _pendingNotifies = _pendingNotifies.add( characteristic );
                }

                // get char2
                characteristic = service.getCharacteristic(POWER_VECTOR_CHARACTERISTIC);
                if( null != characteristic ) {
                    System.println("Subscribed to POWER_MEASUREMENT_CHARACTERISTIC");
                    _pendingNotifies = _pendingNotifies.add( characteristic );
                }

                activateNextNotification();

            }
        } else {
            _isConnected = false;
            _device = null;
            System.println("Disconnected");
            Ble.setScanState( Ble.SCAN_STATE_SCANNING );

            _pendingNotifies = [];
        }
    }

    private function contains( iter, obj )
    {
        for( var uuid = iter.next(); uuid != null; uuid = iter.next() )
        {
            if( uuid.equals( obj ) )
            {
                return true;
            }
        }
        return false;
    }

    function onScanResults (scanResults)
    {

        for( var result = scanResults.next(); result != null; result = scanResults.next() )
        {
            System.println("BleDelegate.onScanResults RSSI="+result.getRssi());
            System.println("BleDelegate.onScanResults UUID="+result.getDeviceName());
            System.println("BleDelegate.onScanResults UUID="+result.getServiceUuids());

            var name = result.getDeviceName();

            if( name.find("Neo") >= 0 )  // result.getRawData()[2] == 128 contains( result.getServiceUuids(), scanForUuid)
            {
                Ble.setScanState( Ble.SCAN_STATE_OFF );
                _device = Ble.pairDevice( result );
            }
        }

    }

    function onDescriptorWrite(descriptor, status)
    {
        if( Ble.cccdUuid().equals( descriptor.getUuid() ) ) {
            processCccdWrite( status );
        }
    }

}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////


class TreadmillDelegate extends Ble.BleDelegate
{

    var _parent = null;

    function initialize(parent  )
    {
        BleDelegate.initialize();
        _parent = parent;
        System.println("BleDelegate.initialize");
    }

    function onScanResults( scanResults )
    {
        if (_parent != null)
        {
            _parent.onScanResults(scanResults);
        }
    }

    function onConnectedStateChanged( device, state )
    {
        if (_parent != null)
        {
            _parent.onConnectedStateChanged(device, state);
        }


    }

    function onCharacteristicChanged(char, value)
    {
        BleDelegate.onCharacteristicChanged(char, value);
        //System.println("**callback characteristic Changed");
        if (_parent != null)
        {
            _parent.onCharacteristicChanged(char, value);
        }

    }

    function onCharacteristicRead(char, value)
    {
        BleDelegate.onCharacteristicRead(char, value);
        System.println("**callback characteristic Read");
        if (_parent != null)
        {
            _parent.onCharacteristicRead(char, value);
        }

    }

    function onCharacteristicWrite(char, value)
    {
        BleDelegate.onCharacteristicChanged(char, value);

        if (_parent != null)
        {
            _parent.onCharacteristicWrite(char, value);
        }

    }

    function onDescriptorWrite(descriptor, status)
    {
        System.println("**callback DESCRIPTOR write");

        if (_parent != null)
        {

            _parent.onDescriptorWrite(descriptor, status);
        }


    }

    function onDescriptorRead(descriptor, status)
    {
        System.println("**callback DESCRIPTOR read");
    }

}

