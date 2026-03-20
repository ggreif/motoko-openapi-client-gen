
// HTTPStatusEnum.mo
/// Numeric enum for HTTP status codes
/// Enum values: #_200_, #_404_, #_500_

module {
    // User-facing type: type-safe variants for application code
    public type HTTPStatusEnum = {
        #_200_;
        #_404_;
        #_500_;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer HTTPStatusEnum type
        public type JSON = Int;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : HTTPStatusEnum) : JSON =
            switch (value) {
                case (#_200_) 200;
                case (#_404_) 404;
                case (#_500_) 500;
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?HTTPStatusEnum =
            switch (json) {
                case (200) ?#_200_;
                case (404) ?#_404_;
                case (500) ?#_500_;
                case _ null;
            };
    }
}
