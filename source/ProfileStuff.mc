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
    
    // BLE variables
    hidden var _device;
    hidden var _bleDelegate;
    hidden var scanForUuid = null;
    hidden var writeBusy = false;

    hidden var _profileManagerStuff;
    hidden var _pendingNotifies;
    hidden var _isConnected = false;
    
    hidden var stack = new[0];
    

	public function wordToUuid(uuid)
	{
		
		return Ble.longToUuid(0x0000000000001000l + ((uuid & 0xffff).toLong() << 32), 0x800000805f9b34fbl);
	}
    
    
	public const FITNESS_MACHINE_SERVICE 	   			= wordToUuid(0x1818);
	public const POWER_MEASUREMENT_CHARACTERISTIC 	    = wordToUuid(0x2a63);
	public const POWER_VECTOR_CHARACTERISTIC            = wordToUuid(0x2a64);
	public const TREADMILL_CONTROL_POINT 				= wordToUuid(0x2a66);
	
	
	
	function isConnected()
	{
		return _isConnected;
	}
	
    private const _fitnessProfileDef = 
    {
    	:uuid => FITNESS_MACHINE_SERVICE,				
        :characteristics => [
        {
            :uuid => POWER_MEASUREMENT_CHARACTERISTIC,:descriptors => [Ble.cccdUuid()]
        },
        {
        	:uuid => POWER_VECTOR_CHARACTERISTIC,:descriptors => [Ble.cccdUuid()]			
            
        },
        {
        	:uuid => TREADMILL_CONTROL_POINT				
        	
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
        else if ( _pendingNotifies.size() > 0 ) {
        
        	System.println("processCccdWrite");
            activateNextNotification();
            
            _pendingNotifies = [];
        }
        else {
            _pendingNotifies = [];
        }
    }
    
    function pushWrite(obj)   //need this so BLE doesn't throw exception if two writerequests come-in before BLE can process them
	{	
		stack.add(obj);
		handleStack();
	}
    function handleStack()
    {
    	if (stack.size() == 0) {return;} // nothing to do
    	if (writeBusy == true) {return;}// already busy.  nothing to do
    	
    	var characteristic = _device.getService(FITNESS_MACHINE_SERVICE ).getCharacteristic(TREADMILL_CONTROL_POINT);
		try
		{
			writeBusy = true;
			characteristic.requestWrite(stack[0],{:writeType=>BluetoothLowEnergy.WRITE_TYPE_DEFAULT});
		
		   //characteristic.requestRead();
		}
		catch (ex)
		{
			System.println("EXCEPTION: " + ex.getErrorMessage());
		}
    }
    function onCharacteristicWrite(char, value)    //called after write is complete
    {
    	System.println("**callback characteristic Write.  SI: " + stack.size() + "Characteristic: " + char + ".  Value: " + value);
    	if (stack.size() == 0) 
    	{
    		System.println("onCharasteristic write called in error si=0");
    		return;
    	}
    	writeBusy = false;
    	
    	stack = stack.slice(1,null);
    	if (stack.size() > 0) {handleStack();}
       //pop-off
    	var ch = char;
    	var v = value;
    	
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
			System.println("POWER_MEASUREMENT_CHARACTERISTIC");
		
			var offset = 0;
			var flags = value.decodeNumber( Lang.NUMBER_FORMAT_UINT8, { :offset => offset });
			offset+=1;
			
			inst_power = value.decodeNumber( Lang.NUMBER_FORMAT_SINT16, { :offset => offset });
			offset+=2;
			
		}
		
		if (cu.equals(POWER_VECTOR_CHARACTERISTIC))
		{
			System.println("POWER_VECTOR_CHARACTERISTIC");
			
			var offset = 0;
			var flags = value.decodeNumber( Lang.NUMBER_FORMAT_UINT8, { :offset => offset });
			offset+=1;
			
			if (flags & 0x1)
			{
				f_mag_array = [];
				inst_torque_mag_array = [];
				
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
				
				f_mag_array = f_mag_array.add( tmp );
			}
			
			while (flags & 0x8 && offset < value.size())
			{
				var tmp = value.decodeNumber( Lang.NUMBER_FORMAT_SINT16, { :offset => offset });
				offset+=2;
				
				inst_torque_mag_array = inst_torque_mag_array.add( tmp );
			}
			
		    WatchUi.requestUpdate();
	         
		}
		
		
	}
	
//	function setSpeed ( speed )
//    {
//	    if (speed < 0) {speed = 0;}
//	    if (speed > 12) {speed = 12;}
//        var kph = speed * 160.934;
//        var long1 = kph.toLong();//convert to kph and multiply by one humdred
//        var b1 = [0x02,0,0]b;   //starting with 2 means set speed
//        b1.encodeNumber(long1,Lang.NUMBER_FORMAT_UINT16,{:offset=>1,:endianness=>Lang.ENDIAN_LITTLE});
//        
//       	System.println("speed");
//        pushWrite(b1);
//    }
//    function setIncline ( incline )
//    {
//        var incl = incline * 10.0;
//        var long1 = incl.toLong();//convert to kph and multiply by one humdred
//        var b1 = [0x03,0,0]b;   //starting with 2 means set speed
//        b1.encodeNumber(long1,Lang.NUMBER_FORMAT_UINT16,{:offset=>1,:endianness=>Lang.ENDIAN_LITTLE});
//        
//       	System.println("incline");
//       	pushWrite(b1);
//    }
	
	function onConnectedStateChanged( device, state )
	{
		if (state == Ble.CONNECTION_STATE_CONNECTED)
		{
			_isConnected = true;
			WatchUi.requestUpdate();
			_device = device;
	    	System.println("BleDelegate.onConnectedStateChanged");

			var service = device.getService(FITNESS_MACHINE_SERVICE );
			
			var characteristic = service.getCharacteristic(POWER_VECTOR_CHARACTERISTIC);
 	        var cccd = characteristic.getDescriptor(Ble.cccdUuid());
 	        cccd.requestWrite([0x01, 0x00]b);
	
			_pendingNotifies = [];
	        characteristic = service.getCharacteristic(POWER_MEASUREMENT_CHARACTERISTIC );
	        if( null != characteristic ) {
	            _pendingNotifies = _pendingNotifies.add( characteristic );
	        }
	    }
	    if (state == Ble.CONNECTION_STATE_DISCONNECTED)
	    {
	    	_isConnected = false;
	    	System.println("Disconnected");

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
			System.println("BleDelegate.onScanResults UUID="+result.getRawData());
			System.println("BleDelegate.onScanResults UUID="+result.getServiceUuids());
			var raw_bytes = [3, 25, 128, 4, 2, 1, 6, 18, 9, 84, 97, 99, 120, 32, 78, 101, 111, 32, 50, 84, 32, 49, 53, 53, 54, 56];
            if( result.getRawData()[2] == 128 )  // result.getRawData()[2] == 128 contains( result.getServiceUuids(), scanForUuid)
            {
            
        		 Ble.setScanState( Ble.SCAN_STATE_OFF );
    			var d = Ble.pairDevice( result );
            }
        }
    
	}
	
	function onDescriptorWrite(descriptor, status) 
    {
        if( Ble.cccdUuid().equals( descriptor.getUuid() ) ) {
            processCccdWrite( status );
        }
    }
	
	
    

    

    

    /*
    
    
    
    
    

function onDescriptorWrite(descriptor, status) 
    {
        if( Ble.cccdUuid().equals( descriptor.getUuid() ) ) 
        {
            processCccdWrite( status );
        }
        else
        {
        
        }
    }


    private function processCccdWrite( status ) 
    {
        if( _pendingNotifies.size() > 1 ) 
        {
            _pendingNotifies = _pendingNotifies.slice(1,_pendingNotifies.size() );
			activateNextNotification();
        }
        else {
            _pendingNotifies = [];
        }
    }
   

    */

    
   
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
    	var q = 42;
        
    }

    
	
    
}

