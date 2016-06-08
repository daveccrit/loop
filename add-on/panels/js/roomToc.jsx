/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */
var loop = loop || {};

// XXX akita add tests
loop.roomToc = (function(mozL10n) {
  "use strict";
  var tocViews = loop.shared.toc;
  var sharedActions = loop.shared.actions;
  var sharedUtils = loop.shared.utils;

  function init() {
    // XXX akita what's this for?
    loop.shared.utils.getBoolPreference = function foo() {};

    var requests = [
      ["GetAllConstants"],
      ["GetAllStrings"],
      ["GetLocale"]
    ];

    loop.requestMulti.apply(null, requests).then(function(results) {
      let [constants, stringBundle, locale] = results;
      mozL10n.initialize({
        locale: locale,
        getStrings: function(key) {
          if (!(key in stringBundle)) {
            console.error("No string found for key: ", key);
            return JSON.stringify({ textContent: "foo" });
          }

          return JSON.stringify({ textContent: stringBundle[key] });
        }
      });

      var dispatcher = new loop.Dispatcher();

      var serverConnectionStore = new loop.store.ServerConnectionStore(dispatcher, {});

      var roomStore = new loop.store.RoomStore(dispatcher, { constants });

      var participantStore = new loop.store.ParticipantStore(dispatcher);

      loop.store.StoreMixin.register({
        participantStore,
        serverConnectionStore,
        roomStore
      });

      window.addEventListener("unload", function() {
        dispatcher.dispatch(new sharedActions.WindowUnload());
      });

      ReactDOM.render(<tocViews.TableOfContentView
                        dispatcher={dispatcher}
                        isScreenShareActive={false}
                        participantStore={participantStore} />, document.querySelector("#main"));

      var locationData = sharedUtils.locationData();
      var hash = locationData.hash.match(/#(.*)/);

      var roomToken = hash[1];

      // Kick off loading the content for this room into the sidebar
      // XXX could this race with something that SetupWindowData is already
      // expecting to be done?
      loop.request("LoadSidebar", roomToken);

      dispatcher.dispatch(new sharedActions.SetupWindowData({
        roomToken: roomToken
      }));
    });
  }

  return {
    init: init
  };
})(document.mozL10n);

document.addEventListener("DOMContentLoaded", loop.roomToc.init);