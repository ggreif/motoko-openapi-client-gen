
// ZoneStatusPower.mo
/// Enum values: #true_, #standby

module {
    // User-facing type: type-safe variants for application code
    public type ZoneStatusPower = {
        #true_;
        #standby;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer ZoneStatusPower type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : ZoneStatusPower) : JSON =
            switch (value) {
                case (#true_) "true";
                case (#standby) "standby";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?ZoneStatusPower =
            switch (json) {
                case "true" ?#true_;
                case "standby" ?#standby;
                case _ null;
            };
    }
}
