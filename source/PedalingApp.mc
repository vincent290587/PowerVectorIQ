using Toybox.Application;

class PedalingApp extends Application.AppBase {

    private var _treadmillProfile = null;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
        //Create the sensor object and open it
        try {
            _treadmillProfile = new TreadmillProfile();
            _treadmillProfile.registerProfiles();
        } catch (e) {
            System.println(e.getErrorMessage());
        }
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
        _treadmillProfile = null;
    }

    //! Return the initial view of your application here
    function getInitialView() {
        return [ new PedalingView(_treadmillProfile) ];
    }

}