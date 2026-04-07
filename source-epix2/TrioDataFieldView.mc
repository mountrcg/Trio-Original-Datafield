//**********************************************************************
// DESCRIPTION : DataField for Trio
// AUTHORS :
//          Created by ivalkou - https://github.com/ivalkou
//          Modify by Pierre Lagarde - https://github.com/avouspierre
//          IOB displayed as text with U suffix (icon removed)
// COPYRIGHT : (c) 2023 ivalkou / Lagarde
//

import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

class TrioDataFieldView extends WatchUi.DataField {

    private var isBottomPosition = false;
    private var isRoundScreen = false;
    private var screenYOffset = 0;
    private var fullScreenRadius = 0;

    function initialize() {
        DataField.initialize();
    }

    function compute(info) {
    }

    function onLayout(dc as Dc) as Void {
        var obscurityFlags = DataField.getObscurityFlags();
        
        if ((obscurityFlags & OBSCURE_TOP) != 0) {
            isBottomPosition = true;
            View.setLayout(Rez.Layouts.MainLayout(dc));
        } else {
            isBottomPosition = false;
            View.setLayout(Rez.Layouts.BottomLayout(dc));
        }

        var deviceSettings = System.getDeviceSettings();
        isRoundScreen = (deviceSettings.screenShape == System.SCREEN_SHAPE_ROUND);
        if (isRoundScreen) {
            var fullScreenHeight = deviceSettings.screenHeight;
            fullScreenRadius = fullScreenHeight / 2;
            var dfHeight = dc.getHeight();
            // OBSCURE_BOTTOM = bottom edge clipped = field is at TOP of screen
            // OBSCURE_TOP = top edge clipped = field is at BOTTOM of screen
            if ((obscurityFlags & OBSCURE_BOTTOM) != 0) {
                screenYOffset = fullScreenHeight - dfHeight;
            } else if ((obscurityFlags & OBSCURE_TOP) != 0) {
                screenYOffset = 0;
            } else {
                screenYOffset = (fullScreenHeight - dfHeight) / 2;
            }
        }

        (View.findDrawableById("label") as Text).setText(Rez.Strings.label);

        var screenHeight = dc.getHeight();
        if (screenHeight <= 260) {
            var valueView = View.findDrawableById("value") as Text;
            if (valueView != null) {
                if (isBottomPosition) {
                    valueView.locY = dc.getHeight() * 0.10;
                } else {
                    valueView.locY = dc.getHeight() * 0.50;
                }
            }
            
            var labelView = View.findDrawableById("label") as Text;
            if (labelView != null) {
                if (isBottomPosition) {
                    labelView.locY = dc.getHeight() * 0.20;
                } else {
                    labelView.locY = dc.getHeight() * 0.60;
                }
            }
        }
    }

    function isMMOL(status) as Boolean {
        if (status instanceof Dictionary) {
            var unitsHint = status["units_hint"];
            return (unitsHint != null && unitsHint.equals("mmol"));
        }
        return false;
    }
    
    function convertGlucoseValue(value, status) as Float {
        if (value instanceof Number) {
            if (isMMOL(status)) {
                return value * 0.05556;
            }
            return value.toFloat();
        }
        return 0.0;
    }

    // Returns [safeLeftX, safeRightX] for a given Y position on round screens.
    // On rectangular screens, returns fixed 8% margins.
    function getSafeBounds(screenWidth as Number, localY as Number, padding as Number) as Array {
        var leftMargin = (screenWidth * 0.08).toNumber();
        var rightMargin = screenWidth - leftMargin;
        if (!isRoundScreen) {
            return [leftMargin, rightMargin];
        }
        var dy = (screenYOffset + localY - fullScreenRadius).toFloat();
        var r = fullScreenRadius.toFloat();
        var disc = r * r - dy * dy;
        if (disc <= 0) {
            return [screenWidth / 2, screenWidth / 2];
        }
        var halfChord = Math.sqrt(disc).toNumber();
        var circleLeft = fullScreenRadius - halfChord + padding;
        var circleRight = fullScreenRadius + halfChord - padding;
        return [
            (circleLeft > leftMargin) ? circleLeft : leftMargin,
            (circleRight < rightMargin) ? circleRight : rightMargin
        ];
    }

