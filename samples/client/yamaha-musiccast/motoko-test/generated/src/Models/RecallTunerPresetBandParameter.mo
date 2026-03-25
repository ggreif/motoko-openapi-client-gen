
// RecallTunerPresetBandParameter.mo
/// Enum values: #am, #fm, #dab

module {
    // User-facing type: type-safe variants for application code
    public type RecallTunerPresetBandParameter = {
        #am;
        #fm;
        #dab;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer RecallTunerPresetBandParameter type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : RecallTunerPresetBandParameter) : JSON =
            switch (value) {
                case (#am) "am";
                case (#fm) "fm";
                case (#dab) "dab";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?RecallTunerPresetBandParameter =
            switch (json) {
                case "am" ?#am;
                case "fm" ?#fm;
                case "dab" ?#dab;
                case _ null;
            };
    }
}
