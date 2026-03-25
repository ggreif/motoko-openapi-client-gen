
// AvailabilityEnum.mo
/// Enum with spaces and special characters
/// Enum values: #available_now, #out_of_stock, #pre_order, #coming_soon

module {
    // User-facing type: type-safe variants for application code
    public type AvailabilityEnum = {
        #available_now;
        #out_of_stock;
        #pre_order;
        #coming_soon;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer AvailabilityEnum type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : AvailabilityEnum) : JSON =
            switch (value) {
                case (#available_now) "Available Now!";
                case (#out_of_stock) "Out of Stock";
                case (#pre_order) "Pre-Order";
                case (#coming_soon) "Coming Soon...";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?AvailabilityEnum =
            switch (json) {
                case "Available Now!" ?#available_now;
                case "Out of Stock" ?#out_of_stock;
                case "Pre-Order" ?#pre_order;
                case "Coming Soon..." ?#coming_soon;
                case _ null;
            };
    }
}
