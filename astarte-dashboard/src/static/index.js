/*
   This file is part of Astarte.

   Copyright 2017 Ispirata Srl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

require( '../../node_modules/@fortawesome/fontawesome-free/js/all.js' );
require( './styles/main.scss' );
var $ = jQuery = require( '../../node_modules/jquery/dist/jquery.js' );

$.getJSON("/user-config/config.json", function(result) {
    if (result.realm_management_api_url) {

        parameters =
            { config: result
            , previousSession: localStorage.session || null
            }

        //init app
        var app = require('../elm/Main').Elm.Main.init({flags: parameters});

        /* begin Elm ports */
        app.ports.storeSession.subscribe(function(session) {
            console.log("storing session");
            localStorage.session = session;
        });

        window.addEventListener("storage", function(event) {
            if (event.storageArea === localStorage && event.key === "session") {
                console.log("local session changed");
                app.ports.onSessionChange.send(event.newValue);
            }
        }, false);
        /* end Elm ports */

    } else {
        throw new Error("Astarte realm management API URL not set.");
    }

}).fail(function(jqXHR, textStatus, errorThrown) {
    throw new Error("Astarte dashboard configuration file (config.json) is missing.\n" + textStatus);

});


