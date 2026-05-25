import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";

// RecallTunerPresetBandParameter.mo
/// Enum values: #am, #fm, #dab

module {
    public type RecallTunerPresetBandParameter = {
        #am;
        #fm;
        #dab;
    };

    public module JSON {
        public func toCandidValue(value : RecallTunerPresetBandParameter) : Candid.Candid =
            switch (value) {
                case (#am) #Text("am");
                case (#fm) #Text("fm");
                case (#dab) #Text("dab");
            };

        public func fromCandidValue(candid : Candid.Candid) : ?RecallTunerPresetBandParameter =
            switch (candid) {
                case (#Text("am")) ?#am;
                case (#Text("fm")) ?#fm;
                case (#Text("dab")) ?#dab;
                case _ null;
            };

        public func toText(value : RecallTunerPresetBandParameter) : Text =
            switch (value) {
                case (#am) "am";
                case (#fm) "fm";
                case (#dab) "dab";
            };
    };
};
