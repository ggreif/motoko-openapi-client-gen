
import { type InnerRecordWithEnum; JSON = InnerRecordWithEnum } "./InnerRecordWithEnum";

// OuterRecord.mo
/// Outer record containing inner record with enum (transitive)

module {
    // User-facing type: what application code uses
    public type OuterRecord = {
        inner : InnerRecordWithEnum;
        id : ?Int;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer OuterRecord type
        public type JSON = {
            inner : InnerRecordWithEnum.JSON;
            id : ?Int;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : OuterRecord) : JSON = { value with
            inner = InnerRecordWithEnum.toJSON(value.inner);
        };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?OuterRecord {
            let ?inner = InnerRecordWithEnum.fromJSON(json.inner) else return null;
            ?{ json with
                inner;
            }
        };
    }
}
