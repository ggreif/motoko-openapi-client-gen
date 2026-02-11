// StoreApi.mo

import Text "mo:core/Text";
import Int "mo:core/Int";
import Nat8 "mo:core/Nat8";
import Nat32 "mo:core/Nat32";
import Blob "mo:core/Blob";
import Array "mo:core/Array";
import Iter "mo:core/Iter";
import Error "mo:core/Error";
import { JSON } "mo:serde";
// FIXME: destructuring on `actor` types is not implemented yet for shared functions
//        type error [M0114], object pattern cannot consume actor type
import { type http_request_args; type http_request_result; type http_header } "ic:aaaaa-aa";
import Mgnt__ = "ic:aaaaa-aa";
import { type Order; JSON = Order } "../Models/Order";
import { type Map } "mo:core/pure/Map";

module {
    type http_method = {
        #get;
        #head;
        #post;
        // TODO: IC HTTP outcalls currently only support GET, HEAD, and POST.
        //   PUT and DELETE methods are not yet supported by the management canister.
        //   Once support is added, uncomment these:
        // #put;
        // #delete;
    };

    let http_request = Mgnt__.http_request;

    // Base64 encoding for Basic Auth
    func base64Encode(bytes : [Nat8]) : Text {
        let base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        let base64CharsArray = Iter.toArray(base64Chars.chars());
        var result = "";
        var i = 0;
        while (i < bytes.size()) {
            let b1 = bytes[i];
            let b2 : Nat8 = if (i + 1 < bytes.size()) bytes[i + 1] else 0;
            let b3 : Nat8 = if (i + 2 < bytes.size()) bytes[i + 2] else 0;

            let n = (Nat32.fromNat(Nat8.toNat(b1)) << 16) | (Nat32.fromNat(Nat8.toNat(b2)) << 8) | Nat32.fromNat(Nat8.toNat(b3));

            let c1 = Text.fromChar(base64CharsArray[Nat32.toNat((n >> 18) & 0x3F)]);
            let c2 = Text.fromChar(base64CharsArray[Nat32.toNat((n >> 12) & 0x3F)]);
            let c3 = if (i + 1 < bytes.size()) Text.fromChar(base64CharsArray[Nat32.toNat((n >> 6) & 0x3F)]) else "=";
            let c4 = if (i + 2 < bytes.size()) Text.fromChar(base64CharsArray[Nat32.toNat(n & 0x3F)]) else "=";

            result #= c1 # c2 # c3 # c4;
            i += 3;
        };
        result
    };

    public type Auth__ = {
        #bearer : Text;
        #apiKey : Text;
        #basicAuth : { user : Text; password : Text };
    };

    public type Config__ = {
        baseUrl : Text;
        auth : ?Auth__;
        max_response_bytes : ?Nat64;
        transform : ?{
            function : shared query ({ response : http_request_result; context : Blob }) -> async http_request_result;
            context : Blob;
        };
        is_replicated : ?Bool;
        cycles : Nat;
    };

    /// Delete purchase order by ID
    /// For valid response try integer IDs with value < 1000. Anything above 1000 or nonintegers will generate API errors
    public func deleteOrder(config : Config__, orderId : Text) : async* () {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/store/order/{orderId}"
            |> Text.replace(_, #text "{orderId}", orderId);

        // Add API key as query parameter if using apiKey auth
        let url = switch (config.auth) {
            case _ baseUrl__;
        };

        let baseHeaders = [
            { name = "Content-Type"; value = "application/json; charset=utf-8" }
        ];

        // Build authentication headers based on auth type
        let authHeaders = switch (config.auth) {
            case (?#bearer(token)) {
                [{ name = "Authorization"; value = "Bearer " # token }]
            };
            case (?#apiKey(key)) {
                // API key goes in header
                [{ name = "api_key"; value = key }]
            };
            case (?#basicAuth({user; password})) {
                let credentials = user # ":" # password;
                let credentialsBytes = Blob.toArray(Text.encodeUtf8(credentials));
                let encoded = base64Encode(credentialsBytes);
                [{ name = "Authorization"; value = "Basic " # encoded }]
            };
            case null [];
        };

        let headers = Array.flatten<http_header>([
            baseHeaders,
            authHeaders
        ]);

        let request : http_request_args = { config with
            url;
            method = #delete;
            headers;
            body = null;
        };

        // Call the management canister's http_request method with cycles
        ignore await (with cycles) http_request(request);

    };

    /// Returns pet inventories by status
    /// Returns a map of status codes to quantities
    public func getInventory(config : Config__) : async* Map<Text, Int> {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/store/inventory";

        // Add API key as query parameter if using apiKey auth
        let url = switch (config.auth) {
            case _ baseUrl__;
        };

        let baseHeaders = [
            { name = "Content-Type"; value = "application/json; charset=utf-8" }
        ];

        // Build authentication headers based on auth type
        let authHeaders = switch (config.auth) {
            case (?#bearer(token)) {
                [{ name = "Authorization"; value = "Bearer " # token }]
            };
            case (?#apiKey(key)) {
                // API key goes in header
                [{ name = "api_key"; value = key }]
            };
            case (?#basicAuth({user; password})) {
                let credentials = user # ":" # password;
                let credentialsBytes = Blob.toArray(Text.encodeUtf8(credentials));
                let encoded = base64Encode(credentialsBytes);
                [{ name = "Authorization"; value = "Basic " # encoded }]
            };
            case null [];
        };

        let headers = Array.flatten<http_header>([
            baseHeaders,
            authHeaders
        ]);

        let request : http_request_args = { config with
            url;
            method = #get;
            headers;
            body = null;
        };

        // Call the management canister's http_request method with cycles
        let response : http_request_result = await (with cycles) http_request(request);

        // Check HTTP status code before parsing
        if (response.status >= 200 and response.status < 300) {
            // Success response (2xx): parse as expected return type
            (switch (Text.decodeUtf8(response.body)) {
                case (?text) text;
                case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to decode response body as UTF-8");
            }) |>
            (switch (JSON.fromText(_, null)) {
                case (#ok(blob)) blob;
                case (#err(msg)) throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to parse JSON: " # msg);
            }) |>
            from_candid(_) : ?Map<Text, Int>.JSON |>
            (switch (_) {
                case (?jsonValue) {
                    switch (Map<Text, Int>.fromJSON(jsonValue)) {
                        case (?value) value;
                        case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to convert response to Map<Text, Int>");
                    }
                };
                case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to deserialize response");
            })
        } else {
            // Error response (4xx, 5xx): parse error models and throw
            let responseText = switch (Text.decodeUtf8(response.body)) {
                case (?text) text;
                case null "";  // Empty body for some errors (e.g., 404)
            };


            // Fallback for status codes not defined in OpenAPI spec
            throw Error.reject("HTTP " # Int.toText(response.status) # ": Unexpected error" #
                (if (responseText != "") { " - " # responseText } else { "" }));
        }
    };

    /// Find purchase order by ID
    /// For valid response try integer IDs with value <= 5 or > 10. Other values will generate exceptions
    public func getOrderById(config : Config__, orderId : Nat) : async* Order {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/store/order/{orderId}"
            |> Text.replace(_, #text "{orderId}", debug_show(orderId));

        // Add API key as query parameter if using apiKey auth
        let url = switch (config.auth) {
            case _ baseUrl__;
        };

        let baseHeaders = [
            { name = "Content-Type"; value = "application/json; charset=utf-8" }
        ];

        // Build authentication headers based on auth type
        let authHeaders = switch (config.auth) {
            case (?#bearer(token)) {
                [{ name = "Authorization"; value = "Bearer " # token }]
            };
            case (?#apiKey(key)) {
                // API key goes in header
                [{ name = "api_key"; value = key }]
            };
            case (?#basicAuth({user; password})) {
                let credentials = user # ":" # password;
                let credentialsBytes = Blob.toArray(Text.encodeUtf8(credentials));
                let encoded = base64Encode(credentialsBytes);
                [{ name = "Authorization"; value = "Basic " # encoded }]
            };
            case null [];
        };

        let headers = Array.flatten<http_header>([
            baseHeaders,
            authHeaders
        ]);

        let request : http_request_args = { config with
            url;
            method = #get;
            headers;
            body = null;
        };

        // Call the management canister's http_request method with cycles
        let response : http_request_result = await (with cycles) http_request(request);

        // Check HTTP status code before parsing
        if (response.status >= 200 and response.status < 300) {
            // Success response (2xx): parse as expected return type
            (switch (Text.decodeUtf8(response.body)) {
                case (?text) text;
                case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to decode response body as UTF-8");
            }) |>
            (switch (JSON.fromText(_, null)) {
                case (#ok(blob)) blob;
                case (#err(msg)) throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to parse JSON: " # msg);
            }) |>
            from_candid(_) : ?Order.JSON |>
            (switch (_) {
                case (?jsonValue) {
                    switch (Order.fromJSON(jsonValue)) {
                        case (?value) value;
                        case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to convert response to Order");
                    }
                };
                case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to deserialize response");
            })
        } else {
            // Error response (4xx, 5xx): parse error models and throw
            let responseText = switch (Text.decodeUtf8(response.body)) {
                case (?text) text;
                case null "";  // Empty body for some errors (e.g., 404)
            };

            // 400: Invalid ID supplied (no response body model defined)
            if (response.status == 400) {
                throw Error.reject("HTTP 400: Invalid ID supplied");
            };
            // 404: Order not found (no response body model defined)
            if (response.status == 404) {
                throw Error.reject("HTTP 404: Order not found");
            };

            // Fallback for status codes not defined in OpenAPI spec
            throw Error.reject("HTTP " # Int.toText(response.status) # ": Unexpected error" #
                (if (responseText != "") { " - " # responseText } else { "" }));
        }
    };

    /// Place an order for a pet
    /// 
    public func placeOrder(config : Config__, order : Order) : async* Order {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/store/order";

        // Add API key as query parameter if using apiKey auth
        let url = switch (config.auth) {
            case _ baseUrl__;
        };

        let baseHeaders = [
            { name = "Content-Type"; value = "application/json; charset=utf-8" }
        ];

        // Build authentication headers based on auth type
        let authHeaders = switch (config.auth) {
            case (?#bearer(token)) {
                [{ name = "Authorization"; value = "Bearer " # token }]
            };
            case (?#apiKey(key)) {
                // API key goes in header
                [{ name = "api_key"; value = key }]
            };
            case (?#basicAuth({user; password})) {
                let credentials = user # ":" # password;
                let credentialsBytes = Blob.toArray(Text.encodeUtf8(credentials));
                let encoded = base64Encode(credentialsBytes);
                [{ name = "Authorization"; value = "Basic " # encoded }]
            };
            case null [];
        };

        let headers = Array.flatten<http_header>([
            baseHeaders,
            authHeaders
        ]);

        let request : http_request_args = { config with
            url;
            method = #post;
            headers;
            body = do ? {
                let jsonValue = Order.toJSON(order);
                let candidBlob = to_candid(jsonValue);
                let #ok(jsonText) = JSON.toText(candidBlob, [], null) else throw Error.reject("Failed to serialize to JSON");
                Text.encodeUtf8(jsonText)
            };
        };

        // Call the management canister's http_request method with cycles
        let response : http_request_result = await (with cycles) http_request(request);

        // Check HTTP status code before parsing
        if (response.status >= 200 and response.status < 300) {
            // Success response (2xx): parse as expected return type
            (switch (Text.decodeUtf8(response.body)) {
                case (?text) text;
                case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to decode response body as UTF-8");
            }) |>
            (switch (JSON.fromText(_, null)) {
                case (#ok(blob)) blob;
                case (#err(msg)) throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to parse JSON: " # msg);
            }) |>
            from_candid(_) : ?Order.JSON |>
            (switch (_) {
                case (?jsonValue) {
                    switch (Order.fromJSON(jsonValue)) {
                        case (?value) value;
                        case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to convert response to Order");
                    }
                };
                case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to deserialize response");
            })
        } else {
            // Error response (4xx, 5xx): parse error models and throw
            let responseText = switch (Text.decodeUtf8(response.body)) {
                case (?text) text;
                case null "";  // Empty body for some errors (e.g., 404)
            };

            // 400: Invalid Order (no response body model defined)
            if (response.status == 400) {
                throw Error.reject("HTTP 400: Invalid Order");
            };

            // Fallback for status codes not defined in OpenAPI spec
            throw Error.reject("HTTP " # Int.toText(response.status) # ": Unexpected error" #
                (if (responseText != "") { " - " # responseText } else { "" }));
        }
    };


    let operations__ = {
        deleteOrder;
        getInventory;
        getOrderById;
        placeOrder;
    };

    public module class StoreApi(config : Config__) {
        /// Delete purchase order by ID
        /// For valid response try integer IDs with value < 1000. Anything above 1000 or nonintegers will generate API errors
        public func deleteOrder(orderId : Text) : async () {
            await* operations__.deleteOrder(config, orderId)
        };

        /// Returns pet inventories by status
        /// Returns a map of status codes to quantities
        public func getInventory() : async Map<Text, Int> {
            await* operations__.getInventory(config)
        };

        /// Find purchase order by ID
        /// For valid response try integer IDs with value <= 5 or > 10. Other values will generate exceptions
        public func getOrderById(orderId : Nat) : async Order {
            await* operations__.getOrderById(config, orderId)
        };

        /// Place an order for a pet
        /// 
        public func placeOrder(order : Order) : async Order {
            await* operations__.placeOrder(config, order)
        };

    }
}
