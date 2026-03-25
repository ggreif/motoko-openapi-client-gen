
import { type AvailabilityEnum; JSON = AvailabilityEnum } "./AvailabilityEnum";

import { type HTTPStatusEnum; JSON = HTTPStatusEnum } "./HTTPStatusEnum";

// FieldAndEnumMapping.mo
/// Test model with BOTH field name mapping AND enum value mapping

module {
    // User-facing type: what application code uses
    public type FieldAndEnumMapping = {
        status_code : HTTPStatusEnum;
        availability_status : ?AvailabilityEnum;
        content_type : ?Text;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer FieldAndEnumMapping type
        public type JSON = {
            status_code : HTTPStatusEnum.JSON;
            availability_status : ?AvailabilityEnum.JSON;
            content_type : ?Text;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : FieldAndEnumMapping) : JSON = { value with
            status_code = HTTPStatusEnum.toJSON(value.status_code);
            availability_status = do ? { AvailabilityEnum.toJSON(value.availability_status!) };
        };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?FieldAndEnumMapping {
            let ?status_code = HTTPStatusEnum.fromJSON(json.status_code) else return null;
            ?{ json with
                status_code;
                availability_status = do ? { AvailabilityEnum.fromJSON(json.availability_status!)! };
            }
        };
    }
}