    function onUpdate(dc as Dc) as Void {
        var bgString;
        var loopColor;
        var evBGString;
        var rightSideString;
        var showingSensRatio = false;
        var showingEventualBG = false;
        var iobString;
        
        // Safely get status from storage - handle both Array and Dictionary
        var storageData = Application.Storage.getValue("status");
        var status = null;
        
        if (storageData != null) {
            if (storageData instanceof Lang.Array && storageData.size() > 0) {
                // Array received - take first element
                status = storageData[0];
            } else if (storageData instanceof Lang.Dictionary) {
                // Dictionary received - use directly
                status = storageData;
            }
        }

        if (status == null || !(status instanceof Lang.Dictionary)) {
            bgString = "---";
            loopColor = getLoopColor(-1);
            evBGString = "(---)";
            rightSideString = "??";
            iobString = "??";
            showingEventualBG = false;
        } else {
            bgString = getGlucoseText(status);
            var min = getMinutes(status);
            loopColor = getLoopColor(min);
            
            var displayType2 = status["displaySecondaryAttributeChoice"];
            
            if (displayType2 != null && displayType2.equals("eventualBG")) {
                evBGString = "(" + getEventualBGText(status) + ")";
                showingEventualBG = true;
            } else {
                // Fallback to TBR
                evBGString = "[" + getTBRText(status) + "]";
                showingEventualBG = false;
            }
            
            var displayType1 = status["displayPrimaryAttributeChoice"];
            
            if (displayType1 != null && displayType1.equals("sensRatio")) {
                rightSideString = getSensRatioText(status);
                showingSensRatio = true;
            } else if (displayType1 != null && displayType1.equals("isf")) {
                rightSideString = getISFText(status);
                showingSensRatio = true;
            } else {
                // Fallback to COB
                rightSideString = getCOBText(status);
                showingSensRatio = false;
            }
            
            iobString = getIOBText(status);
        }

        var screenWidth = dc.getWidth();
        var centerX = screenWidth / 2;
        var largeFont = Graphics.FONT_SYSTEM_LARGE;
        var xtinyFont = Graphics.FONT_SYSTEM_XTINY;
        var roundPadding = 8;
        var isFullWidthField = !isRoundScreen || (screenWidth > fullScreenRadius);
        var bottomLinePadding = (isRoundScreen && isFullWidthField) ? 42 : 8;

        var currentValueWidth = dc.getTextWidthInPixels(bgString, largeFont);

        var labelView = View.findDrawableById("label");
        if (labelView != null) {
            var labelX = centerX - (currentValueWidth / 2) - (screenWidth * 0.07);
            if (isRoundScreen) {
                var bgBounds = getSafeBounds(screenWidth, labelView.locY, roundPadding);
                if (labelX < bgBounds[0]) { labelX = bgBounds[0]; }
            }
            labelView.locX = labelX;
        }

        var valueViewArrow = View.findDrawableById("arrow");
        if (valueViewArrow != null) {
            var arrowX = centerX + (currentValueWidth / 2) + (screenWidth * 0.03);
            if (isRoundScreen) {
                var bgBounds = getSafeBounds(screenWidth, valueViewArrow.locY, roundPadding);
                if (arrowX > bgBounds[1]) { arrowX = bgBounds[1]; }
            }
            valueViewArrow.locX = arrowX;
        }

        var valueViewIOB = View.findDrawableById("valueIOB");
        var valueViewIOBUnit = View.findDrawableById("valueIOBUnit");
        var valueViewEventualBG = View.findDrawableById("valueEventualBG");

        var secondLineFont = isRoundScreen ? (isFullWidthField ? Graphics.FONT_SYSTEM_MEDIUM : Graphics.FONT_SYSTEM_SMALL) : largeFont;
        if (isRoundScreen) {
            if (valueViewIOB != null) { (valueViewIOB as Text).setFont(secondLineFont); }
            if (valueViewIOBUnit != null) { (valueViewIOBUnit as Text).setFont(xtinyFont); }
        }

        var secondLineY = (valueViewIOB != null) ? valueViewIOB.locY : 0;
        var slBounds = getSafeBounds(screenWidth, secondLineY, bottomLinePadding);
        var safeLeft = slBounds[0];
        var safeRight = slBounds[1];

        if (valueViewIOB != null && valueViewIOBUnit != null) {
            var iobTextWidth = dc.getTextWidthInPixels(iobString, secondLineFont);
            var iobStartX = safeLeft;
            
            valueViewIOB.locX = iobStartX;
            (valueViewIOB as Text).setJustification(Graphics.TEXT_JUSTIFY_LEFT);
            
            valueViewIOBUnit.locX = iobStartX + iobTextWidth + 2;
            (valueViewIOBUnit as Text).setJustification(Graphics.TEXT_JUSTIFY_LEFT);

            var slHeight = dc.getFontHeight(secondLineFont);
            var xtinyHeight = dc.getFontHeight(xtinyFont);
            valueViewIOBUnit.locY = valueViewIOB.locY + (slHeight - xtinyHeight) * 0.8;
        }

        var valueViewAiSRIcon = View.findDrawableById("aiSRIcon");
        var valueViewAiSR = View.findDrawableById("valueAiSR");
        var valueViewAiSRUnit = View.findDrawableById("valueAiSRUnit");

        if (isRoundScreen && valueViewAiSR != null) {
            (valueViewAiSR as Text).setFont(secondLineFont);
        }

        if (showingSensRatio) {
            if (valueViewAiSRIcon != null && valueViewAiSR != null && valueViewAiSRUnit != null) {
                var sensRatioTextWidth = dc.getTextWidthInPixels(rightSideString, secondLineFont);
                var rightEdgeX = safeRight;

                valueViewAiSR.locX = rightEdgeX;
                (valueViewAiSR as Text).setJustification(Graphics.TEXT_JUSTIFY_RIGHT);

                valueViewAiSRIcon.locX = rightEdgeX - sensRatioTextWidth - (screenWidth * 0.07);

                valueViewAiSRUnit.locX = -100;
            }
        } else {
            if (valueViewAiSRIcon != null && valueViewAiSR != null && valueViewAiSRUnit != null) {
                var cobTextWidth = dc.getTextWidthInPixels(rightSideString, secondLineFont);
                var gUnitWidth = dc.getTextWidthInPixels("g", xtinyFont);
                var rightEdgeX = safeRight;

                valueViewAiSRIcon.locX = -100;

                valueViewAiSRUnit.locX = rightEdgeX - gUnitWidth;
                (valueViewAiSRUnit as Text).setJustification(Graphics.TEXT_JUSTIFY_LEFT);

                valueViewAiSR.locX = rightEdgeX - gUnitWidth - 2;
                (valueViewAiSR as Text).setJustification(Graphics.TEXT_JUSTIFY_RIGHT);

                var slHeight = dc.getFontHeight(secondLineFont);
                var xtinyHeight = dc.getFontHeight(xtinyFont);
                valueViewAiSRUnit.locY = valueViewAiSR.locY + (slHeight - xtinyHeight) * 0.7;
            }
        }

        if (valueViewEventualBG != null && valueViewIOB != null && valueViewIOBUnit != null) {
            var iobTextWidth = dc.getTextWidthInPixels(iobString, secondLineFont);
            var iobUnitWidth = dc.getTextWidthInPixels("U", xtinyFont);
            var iobRightEdge = safeLeft + iobTextWidth + 2 + iobUnitWidth;

            var rightSideLeftEdge;
            if (showingSensRatio && valueViewAiSRIcon != null) {
                rightSideLeftEdge = valueViewAiSRIcon.locX;
            } else {
                var cobTextWidth = dc.getTextWidthInPixels(rightSideString, secondLineFont);
                var gUnitWidth = dc.getTextWidthInPixels("g", xtinyFont);
                rightSideLeftEdge = safeRight - gUnitWidth - 2 - cobTextWidth;
            }
            
            valueViewEventualBG.locX = (iobRightEdge + rightSideLeftEdge) / 2;
        }

        (View.findDrawableById("Background") as Text).setColor(loopColor);
        
        var value = View.findDrawableById("value") as Text;
        var valueEventualBG = View.findDrawableById("valueEventualBG") as Text;
        var valueAiSR = View.findDrawableById("valueAiSR") as Text;
        var valueIOB = View.findDrawableById("valueIOB") as Text;
        var valueIOBUnit = View.findDrawableById("valueIOBUnit") as Text;
        var valueAiSRUnit = View.findDrawableById("valueAiSRUnit") as Text;
        var bgLabel = View.findDrawableById("label") as Text;
        
        var backgroundIsRed = (loopColor == Graphics.COLOR_RED);
        var backgroundIsYellow = (loopColor == Graphics.COLOR_YELLOW);
        
        if (backgroundIsRed) {
            if (bgLabel != null) {
                bgLabel.setColor(Graphics.COLOR_WHITE);
            }
            value.setColor(Graphics.COLOR_WHITE);
            valueEventualBG.setColor(Graphics.COLOR_WHITE);
            
            if (valueIOB != null && valueIOBUnit != null) {
                valueIOB.setColor(Graphics.COLOR_WHITE);
                valueIOBUnit.setColor(Graphics.COLOR_WHITE);
            }
            
            if (showingSensRatio) {
                valueAiSR.setColor(Graphics.COLOR_WHITE);
            } else {
                valueAiSR.setColor(Graphics.COLOR_WHITE);
                valueAiSRUnit.setColor(Graphics.COLOR_WHITE);
            }
        } else if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            if (bgLabel != null) {
                bgLabel.setColor(Graphics.COLOR_GREEN);
            }
            value.setColor(Graphics.COLOR_WHITE);
            valueEventualBG.setColor(Graphics.COLOR_WHITE);
            
            if (valueIOB != null && valueIOBUnit != null) {
                if (backgroundIsYellow) {
                    valueIOB.setColor(Graphics.COLOR_WHITE);
                    valueIOBUnit.setColor(Graphics.COLOR_WHITE);
                } else {
                    valueIOB.setColor(Graphics.COLOR_BLUE);
                    valueIOBUnit.setColor(Graphics.COLOR_BLUE);
                }
            }
            
            if (showingSensRatio) {
                valueAiSR.setColor(Graphics.COLOR_WHITE);
            } else {
                if (backgroundIsYellow) {
                    valueAiSR.setColor(Graphics.COLOR_WHITE);
                    valueAiSRUnit.setColor(Graphics.COLOR_WHITE);
                } else {
                    valueAiSR.setColor(Graphics.COLOR_YELLOW);
                    valueAiSRUnit.setColor(Graphics.COLOR_YELLOW);
                }
            }
        } else {
            if (bgLabel != null) {
                bgLabel.setColor(Graphics.COLOR_DK_GREEN);
            }
            value.setColor(Graphics.COLOR_BLACK);
            valueEventualBG.setColor(Graphics.COLOR_BLACK);
            
            if (valueIOB != null && valueIOBUnit != null) {
                if (backgroundIsYellow) {
                    valueIOB.setColor(Graphics.COLOR_BLACK);
                    valueIOBUnit.setColor(Graphics.COLOR_BLACK);
                } else {
                    valueIOB.setColor(Graphics.COLOR_DK_BLUE);
                    valueIOBUnit.setColor(Graphics.COLOR_DK_BLUE);
                }
            }
            
            if (showingSensRatio) {
                valueAiSR.setColor(Graphics.COLOR_BLACK);
            } else {
                if (backgroundIsYellow) {
                    valueAiSR.setColor(Graphics.COLOR_BLACK);
                    valueAiSRUnit.setColor(Graphics.COLOR_BLACK);
                } else {
                    valueAiSR.setColor(Graphics.COLOR_ORANGE);
                    valueAiSRUnit.setColor(Graphics.COLOR_ORANGE);
                }
            }
        }
        
