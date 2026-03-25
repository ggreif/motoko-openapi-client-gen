
import { type MixedOneOf; JSON = MixedOneOf } "./MixedOneOf";

// TestMixedOneOf200Response.mo

module {
    // User-facing type: what application code uses
    public type TestMixedOneOf200Response = {
        received : ?MixedOneOf;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer TestMixedOneOf200Response type
        public type JSON = {
            received : ?MixedOneOf;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : TestMixedOneOf200Response) : JSON = value;

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?TestMixedOneOf200Response = ?json;
    }
}
