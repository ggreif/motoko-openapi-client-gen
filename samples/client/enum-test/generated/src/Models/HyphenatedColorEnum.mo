
// HyphenatedColorEnum.mo
/// Enum with hyphenated values
/// Enum values: #blue_green, #red_orange, #yellow_green

module {
    // User-facing type: type-safe variants for application code
    public type HyphenatedColorEnum = {
        #blue_green;
        #red_orange;
        #yellow_green;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer HyphenatedColorEnum type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : HyphenatedColorEnum) : JSON =
            switch (value) {
                case (#blue_green) "blue-green";
                case (#red_orange) "red-orange";
                case (#yellow_green) "yellow-green";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?HyphenatedColorEnum =
            switch (json) {
                case "blue-green" ?#blue_green;
                case "red-orange" ?#red_orange;
                case "yellow-green" ?#yellow_green;
                case _ null;
            };
    }
}