        value.setText(bgString);
        valueEventualBG.setText(evBGString);
        valueAiSR.setText(rightSideString);
        if (valueIOB != null) {
            valueIOB.setText(iobString);
        }
        if (valueIOBUnit != null) {
            valueIOBUnit.setText("U");
        }
        if (valueAiSRUnit != null) {
            if (showingSensRatio) {
                valueAiSRUnit.setText("");
            } else {
                valueAiSRUnit.setText("g");
            }
        }

        var arrowView = View.findDrawableById("arrow") as Bitmap;
        var aiSRIconView = View.findDrawableById("aiSRIcon") as Bitmap;
        
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            arrowView.setBitmap(getDirection(status));
            if (aiSRIconView != null && showingSensRatio) {
                aiSRIconView.setBitmap(WatchUi.loadResource(Rez.Drawables.aiSRDark));
            }
        } else {
            arrowView.setBitmap(getDirectionBlack(status));
            if (aiSRIconView != null && showingSensRatio) {
                aiSRIconView.setBitmap(WatchUi.loadResource(Rez.Drawables.aiSRLight));
            }
        }
        
        View.onUpdate(dc);
    }

    function getGlucoseText(status) as String {
        if (status instanceof Dictionary) {
            var glucose = status["sgv"];
            if (glucose instanceof Number || glucose instanceof Float || glucose instanceof Double) {
                var convertedValue = convertGlucoseValue(glucose, status);
                if (isMMOL(status)) {
                    return convertedValue.format("%2.1f");
                } else {
                    return convertedValue.toNumber().format("%d");
                }
            }
        }
        return "--";
    }

    function getEventualBGText(status) as String {
        if (status instanceof Dictionary) {
            var ebg = status["eventualBG"];
            if (ebg instanceof Number || ebg instanceof Float || ebg instanceof Double) {
                var convertedValue = convertGlucoseValue(ebg, status);
                if (isMMOL(status)) {
                    return convertedValue.format("%2.1f");
                } else {
                    return convertedValue.toNumber().format("%d");
                }
            }
        }
        return "--";
    }

    function getCOBText(status as Dictionary) as String {
        if (status == null) {
            return "--";
        }
        var cob = status["cob"];
        if (cob == null) {
            return "--";
        }
        if (cob instanceof Number || cob instanceof Float || cob instanceof Double) {
            return cob.toNumber().format("%d");
        } else {
            return cob.toString();
        }
    }

    function getIOBText(status as Dictionary) as String {
        if (status == null) {
            return "--";
        }
        var iob = status["iob"];
        if (iob == null) {
            return "--";
        }
        if (iob instanceof Number || iob instanceof Float || iob instanceof Double) {
            return iob.format("%2.1f");
        } else {
            return iob.toString();
        }
    }

    function getMinutes(status) as Number {
        if (status instanceof Dictionary) {
            var lastLoopDate = status["date"];
            if (lastLoopDate == null) {
                return -1;
            }
            
            // Type safety: ensure we have a number before calling toLong()
            if (!(lastLoopDate instanceof Number || lastLoopDate instanceof Long)) {
                return -1;
            }
            
            var lastLoopMs = lastLoopDate.toLong();
            var lastLoopSeconds = lastLoopMs / 1000;
            
            var now = Time.now().value();
            var deltaSeconds = now - lastLoopSeconds;
            
            if (deltaSeconds <= 0) {
                return 0;
            }
            
            var minutes = (deltaSeconds / 60).toNumber();
            return minutes;
        }
        return -1;
    }

    function getLoopColor(min as Number) as Number {
        if (min < 0) {
            return getBackgroundColor() as Number;
        } else if (min <= 7) {
            return getBackgroundColor() as Number;
        } else if (min <= 13) {
            return Graphics.COLOR_YELLOW as Number;
        } else {
            return Graphics.COLOR_RED as Number;
        }
    }

    function getSensRatioText(status as Dictionary) as String {
        if (status == null) {
            return "--";
        }
        var sensRatio = status["sensRatio"];
        if (sensRatio == null) {
            return "--";
        }
        if (sensRatio instanceof Number || sensRatio instanceof Float || sensRatio instanceof Double) {
            return sensRatio.format("%2.2f");
        } else {
            return sensRatio.toString();
        }
    }

    function getISFText(status as Dictionary) as String {
        if (status == null) {
            return "--";
        }
        var isf = status["isf"];
        if (isf == null) {
            return "--";
        }
        if (isf instanceof Number || isf instanceof Float || isf instanceof Double) {
            var convertedValue = convertGlucoseValue(isf, status);
            if (isMMOL(status)) {
                return convertedValue.format("%2.1f");
            } else {
                return convertedValue.toNumber().format("%d");
            }
        } else {
            return isf.toString();
        }
    }

    function getTBRText(status as Dictionary) as String {
        if (status == null) {
            return "--";
        }
        var tbr = status["tbr"];
        if (tbr == null) {
            return "--";
        }
        if (tbr instanceof Number || tbr instanceof Float || tbr instanceof Double) {
            if (tbr == tbr.toNumber()) {
                return tbr.format("%.0f");
            } else if ((tbr * 10) == (tbr * 10).toNumber()) {
                return tbr.format("%.1f");
            } else {
                return tbr.format("%.2f");
            }
        } else {
            return tbr.toString();
        }
    }

    function getDirectionBlack(status) as BitmapType {
        var bitmap = WatchUi.loadResource(Rez.Drawables.UnknownB);
        if (status instanceof Dictionary) {
            var trend = status["direction"] as String;
            if (trend == null) {
                return bitmap;
            }
            switch (trend) {
                case "Flat":
                    bitmap = WatchUi.loadResource(Rez.Drawables.FlatB);
                    break;
                case "SingleUp":
                    bitmap = WatchUi.loadResource(Rez.Drawables.SingleUpB);
                    break;
                case "SingleDown":
                    bitmap = WatchUi.loadResource(Rez.Drawables.SingleDownB);
                    break;
                case "FortyFiveUp":
                    bitmap = WatchUi.loadResource(Rez.Drawables.FortyFiveUpB);
                    break;
                case "FortyFiveDown":
                    bitmap = WatchUi.loadResource(Rez.Drawables.FortyFiveDownB);
                    break;
                case "DoubleUp":
                case "TripleUp":
                    bitmap = WatchUi.loadResource(Rez.Drawables.DoubleUpB);
                    break;
                case "DoubleDown":
                case "TripleDown":
                    bitmap = WatchUi.loadResource(Rez.Drawables.DoubleDownB);
                    break;
                default: break;
            }
        }
        return bitmap;
    }

    function getDirection(status) as BitmapType {
        var bitmap = WatchUi.loadResource(Rez.Drawables.Unknown);
        if (status instanceof Dictionary) {
            var trend = status["direction"] as String;
            if (trend == null) {
                return bitmap;
            }

            switch (trend) {
                case "Flat":
                    bitmap = WatchUi.loadResource(Rez.Drawables.Flat);
                    break;
                case "SingleUp":
                    bitmap = WatchUi.loadResource(Rez.Drawables.SingleUp);
                    break;
                case "SingleDown":
                    bitmap = WatchUi.loadResource(Rez.Drawables.SingleDown);
                    break;
                case "FortyFiveUp":
                    bitmap = WatchUi.loadResource(Rez.Drawables.FortyFiveUp);
                    break;
                case "FortyFiveDown":
                    bitmap = WatchUi.loadResource(Rez.Drawables.FortyFiveDown);
                    break;
                case "DoubleUp":
                case "TripleUp":
                    bitmap = WatchUi.loadResource(Rez.Drawables.DoubleUp);
                    break;
                case "DoubleDown":
                case "TripleDown":
                    bitmap = WatchUi.loadResource(Rez.Drawables.DoubleDown);
                    break;
                default: break;
            }
        }
        return bitmap;
    }
}