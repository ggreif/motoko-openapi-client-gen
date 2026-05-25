import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";

// SetVolumeVolumeParameterOneOf.mo
/// Enum values: #up, #down

module {
    public type SetVolumeVolumeParameterOneOf = {
        #up;
        #down;
    };

    public module JSON {
        public func toCandidValue(value : SetVolumeVolumeParameterOneOf) : Candid.Candid =
            switch (value) {
                case (#up) #Text("up");
                case (#down) #Text("down");
            };

        public func fromCandidValue(candid : Candid.Candid) : ?SetVolumeVolumeParameterOneOf =
            switch (candid) {
                case (#Text("up")) ?#up;
                case (#Text("down")) ?#down;
                case _ null;
            };

        public func toText(value : SetVolumeVolumeParameterOneOf) : Text =
            switch (value) {
                case (#up) "up";
                case (#down) "down";
            };
    };
};
