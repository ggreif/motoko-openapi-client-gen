
// SwitchTunerPresetDirParameter.mo
/// Enum values: #next, #previous

module {
    // User-facing type: type-safe variants for application code
    public type SwitchTunerPresetDirParameter = {
        #next;
        #previous;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SwitchTunerPresetDirParameter type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SwitchTunerPresetDirParameter) : JSON =
            switch (value) {
                case (#next) "next";
                case (#previous) "previous";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SwitchTunerPresetDirParameter =
            switch (json) {
                case "next" ?#next;
                case "previous" ?#previous;
                case _ null;
            };
    }
}
