/* -------------------------------------------------------------------------- */
/* Copyright 2002-2020, OpenNebula Project, OpenNebula Systems                */
/*                                                                            */
/* Licensed under the Apache License, Version 2.0 (the "License"); you may    */
/* not use this file except in compliance with the License. You may obtain    */
/* a copy of the License at                                                   */
/*                                                                            */
/* http://www.apache.org/licenses/LICENSE-2.0                                 */
/*                                                                            */
/* Unless required by applicable law or agreed to in writing, software        */
/* distributed under the License is distributed on an "AS IS" BASIS,          */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   */
/* See the License for the specific language governing permissions and        */
/* limitations under the License.                                             */
/* -------------------------------------------------------------------------- */

define(function(require) {
  // var WMKS = requiere("wmks");
  var Config = require("sunstone-config");
  var _lock = false;
  var _rfb;
  var _wmks;
  var _message = "";
  var _status = "Loading";
  var _is_encrypted = "";

  return {
    "lockStatus": lockStatus,
    "lock": lock,
    "unlock": unlock,
    "vmrcCallback": vmrcCallback,
    "disconnect": disconnect,
    "sendCtrlAltDel": sendCtrlAltDel
  };

  function lockStatus() {
    return _lock;
  }

  function lock() {
    _lock = true;
  }

  function unlock() {
    _lock = false;
  }

  function setStatus(message="", status=""){
    _message = message;
    _status = status;
    $(".VMRC_message").text(_message);
    $("#VMRC_status").text(_status);
  }

  function connected(){
    setStatus(null, "VMRC " + _rfb._rfb_connection_state + " (" + _is_encrypted + ") to: " + _rfb._fb_name);
  }

  function disconnectedFromServer(e){
    if (e.detail.clean) {
      setStatus(null, "VMRC " + _rfb._rfb_connection_state + " (" + _is_encrypted + ") to: " + _rfb._fb_name);
    } else {
      setStatus("Something went wrong, connection is closed", "Failed");
    }
  }

  function desktopNameChange(e) {
    if (e.detail.name) {
      setStatus(null, "VMRC " + _rfb._rfb_connection_state + " (" + _is_encrypted + ") to: " + e.detail.name);
    }
  }

  function credentialsRequired(e) {
    setStatus("Something went wrong, more credentials must be given to continue", "Failed");
  }

  function vmrcCallback(response) {
    var URL = "";
    var proxy_port = Config.vncProxyPort;
    var pw = response["password"];
    var token = response["token"];
    var vm_name = response["vm_name"];
    var protocol = window.location.protocol;
    var hostname = window.location.hostname;
    var port = window.location.port;

    if (protocol === "https:") {
      URL = "wss";
      _is_encrypted ="encrypted";
    } else {
      URL = "ws";
      _is_encrypted ="unencrypted";
    }
    URL += "://" + hostname;
    URL += ":" + proxy_port;
    URL += "/ticket/" + token;
    // URL += "/?vm=" + vm_name;

    // if (!Config.requestVNCPassword) {
    //   URL += "&password=" + pw;
    // }
    var re = new RegExp("^(ws|wss):\\/\\/[\\w\\D]*?\\?", "gi");
    var link = URL.replace(re, protocol + "//" + hostname + ":" + port + "/vnc?");

    try{
      var	wmks	=	WMKS.createWMKS("VMRC_canvas",{})
        .register(WMKS.CONST.Events.CONNECTION_STATE_CHANGE,								
        function(event,data){	
          if(typeof cons !== 'undefined' && data.state	== cons.ConnectionState.CONNECTED)	
          {	
            console.log("connection	state	change	:	connected");
          }	
        });	
      wmks.connect(URL);
    }catch(err){
      setStatus("Something went wrong, connection is closed", "Failed");
      console.log("error start VMRC ", err);
    }

    $("#open_in_a_new_window").attr("href", link);
  }

  function disconnect() {
    if (_rfb) { _rfb.disconnect(); }
  }

  function sendCtrlAltDel() {
    if (_rfb) { _rfb.sendCtrlAltDel(); }
  }
});