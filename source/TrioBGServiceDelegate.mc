//**********************************************************************
// DESCRIPTION : service delegation of Trio connexion
// AUTHORS :
//          Created by ivalkou - https://github.com/ivalkou
//          Modify by Pierre Lagarde - https://github.com/avouspierre
// COPYRIGHT : (c) 2023 ivalkou / Lagarde
//

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Background;
import Toybox.System;
import Toybox.Communications;

(:background)
class TrioBGServiceDelegate extends System.ServiceDelegate {


    function initialize() {
        ServiceDelegate.initialize();
        //for fenix 5 if required

         if (Background has :registerForPhoneAppMessageEvent) {
                // nothing to do
        } else {
                Communications.registerForPhoneAppMessages(method(:onReceiveMessage) as Communications.PhoneMessageCallback);
                System.println("****add the registerForPhoneAppMessages done****");
        }
    }

    function onReceiveMessage(msg) {
        System.println("a message from onReceiveMessage! ");
        System.println(msg);
        Background.exit(msg.data);
    }

    function onTemporalEvent() {
        System.println("Temp event");
        Communications.transmit("status", null, new CommsRelay(method(:onTransmitComplete)));
        // Let onTransmitComplete handle Background.exit() after transmit completes
    }

    function onPhoneAppMessage(msg) {
        System.println("****onPhoneAppMessage*****");
        System.println(msg);
        var data = msg.data;
        
        if (data instanceof Array) {
            // Extract first element if it's an array
            if (data.size() > 0) {
                var firstEntry = data[0];
                if (firstEntry instanceof Dictionary) {
                    Application.Storage.setValue("status", firstEntry as Dictionary);
                }
            }
        } else if (data instanceof Dictionary) {
            // Store directly if it's already a dictionary
            Application.Storage.setValue("status", data as Dictionary);
        }
        
        Background.exit(true);
    }

    function onTransmitComplete(isSuccess) {
        if (isSuccess) {
            System.println("Listener onComplete");
        } else {
            System.println("Listener onError");
        }
        Background.exit(isSuccess);
    }
}