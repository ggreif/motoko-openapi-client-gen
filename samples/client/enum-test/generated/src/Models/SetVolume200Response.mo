
import { type VolumeParameter; JSON = VolumeParameter } "./VolumeParameter";

// SetVolume200Response.mo

module {
    // User-facing type: what application code uses
    public type SetVolume200Response = {
        status : ?Text;
        volume : ?VolumeParameter;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SetVolume200Response type
        public type JSON = {
            status : ?Text;
            volume : ?VolumeParameter;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SetVolume200Response) : JSON = value;

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SetVolume200Response = ?json;
    }
}
