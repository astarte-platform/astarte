$.getJSON("/user-config/config.json", function(result) {
    if (result.realm_management_api_url) {

        parameters =
        {
            config: result,
            previousSession: localStorage.session || null
        }

        //init app
        var app = require('js/elm-app.js').Main.fullscreen(parameters);

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


