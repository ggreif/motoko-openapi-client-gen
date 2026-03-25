
// SetPowerPowerParameter.mo
/// Enum values: #true_, #standby, #toggle

module {
    // User-facing type: type-safe variants for application code
    public type SetPowerPowerParameter = {
        #true_;
        #standby;
        #toggle;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SetPowerPowerParameter type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SetPowerPowerParameter) : JSON =
            switch (value) {
                case (#true_) "true";
                case (#standby) "standby";
                case (#toggle) "toggle";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SetPowerPowerParameter =
            switch (json) {
                case "true" ?#true_;
                case "standby" ?#standby;
                case "toggle" ?#toggle;
                case _ null;
            };
    }
}
