
// SimpleColorEnum.mo
/// Simple enum without special characters
/// Enum values: #red, #green, #blue

module {
    // User-facing type: type-safe variants for application code
    public type SimpleColorEnum = {
        #red;
        #green;
        #blue;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SimpleColorEnum type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SimpleColorEnum) : JSON =
            switch (value) {
                case (#red) "red";
                case (#green) "green";
                case (#blue) "blue";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SimpleColorEnum =
            switch (json) {
                case "red" ?#red;
                case "green" ?#green;
                case "blue" ?#blue;
                case _ null;
            };
    }
}
