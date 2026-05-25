import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";

// SwitchTunerPresetDirParameter.mo
/// Enum values: #next, #previous

module {
    public type SwitchTunerPresetDirParameter = {
        #next;
        #previous;
    };

    public module JSON {
        public func toCandidValue(value : SwitchTunerPresetDirParameter) : Candid.Candid =
            switch (value) {
                case (#next) #Text("next");
                case (#previous) #Text("previous");
            };

        public func fromCandidValue(candid : Candid.Candid) : ?SwitchTunerPresetDirParameter =
            switch (candid) {
                case (#Text("next")) ?#next;
                case (#Text("previous")) ?#previous;
                case _ null;
            };

        public func toText(value : SwitchTunerPresetDirParameter) : Text =
            switch (value) {
                case (#next) "next";
                case (#previous) "previous";
            };
    };
};
