import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";

// SetInputModeParameter.mo
/// Enum values: #autoplay, #autoplay_disabled

module {
    public type SetInputModeParameter = {
        #autoplay;
        #autoplay_disabled;
    };

    public module JSON {
        public func toCandidValue(value : SetInputModeParameter) : Candid.Candid =
            switch (value) {
                case (#autoplay) #Text("autoplay");
                case (#autoplay_disabled) #Text("autoplay_disabled");
            };

        public func fromCandidValue(candid : Candid.Candid) : ?SetInputModeParameter =
            switch (candid) {
                case (#Text("autoplay")) ?#autoplay;
                case (#Text("autoplay_disabled")) ?#autoplay_disabled;
                case _ null;
            };

        public func toText(value : SetInputModeParameter) : Text =
            switch (value) {
                case (#autoplay) "autoplay";
                case (#autoplay_disabled) "autoplay_disabled";
            };
    };
};
