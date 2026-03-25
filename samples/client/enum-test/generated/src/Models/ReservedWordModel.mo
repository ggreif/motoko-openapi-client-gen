
// ReservedWordModel.mo
/// Model with reserved word field names

module {
    // User-facing type: what application code uses
    public type ReservedWordModel = {
        try_ : Text;
        type_ : ?Text;
        switch_ : ?Int;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer ReservedWordModel type
        public type JSON = {
            try_ : Text;
            type_ : ?Text;
            switch_ : ?Int;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : ReservedWordModel) : JSON = value;

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?ReservedWordModel = ?json;
    }
}
