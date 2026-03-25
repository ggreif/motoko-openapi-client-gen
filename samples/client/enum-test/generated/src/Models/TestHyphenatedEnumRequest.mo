
import { type HyphenatedColorEnum; JSON = HyphenatedColorEnum } "./HyphenatedColorEnum";

// TestHyphenatedEnumRequest.mo

module {
    // User-facing type: what application code uses
    public type TestHyphenatedEnumRequest = {
        color : HyphenatedColorEnum;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer TestHyphenatedEnumRequest type
        public type JSON = {
            color : HyphenatedColorEnum.JSON;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : TestHyphenatedEnumRequest) : JSON = {
            color = HyphenatedColorEnum.toJSON(value.color);
        };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?TestHyphenatedEnumRequest {
            let ?color = HyphenatedColorEnum.fromJSON(json.color) else return null;
            ?{
                color;
            }
        };
    }
}
