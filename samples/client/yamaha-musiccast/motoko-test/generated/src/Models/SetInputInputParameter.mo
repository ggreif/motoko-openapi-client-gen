import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";

// SetInputInputParameter.mo
/// Enum values: #net_radio, #napster, #spotify, #juke, #qobuz, #tidal, #deezer, #server, #bluetooth, #airplay, #mc_link, #usb

module {
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

    public module JSON {
        public func toCandidValue(value : SetInputInputParameter) : Candid.Candid =
            switch (value) {
                case (#net_radio) #Text("net_radio");
                case (#napster) #Text("napster");
                case (#spotify) #Text("spotify");
                case (#juke) #Text("juke");
                case (#qobuz) #Text("qobuz");
                case (#tidal) #Text("tidal");
                case (#deezer) #Text("deezer");
                case (#server) #Text("server");
                case (#bluetooth) #Text("bluetooth");
                case (#airplay) #Text("airplay");
                case (#mc_link) #Text("mc_link");
                case (#usb) #Text("usb");
            };

        public func fromCandidValue(candid : Candid.Candid) : ?SetInputInputParameter =
            switch (candid) {
                case (#Text("net_radio")) ?#net_radio;
                case (#Text("napster")) ?#napster;
                case (#Text("spotify")) ?#spotify;
                case (#Text("juke")) ?#juke;
                case (#Text("qobuz")) ?#qobuz;
                case (#Text("tidal")) ?#tidal;
                case (#Text("deezer")) ?#deezer;
                case (#Text("server")) ?#server;
                case (#Text("bluetooth")) ?#bluetooth;
                case (#Text("airplay")) ?#airplay;
                case (#Text("mc_link")) ?#mc_link;
                case (#Text("usb")) ?#usb;
                case _ null;
            };

        public func toText(value : SetInputInputParameter) : Text =
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
    };
};
