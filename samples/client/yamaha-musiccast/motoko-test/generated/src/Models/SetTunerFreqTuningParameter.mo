
// SetTunerFreqTuningParameter.mo
/// Enum values: #direct

module {
    // User-facing type: type-safe variants for application code
    public type SetTunerFreqTuningParameter = {
        #direct;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SetTunerFreqTuningParameter type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SetTunerFreqTuningParameter) : JSON =
            switch (value) {
                case (#direct) "direct";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SetTunerFreqTuningParameter =
            switch (json) {
                case "direct" ?#direct;
                case _ null;
            };
    }
}
