import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";

// SetPowerPowerParameter.mo
/// Enum values: #true_, #standby, #toggle

module {
    public type SetPowerPowerParameter = {
        #true_;
        #standby;
        #toggle;
    };

    public module JSON {
        public func toCandidValue(value : SetPowerPowerParameter) : Candid.Candid =
            switch (value) {
                case (#true_) #Text("true");
                case (#standby) #Text("standby");
                case (#toggle) #Text("toggle");
            };

        public func fromCandidValue(candid : Candid.Candid) : ?SetPowerPowerParameter =
            switch (candid) {
                case (#Text("true")) ?#true_;
                case (#Text("standby")) ?#standby;
                case (#Text("toggle")) ?#toggle;
                case _ null;
            };

        public func toText(value : SetPowerPowerParameter) : Text =
            switch (value) {
                case (#true_) "true";
                case (#standby) "standby";
                case (#toggle) "toggle";
            };
    };
};
