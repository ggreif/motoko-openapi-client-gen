
// SetInputInputParameter.mo
/// Enum values: #net_radio, #napster, #spotify, #juke, #qobuz, #tidal, #deezer, #server, #bluetooth, #airplay, #mc_link, #usb

module {
    // User-facing type: type-safe variants for application code
    public type SetInputInputParameter = {
        #net_radio;
        #napster;
        #spotify;
        #juke;
        #qobuz;
        #tidal;
        #deezer;
        #server;
        #bluetooth;
        #airplay;
        #mc_link;
        #usb;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SetInputInputParameter type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SetInputInputParameter) : JSON =
            switch (value) {
                case (#net_radio) "net_radio";
                case (#napster) "napster";
                case (#spotify) "spotify";
                case (#juke) "juke";
                case (#qobuz) "qobuz";
                case (#tidal) "tidal";
                case (#deezer) "deezer";
                case (#server) "server";
                case (#bluetooth) "bluetooth";
                case (#airplay) "airplay";
                case (#mc_link) "mc_link";
                case (#usb) "usb";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SetInputInputParameter =
            switch (json) {
                case "net_radio" ?#net_radio;
                case "napster" ?#napster;
                case "spotify" ?#spotify;
                case "juke" ?#juke;
                case "qobuz" ?#qobuz;
                case "tidal" ?#tidal;
                case "deezer" ?#deezer;
                case "server" ?#server;
                case "bluetooth" ?#bluetooth;
                case "airplay" ?#airplay;
                case "mc_link" ?#mc_link;
                case "usb" ?#usb;
                case _ null;
            };
    }
}
