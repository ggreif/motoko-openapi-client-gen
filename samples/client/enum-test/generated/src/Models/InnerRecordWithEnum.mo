
import { type AvailabilityEnum; JSON = AvailabilityEnum } "./AvailabilityEnum";

// InnerRecordWithEnum.mo
/// Inner record containing an enum field

module {
    // User-facing type: what application code uses
    public type InnerRecordWithEnum = {
        status : AvailabilityEnum;
        message : ?Text;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer InnerRecordWithEnum type
        public type JSON = {
            status : AvailabilityEnum.JSON;
            message : ?Text;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : InnerRecordWithEnum) : JSON = { value with
            status = AvailabilityEnum.toJSON(value.status);
        };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?InnerRecordWithEnum {
            let ?status = AvailabilityEnum.fromJSON(json.status) else return null;
            ?{ json with
                status;
            }
        };
    }
}
