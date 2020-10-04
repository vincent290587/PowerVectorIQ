using Toybox.WatchUi;
using Toybox.Graphics;

class PedalingView extends WatchUi.DataField {

    hidden var mValue;
	var _treadmillProfile;
	//var backgroundLayer;

    function initialize(tp) {
        DataField.initialize();
		_treadmillProfile = tp;
		
        mValue = 0;
        
        // create a 240x240 layer, at [0,0] offset from the top-left corner of the screen
		//backgroundLayer = new WatchUi.Layer();
		// add layer to View as background
		//View.addLayer(backgroundLayer);
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc) {
        var obscurityFlags = DataField.getObscurityFlags();

        // Top left quadrant so we'll use the top left layout
        if (obscurityFlags == (OBSCURE_TOP | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.TopLeftLayout(dc));

        // Top right quadrant so we'll use the top right layout
        } else if (obscurityFlags == (OBSCURE_TOP | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.TopRightLayout(dc));

        // Bottom left quadrant so we'll use the bottom left layout
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.BottomLeftLayout(dc));

        // Bottom right quadrant so we'll use the bottom right layout
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.BottomRightLayout(dc));

        // Use the generic, centered layout
        } else {
            View.setLayout(Rez.Layouts.MainLayout(dc));
            var labelView = View.findDrawableById("label");
            labelView.locY = labelView.locY - 16;
            var valueView = View.findDrawableById("value");
            valueView.locY = valueView.locY + 7;
        }

        View.findDrawableById("label").setText(Rez.Strings.label);
        return true;
    }

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info) {
    
        mValue = _treadmillProfile.inst_power;
    }
    
    private function _drawArc(dc, centerX, centerY, radius, startAngle, endAngle, fill) {
        var points = new [30];
        var halfHeight = dc.getHeight() / 2;
        var halfWidth = dc.getWidth() / 2;
        var radius = ( halfHeight > halfWidth ) ? halfWidth : halfHeight;
        var arcSize = points.size() - 2;
        for(var i = arcSize; i >= 0; --i) {
            var angle = ( i / arcSize.toFloat() ) * ( endAngle - startAngle ) + startAngle;
            points[i] = [halfWidth + radius * Math.cos(angle), halfHeight + radius * Math.sin(angle)];
        }
        points[points.size() - 1] = [halfWidth, halfHeight];

        if(fill) {
            dc.fillPolygon(points);
        }
        else {
            for(var i = 0; i < points.size() - 1; ++i) {
                dc.drawLine(points[i][0], points[i][1], points[i+1][0], points[i+1][1]);
            }
            dc.drawLine(points[points.size()-1][0], points[points.size()-1][1], points[0][0], points[0][1]);
        }
    }
    
	private function min(b1_i, b2_i)
	{
	  if (b1_i > b2_i) {
	  	return b2_i;
	  }
	  return b1_i;
    }
    
	private function max(b1_i, b2_i)
	{
	  if (b1_i < b2_i) {
	  	return b2_i;
	  }
	  return b1_i;
    }
    
	private function map(val, b1_i, b1_f, b2_i, b2_f)
	{
	
	  if (b1_f == b1_i) {
	  	return b2_i;
	  }
	
	  var x;
	  var res;
	  // calcul x
	  x = (val - b1_i) / (b1_f - b1_i);
	  
	  // calcul valeur: x commun
	  res = x * (b2_f - b2_i) + b2_i;
	  if (res < min(b2_i,b2_f))
	  {
	  	res = min(b2_i,b2_f);
	  }
	  if (res > max(b2_i,b2_f))
      {
      	res = max(b2_i,b2_f);
      }
	  return res;
	}
	
	private function draw_power_vector( dc ) 
    {
        
        var width;
        var height;
        
        var max_circle_diam = 90;

        width = dc.getWidth();
        height = dc.getHeight();
        
        if (_treadmillProfile.inst_torque_mag_array.size() > 0)
        {
	        var max_torque;
	        
	        // calculate the max torque
	        max_torque = _treadmillProfile.inst_torque_mag_array[0];
	        for (var i=1 ; i < _treadmillProfile.inst_torque_mag_array.size(); i++)
	        {
	        	if (max_torque < _treadmillProfile.inst_torque_mag_array[i])
	        	{
	        		max_torque = _treadmillProfile.inst_torque_mag_array[i];
	        	}
	        }
	        
	        // map the current torque to the max torque
	        var delta_angle = 359.0f / _treadmillProfile.inst_torque_mag_array.size();
	        for (var i=0 ; i < _treadmillProfile.inst_torque_mag_array.size(); i++)
	        {
	        	var cur_angle_deg = _treadmillProfile.first_crank_angle + map(i, 0.0f, _treadmillProfile.inst_torque_mag_array.size(), 0, 360.0f);
	        	var cur_torque_dr = map(_treadmillProfile.inst_torque_mag_array[i], 0.0f, max_torque, 0.0f, max_circle_diam);
	        	
	        	if (cur_angle_deg > 359)
	        	{
	        		cur_angle_deg = cur_angle_deg - 360;
	        	}

		        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
		        
		        for (var th=0; th < 4; ++th)
		        {
			        dc.drawArc(width / 2, height / 2, cur_torque_dr+th, Graphics.ARC_COUNTER_CLOCKWISE, 
			        	cur_angle_deg - delta_angle/2, cur_angle_deg + delta_angle/2);
		        }
	        }
        
        }
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc) {
    
        // Set the background color
        View.findDrawableById("Background").setColor(getBackgroundColor());

        // Set the foreground color and value
        var value = View.findDrawableById("value");
        var foreground_color = Graphics.COLOR_BLACK;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            foreground_color = Graphics.COLOR_WHITE;
        }
        value.setColor(foreground_color);
        value.setText(mValue.format("%d"));

        // Call parent's onUpdate(dc) to redraw the layout
        View.onUpdate(dc);
        
        //backgroundLayer.setX(dc.getWidth()/2);
        //backgroundLayer.setY(dc.getWidth()/2);
        
        // next, draw on the DC (View.onUpdate(dc) clears it !)
        draw_power_vector(dc); // backgroundLayer.getDc()
    }

}
