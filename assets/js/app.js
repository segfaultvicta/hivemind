// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "phoenix_html"

function getSocketUrl() {
  var host = window.location.host
  var protocol = window.location.protocol == "https:" ? "wss://" : "ws://";
  return protocol + host + "/socket/websocket"
}

function getCookie(cname) {
  var name = cname + "=";
  var decodedCookie = decodeURIComponent(document.cookie);
  var ca = decodedCookie.split(';');
  for (var i = 0; i < ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0) == ' ') {
      c = c.substring(1);
    }
    if (c.indexOf(name) == 0) {
      return c.substring(name.length, c.length)
    }
  }
  return "";
}


import Elm from "./hivemind.js"
 
let hm = document.getElementById('hivemind-main');
if (hm !== undefined && hm !== null) {
	var app = Elm.Hivemind.embed(hm, {uid: getCookie("user-id"), loc: getCookie("location-id"), width: window.innerWidth, socketUrl: getSocketUrl()});
}
