using Toybox.Application;
using Toybox.WatchUi;
using Plexit.Menu;
using Plexit.Storage;

class PlexitApp extends Application.AudioContentProviderApp {

    function initialize() {
        AudioContentProviderApp.initialize();

        // perform storage check and fix if possible
        Storage.check();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }
    
    function onSettingsChanged() {
    	// reset the sessions for the provider
    	Plexit.Provider.onSettingsChanged();

        // reload the media profile
        Media.requestPlaybackProfileUpdate();
    }

    // Get a Media.ContentDelegate for use by the system to get and iterate through media on the device
    function getContentDelegate(arg) {
        return new PlexitContentDelegate();
    }

    // Get a delegate that communicates sync status to the system for syncing media content to the device
    function getSyncDelegate() {
        var syncrequest = Application.Storage.getValue(Storage.SYNC_REQUEST);
        // return deprecated if sync was not started from the menu (i.e. autostart)
        if (syncrequest != true) {
            return new Plexit.SyncDelegate_deprecated();
        }
        return new Plexit.SyncDelegate();
    }

    // Get the initial view for configuring playback
    function getPlaybackConfigurationView() {
        var menu = new Menu.Playback();
        menu.load();    // menu needs to be loaded when MenuLoader is not used
    	return [ new Menu.MenuView(menu), menu.delegate() ];
    }

    // Get the initial view for configuring sync
    function getSyncConfigurationView() {
        var menu = new Menu.Sync();
        menu.load();    // menu needs to be loaded when MenuLoader is not used
    	return [ new Plexit.Menu.MenuView(menu), menu.delegate() ];
    }
    
    function popView() {
    	WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
