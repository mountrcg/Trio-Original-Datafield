//**********************************************************************
// DESCRIPTION : Application for data field for Trio
// AUTHORS :
// Created by ivalkou - https://github.com/ivalkou
// Modify by Pierre Lagarde - https://github.com/avouspierre
// Modified to display IOB with blue drop icon instead of delta
// COPYRIGHT : (c) 2023 ivalkou / Lagarde
//
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Background;
import Toybox.Time;
import Toybox.System;
import Toybox.Communications;
import Toybox.Graphics;

(:background)
class TrioDataFieldApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        //register for temporal events if they are supported
        if(Toybox.System has :ServiceDelegate) {
            // canDoBG=true;
            Background.registerForTemporalEvent(new Time.Duration(5 * 60));
            if (Background has :registerForPhoneAppMessageEvent) {
                Background.registerForPhoneAppMessageEvent();
                System.println("****background is ok****");
            } else {
                System.println("****registerForPhoneAppMessageEvent is not available****");
            }
        } else {
            System.println("****background not available on this device****");
        }
        
        // Calculate timestamps for test data
        var currentTime = Time.now().value();
        var loopSecondsAgo = 120; // Loop ran 2 minutes ago
        var glucoseSecondsAgo = 330; // Glucose reading ~5.5 min ago
        var loopDateMs = (currentTime - loopSecondsAgo).toLong() * 1000;
        var glucoseDateMs = (currentTime - glucoseSecondsAgo).toLong() * 1000;

        // Sample data with mg/dL units
        var sample = {
            "sgv" => 115,
            "date" => loopDateMs, // Loop timestamp in milliseconds
            "glucoseDate" => glucoseDateMs, // Glucose reading timestamp
            "delta" => -15,
            "direction" => "FortyFiveDown",
            "units_hint" => "mgdl",
            "iob" => 2.5,
            "cob" => 25,
            "tbr" => 1.45,           // Basal rate in U/hr
            "eventualBG" => 89,
            "isf" => 50,
            "sensRatio" => 0.65,
            "displayPrimaryAttributeChoice" => "sensRatio", // Right side: sensRatio, isf, or cob
            "displaySecondaryAttributeChoice" => "eventualBG" // Middle: eventualBG or tbr
        } as Dictionary;
        
        //uncomment for testing
        //Application.Storage.setValue("status", sample);
    }

    function onBackgroundData(data) {
        // Handle Boolean from onTransmitComplete (status request result)
        if (data instanceof Lang.Boolean) {
            if (data == true) {
                System.println("Trio: Status transmit succeeded - re-registering temporal event");
                Background.deleteTemporalEvent();
                Background.registerForTemporalEvent(new Time.Duration(5 * 60));
            } else {
                System.println("Trio: Status transmit failed");
            }
            return;
        }

        if (data instanceof Number || data == null) {
            System.println("Not a dictionary/array");
        } else {
            System.println("try to update the status");
            if (Background has :registerForPhoneAppMessageEvent) {
                System.println("updated with registerForPhoneAppMessageEvent");
            } else {
                System.println("update status");
                
                // Handle both Array and Dictionary formats
                if (data instanceof Array) {
                    // Extract first element if it's an array
                    if (data.size() > 0) {
                        var firstEntry = data[0];
                        if (firstEntry instanceof Dictionary) {
                            Application.Storage.setValue("status", firstEntry as Dictionary);
                        }
                    }
                } else if (data instanceof Dictionary) {
                    Application.Storage.setValue("status", data as Dictionary);
                }
                
                Background.registerForTemporalEvent(new Time.Duration(5 * 60));
            }
        }
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        System.println("stop temp event");
        Background.deleteTemporalEvent();
    }

    //! Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new TrioDataFieldView() ] as [Views];
    }

    function getServiceDelegate() {
        System.println("start background");
        return [new TrioBGServiceDelegate()];
    }
}

function getApp() as TrioDataFieldApp {
    return Application.getApp() as TrioDataFieldApp;
}