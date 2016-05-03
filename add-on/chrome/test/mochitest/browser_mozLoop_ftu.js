/* Any copyright is dedicated to the Public Domain.
   http://creativecommons.org/publicdomain/zero/1.0/ */

/*
 * This file contains tests for the FTU panel in slideshow.
 */
"use strict";

const PREF_FTU_VERSION = "loop.gettingStarted.latestFTUVersion";

// Pref set to default value check
add_task(function* setup() {
  Services.prefs.setCharPref("loop.debug.loglevel", "All");
  Services.prefs.setIntPref(PREF_FTU_VERSION, 0);

  registerCleanupFunction(function* () {
    Services.prefs.clearUserPref(PREF_FTU_VERSION);
  });
});

// open the panel, check that FTU is displayed
add_task(function* test_mozLoop_ftu_displayed() {
  yield loadLoopPanel();
  let loopDoc = document.getElementById("loop-panel-iframe").contentDocument;
  // Wait a little until our pieces have been rendered.
  yield promiseWaitForCondition(() => {
    return !!loopDoc.querySelector(".fte-get-started-button");
  }, "FTE Button should be displayed indicating that the FTU is displayed");


  let fte_button = loopDoc.getElementsByClassName("fte-get-started-button")[0];
  fte_button.click();

  let loopButton = document.getElementById("loop-button");
  yield promiseWaitForCondition(() => {
    return !loopButton.open;
  }, "Panel should be hidden after slideshow button click");

  yield promiseWaitForCondition(() => {
    return !!document.getElementById("loop-slideshow-browser");
  }, "Slideshow browser should be displayed after slideshow button click");

  let slideshowDoc = document.getElementById("loop-slideshow-browser").contentDocument;

  // Wait to ensure the document has loaded.
  yield promiseWaitForCondition(() => {
    return slideshowDoc.getElementsByClassName("slideshow").length != 0;
  }, "Slideshow should have loaded");

  is(slideshowDoc.getElementsByClassName("slideshow").length, 1,
    "Slideshow should exist after panel has closed");
});


// check that FTU content exists
add_task(function* test_mozLoop_ftu_has_content() {
  let slideshowDoc = document.getElementById("loop-slideshow-browser").contentDocument;

  yield promiseWaitForCondition(() => {
    return slideshowDoc.getElementsByClassName("slide--active").length != 0;
  }, "Active Slide should have loaded");

  let activeSlide = slideshowDoc.getElementsByClassName("slide--active")[0];
  let slideTitle = activeSlide.getElementsByTagName("h2")[0].innerHTML;
  let slideText = activeSlide.getElementsByClassName("slide-text")[0].innerHTML;

  is(slideTitle.length > 0,
    true, "Active Slide should have a title");
  is(slideText.length > 0,
    true, "Active Slide should have text");
});


// Close tour
add_task(function* test_mozLoop_close_tour() {
  let slideshowDoc = document.getElementById("loop-slideshow-browser").contentDocument;

  slideshowDoc.getElementsByClassName("button-close")[0].click();

  let loopButton = document.getElementById("loop-button");
  yield promiseWaitForCondition(() => {
    return loopButton.open;
  }, "Panel should be open after slideshow is closed");

  yield promiseWaitForCondition(() => {
    return document.getElementById("loop-notification-panel").state == "open";
  }, "should have opened the panel after closing the tour");

  ok(!document.getElementById("loop-slideshow-browser"),
     "should have closed the tour");

  let loopPanelFrame = document.getElementById("loop-panel-iframe");

  yield promiseWaitForCondition(() => {
    return !!loopPanelFrame.contentDocument;
  }, "Loop Panel iFrame should be displayed");

  let loopDoc = loopPanelFrame.contentDocument;

  yield promiseWaitForCondition(() => {
      return !!loopDoc.querySelector(".rooms");
  }, "Content within Loop panel iFrame should be displayed");

  is(loopDoc.getElementsByClassName("rooms").length, 1,
     "should be displaying the rooms after closing the tour");
});
