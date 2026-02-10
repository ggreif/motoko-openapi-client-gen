import { type Map } "mo:core/pure/Map";

// GetHeaders200Response.mo

module {
    // User-facing type: what application code uses
    public type GetHeaders200Response = {
        /// Map of all request headers
        headers : ?Map<Text, Text>;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer GetHeaders200Response type
        public type JSON = {
            headers : ?Map<Text, Text>;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : GetHeaders200Response) : JSON = value;

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?GetHeaders200Response = ?json;
    }
}
