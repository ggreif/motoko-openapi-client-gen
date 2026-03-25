
// SetInputModeParameter.mo
/// Enum values: #autoplay, #autoplay_disabled

module {
    // User-facing type: type-safe variants for application code
    public type SetInputModeParameter = {
        #autoplay;
        #autoplay_disabled;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SetInputModeParameter type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SetInputModeParameter) : JSON =
            switch (value) {
                case (#autoplay) "autoplay";
                case (#autoplay_disabled) "autoplay_disabled";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SetInputModeParameter =
            switch (json) {
                case "autoplay" ?#autoplay;
                case "autoplay_disabled" ?#autoplay_disabled;
                case _ null;
            };
    }
}
