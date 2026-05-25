import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";

// ZoneStatusPower.mo
/// Enum values: #true_, #standby

module {
    public type ZoneStatusPower = {
        #true_;
        #standby;
    };

    public module JSON {
        public func toCandidValue(value : ZoneStatusPower) : Candid.Candid =
            switch (value) {
                case (#true_) #Text("true");
                case (#standby) #Text("standby");
            };

        public func fromCandidValue(candid : Candid.Candid) : ?ZoneStatusPower =
            switch (candid) {
                case (#Text("true")) ?#true_;
                case (#Text("standby")) ?#standby;
                case _ null;
            };

        public func toText(value : ZoneStatusPower) : Text =
            switch (value) {
                case (#true_) "true";
                case (#standby) "standby";
            };
    };
};
