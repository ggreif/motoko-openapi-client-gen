// GenresApi.mo

import Text "mo:core/Text";
import Int "mo:core/Int";
import Nat8 "mo:core/Nat8";
import Nat32 "mo:core/Nat32";
import Blob "mo:core/Blob";
import Array "mo:core/Array";
import Iter "mo:core/Iter";
import Error "mo:core/Error";
import { JSON } "mo:serde";
import { type GetAnAlbum401Response; JSON = GetAnAlbum401Response } "../Models/GetAnAlbum401Response";
import { type GetRecommendationGenres200Response; JSON = GetRecommendationGenres200Response } "../Models/GetRecommendationGenres200Response";

module {
    // Management Canister interface for HTTP outcalls
    // Based on types in https://github.com/dfinity/sdk/blob/master/src/dfx/src/util/ic.did
    type http_header = {
        name : Text;
        value : Text;
    };

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

    type http_request_args = {
        url : Text;
        max_response_bytes : ?Nat64;
        method : http_method;
        headers : [http_header];
        body : ?Blob;
        transform : ?{
            function : shared query ({ response : http_request_result; context : Blob }) -> async http_request_result;
            context : Blob;
        };
        is_replicated : ?Bool;
    };

    type http_request_result = {
        status : Nat;
        headers : [http_header];
        body : Blob;
    };

    let http_request = (actor "aaaaa-aa" : actor { http_request : (http_request_args) -> async http_request_result }).http_request;

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

    /// Get Available Genre Seeds 
    /// Retrieve a list of available genres seed parameter values for [recommendations](/documentation/web-api/reference/get-recommendations). 
    public func getRecommendationGenres(config : Config__) : async* GetRecommendationGenres200Response {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/recommendations/available-genre-seeds";

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
            from_candid(_) : ?GetRecommendationGenres200Response.JSON |>
            (switch (_) {
                case (?jsonValue) {
                    switch (GetRecommendationGenres200Response.fromJSON(jsonValue)) {
                        case (?value) value;
                        case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to convert response to GetRecommendationGenres200Response");
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

            // Try parsing 401 response as GetAnAlbum401Response
            if (response.status == 401) {
                let errorDetail = if (responseText != "") {
                    switch (JSON.fromText(responseText, null)) {
                        case (#ok(blob)) {
                            let parsedJson : ?GetAnAlbum401Response.JSON = from_candid(blob);
                            switch (parsedJson) {
                                case (?jsonValue) {
                                    switch (GetAnAlbum401Response.fromJSON(jsonValue)) {
                                        case (?err) " - " # debug_show(err);
                                        case null " - " # responseText;
                                    }
                                };
                                case null " - " # responseText;
                            };
                        };
                        case (#err(_)) " - " # responseText;
                    };
                } else { "" };
                throw Error.reject("HTTP 401: Bad or expired token. This can happen if the user revoked a token or the access token has expired. You should re-authenticate the user. " # errorDetail);
            };
            // Try parsing 403 response as GetAnAlbum401Response
            if (response.status == 403) {
                let errorDetail = if (responseText != "") {
                    switch (JSON.fromText(responseText, null)) {
                        case (#ok(blob)) {
                            let parsedJson : ?GetAnAlbum401Response.JSON = from_candid(blob);
                            switch (parsedJson) {
                                case (?jsonValue) {
                                    switch (GetAnAlbum401Response.fromJSON(jsonValue)) {
                                        case (?err) " - " # debug_show(err);
                                        case null " - " # responseText;
                                    }
                                };
                                case null " - " # responseText;
                            };
                        };
                        case (#err(_)) " - " # responseText;
                    };
                } else { "" };
                throw Error.reject("HTTP 403: Bad OAuth request (wrong consumer key, bad nonce, expired timestamp...). Unfortunately, re-authenticating the user won&#39;t help here. " # errorDetail);
            };
            // Try parsing 429 response as GetAnAlbum401Response
            if (response.status == 429) {
                let errorDetail = if (responseText != "") {
                    switch (JSON.fromText(responseText, null)) {
                        case (#ok(blob)) {
                            let parsedJson : ?GetAnAlbum401Response.JSON = from_candid(blob);
                            switch (parsedJson) {
                                case (?jsonValue) {
                                    switch (GetAnAlbum401Response.fromJSON(jsonValue)) {
                                        case (?err) " - " # debug_show(err);
                                        case null " - " # responseText;
                                    }
                                };
                                case null " - " # responseText;
                            };
                        };
                        case (#err(_)) " - " # responseText;
                    };
                } else { "" };
                throw Error.reject("HTTP 429: The app has exceeded its rate limits. " # errorDetail);
            };

            // Fallback for status codes not defined in OpenAPI spec
            throw Error.reject("HTTP " # Int.toText(response.status) # ": Unexpected error" #
                (if (responseText != "") { " - " # responseText } else { "" }));
        }
    };


    let operations__ = {
        getRecommendationGenres;
    };

    public module class GenresApi(config : Config__) {
        /// Get Available Genre Seeds 
        /// Retrieve a list of available genres seed parameter values for [recommendations](/documentation/web-api/reference/get-recommendations). 
        public func getRecommendationGenres() : async GetRecommendationGenres200Response {
            await* operations__.getRecommendationGenres(config)
        };

    }
}
