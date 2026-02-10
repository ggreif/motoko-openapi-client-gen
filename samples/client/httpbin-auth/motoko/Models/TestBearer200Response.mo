
// TestBearer200Response.mo

module {
    // User-facing type: what application code uses
    public type TestBearer200Response = {
        /// Whether the request was authenticated
        authenticated : ?Bool;
        /// The bearer token that was received
        token : ?Text;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer TestBearer200Response type
        public type JSON = {
            authenticated : ?Bool;
            token : ?Text;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : TestBearer200Response) : JSON = value;

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?TestBearer200Response = ?json;
    }
}
