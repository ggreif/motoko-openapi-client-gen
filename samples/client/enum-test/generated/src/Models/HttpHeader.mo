
// HttpHeader.mo
/// Model with hyphenated field names

module {
    // User-facing type: what application code uses
    public type HttpHeader = {
        content_type : Text;
        cache_control : ?Text;
        x_request_id : ?Text;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer HttpHeader type
        public type JSON = {
            content_type : Text;
            cache_control : ?Text;
            x_request_id : ?Text;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : HttpHeader) : JSON = value;

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?HttpHeader = ?json;
    }
}
