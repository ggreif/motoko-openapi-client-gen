import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";

// SetTunerFreqTuningParameter.mo
/// Enum values: #direct

module {
    public type SetTunerFreqTuningParameter = {
        #direct;
    };

    public module JSON {
        public func toCandidValue(value : SetTunerFreqTuningParameter) : Candid.Candid =
            switch (value) {
                case (#direct) #Text("direct");
            };

        public func fromCandidValue(candid : Candid.Candid) : ?SetTunerFreqTuningParameter =
            switch (candid) {
                case (#Text("direct")) ?#direct;
                case _ null;
            };

        public func toText(value : SetTunerFreqTuningParameter) : Text =
            switch (value) {
                case (#direct) "direct";
            };
    };
};
