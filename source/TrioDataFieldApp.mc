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
    var inBackground=false;
    
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
        
        // This will always give you a timestamp from exactly 4 minutes ago
        var currentTime = Time.now().value();
        var minutesAgo = currentTime - 240; // 240 seconds = 4 minutes
        var minutesAgoMillis = minutesAgo * 1000; // Convert to milliseconds
        
        // Sample data with mg/dL units
        var sample = {
            "sgv" => 145,
            "date" => minutesAgoMillis, // In milliseconds
            "delta" => -15,
            "direction" => "FortyFiveDown",
            "units_hint" => "mgdl",
            "iob" => 2.5,
            "cob" => 25,
            "tbr" => 1.45,           // Basal rate in U/hr
            "eventualBG" => 89,
            "isf" => 50,
            "sensRatio" => 0.65,
            "displayDataType1" => "sensRatio",   // Right side: sensRatio, isf, or cob
            "displayDataType2" => "eventualBG"   // Middle: eventualBG or tbr
        } as Dictionary;
        
        //uncomment for testing
        //Application.Storage.setValue("status", sample);
    }

    function onBackgroundData(data) {
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
        if(!inBackground) {
            System.println("stop temp event");
            Background.deleteTemporalEvent();
        }
    }

    //! Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new TrioDataFieldView() ] as [Views];
    }

    function getServiceDelegate() {
        inBackground=true;
        System.println("start background");
        return [new TrioBGServiceDelegate()];
    }
}

function getApp() as TrioDataFieldApp {
    return Application.getApp() as TrioDataFieldApp;
}