using Toybox.Application;

class PedalingApp extends Application.AppBase {

    var _treadmillProfile = null;

    function initialize() {
        AppBase.initialize();
        _treadmillProfile = new TreadmillProfile();
    }

    // onStart() is called on application start up
    function onStart(state) {
        _treadmillProfile.scanFor(_treadmillProfile.FITNESS_MACHINE_SERVICE);
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
        _treadmillProfile.unpair();
    }

    //! Return the initial view of your application here
    function getInitialView() {
        return [ new PedalingView(_treadmillProfile) ];
    }

}