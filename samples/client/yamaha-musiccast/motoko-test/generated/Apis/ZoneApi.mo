// ZoneApi.mo

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
import { type SetInputInputParameter; JSON = SetInputInputParameter } "../Models/SetInputInputParameter";
import { type SetInputModeParameter; JSON = SetInputModeParameter } "../Models/SetInputModeParameter";
import { type SetVolumeVolumeParameter; JSON = SetVolumeVolumeParameter } "../Models/SetVolumeVolumeParameter";

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

    /// Get sound program list
    /// Returns the list of available sound programs for the zone
    public func getSoundProgramList(config : Config__, zone : Text) : async* Any {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/{zone}/getSoundProgramList"
            |> Text.replace(_, #text "{zone}", zone);

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
                // API key goes in query parameter, not header
                []
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
            from_candid(_) : ?Any |>
            (switch (_) {
                case (?result) result;
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

    /// Get zone status
    /// Returns the current status of the specified zone
    public func getZoneStatus(config : Config__, zone : Text) : async* Any {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/{zone}/getStatus"
            |> Text.replace(_, #text "{zone}", zone);

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
                // API key goes in query parameter, not header
                []
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
            from_candid(_) : ?Any |>
            (switch (_) {
                case (?result) result;
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

    /// Prepare input change
    /// Let a device do necessary process before changing input in a specific zone
    public func prepareInputChange(config : Config__, zone : Text, input : Text) : async* Any {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/{zone}/prepareInputChange"
            |> Text.replace(_, #text "{zone}", zone)
            # "?" # "input=" # input;

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
                // API key goes in query parameter, not header
                []
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
            from_candid(_) : ?Any |>
            (switch (_) {
                case (?result) result;
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

    /// Set input source
    /// Sets the input source for the zone
    public func setInput(config : Config__, zone : Text, input : SetInputInputParameter, mode : SetInputModeParameter) : async* Any {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/{zone}/setInput"
            |> Text.replace(_, #text "{zone}", zone)
            # "?" # "input=" # SetInputInputParameter.toJSON(input) # "&" # "mode=" # SetInputModeParameter.toJSON(mode);

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
                // API key goes in query parameter, not header
                []
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
            from_candid(_) : ?Any |>
            (switch (_) {
                case (?result) result;
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

    /// Set mute
    /// Enables or disables mute for the zone
    public func setMute(config : Config__, zone : Text, enable : Bool) : async* Any {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/{zone}/setMute"
            |> Text.replace(_, #text "{zone}", zone)
            # "?" # "enable=" # debug_show(enable);

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
                // API key goes in query parameter, not header
                []
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
            from_candid(_) : ?Any |>
            (switch (_) {
                case (?result) result;
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

    /// Set sleep timer
    /// Sets the sleep timer in minutes (0 to cancel)
    public func setSleep(config : Config__, zone : Text, sleep : Nat) : async* Any {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/{zone}/setSleep"
            |> Text.replace(_, #text "{zone}", zone)
            # "?" # "sleep=" # Int.toText(sleep);

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
                // API key goes in query parameter, not header
                []
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
            from_candid(_) : ?Any |>
            (switch (_) {
                case (?result) result;
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

    /// Set sound program
    /// Sets the sound program (DSP mode) for the zone
    public func setSoundProgram(config : Config__, zone : Text, program : Text) : async* Any {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/{zone}/setSoundProgram"
            |> Text.replace(_, #text "{zone}", zone)
            # "?" # "program=" # program;

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
                // API key goes in query parameter, not header
                []
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
            from_candid(_) : ?Any |>
            (switch (_) {
                case (?result) result;
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

    /// Set volume
    /// Sets the volume level directly or incrementally
    public func setVolume(config : Config__, zone : Text, volume : SetVolumeVolumeParameter, step : Nat) : async* Any {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/{zone}/setVolume"
            |> Text.replace(_, #text "{zone}", zone)
            # "?" # "volume=" # SetVolumeVolumeParameter.toText(volume) # "&" # "step=" # Int.toText(step);

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
                // API key goes in query parameter, not header
                []
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
            from_candid(_) : ?Any |>
            (switch (_) {
                case (?result) result;
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


    let operations__ = {
        getSoundProgramList;
        getZoneStatus;
        prepareInputChange;
        setInput;
        setMute;
        setSleep;
        setSoundProgram;
        setVolume;
    };

    public module class ZoneApi(config : Config__) {
        /// Get sound program list
        /// Returns the list of available sound programs for the zone
        public func getSoundProgramList(zone : Text) : async Any {
            await* operations__.getSoundProgramList(config, zone)
        };

        /// Get zone status
        /// Returns the current status of the specified zone
        public func getZoneStatus(zone : Text) : async Any {
            await* operations__.getZoneStatus(config, zone)
        };

        /// Prepare input change
        /// Let a device do necessary process before changing input in a specific zone
        public func prepareInputChange(zone : Text, input : Text) : async Any {
            await* operations__.prepareInputChange(config, zone, input)
        };

        /// Set input source
        /// Sets the input source for the zone
        public func setInput(zone : Text, input : SetInputInputParameter, mode : SetInputModeParameter) : async Any {
            await* operations__.setInput(config, zone, input, mode)
        };

        /// Set mute
        /// Enables or disables mute for the zone
        public func setMute(zone : Text, enable : Bool) : async Any {
            await* operations__.setMute(config, zone, enable)
        };

        /// Set sleep timer
        /// Sets the sleep timer in minutes (0 to cancel)
        public func setSleep(zone : Text, sleep : Nat) : async Any {
            await* operations__.setSleep(config, zone, sleep)
        };

        /// Set sound program
        /// Sets the sound program (DSP mode) for the zone
        public func setSoundProgram(zone : Text, program : Text) : async Any {
            await* operations__.setSoundProgram(config, zone, program)
        };

        /// Set volume
        /// Sets the volume level directly or incrementally
        public func setVolume(zone : Text, volume : SetVolumeVolumeParameter, step : Nat) : async Any {
            await* operations__.setVolume(config, zone, volume, step)
        };

    }
}
