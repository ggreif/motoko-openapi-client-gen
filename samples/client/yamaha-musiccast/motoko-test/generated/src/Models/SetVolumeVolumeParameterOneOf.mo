
// SetVolumeVolumeParameterOneOf.mo
/// Enum values: #up, #down

module {
    // User-facing type: type-safe variants for application code
    public type SetVolumeVolumeParameterOneOf = {
        #up;
        #down;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SetVolumeVolumeParameterOneOf type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SetVolumeVolumeParameterOneOf) : JSON =
            switch (value) {
                case (#up) "up";
                case (#down) "down";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SetVolumeVolumeParameterOneOf =
            switch (json) {
                case "up" ?#up;
                case "down" ?#down;
                case _ null;
            };
    }
}
