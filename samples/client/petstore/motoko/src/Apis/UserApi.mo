// UserApi.mo

import Text "mo:core/Text";
import Int "mo:core/Int";
import Blob "mo:core/Blob";
import Array "mo:core/Array";
import Error "mo:core/Error";
import Base64 "mo:core/Base64";
import { JSON; Candid } "mo:serde-core";
// FIXME: destructuring on `actor` types is not implemented yet for shared functions
//        type error [M0114], object pattern cannot consume actor type
import { type http_request_args; type http_request_result; type http_header } "ic:aaaaa-aa";
import Mgnt__ = "ic:aaaaa-aa";
import { type User; JSON = User } "../Models/User";
import { type Config } "../Config";

module {
    let http_request = Mgnt__.http_request;


    /// Create user
    ///
    /// This can only be done by the logged in user.
    public func createUser(config : Config, user : User) : async* () {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/user";

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
                let encoded = Base64.encode(Text.encodeUtf8(user # ":" # password));
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
                let jsonValue = User.toJSON(user);
                let candidBlob = to_candid(jsonValue);
                let #ok(jsonText) = JSON.toText(candidBlob, ["id", "username", "firstName", "lastName", "email", "password", "phone", "userStatus"], ?{ Candid.defaultOptions with skip_null_fields = true }) else throw Error.reject("Failed to serialize to JSON");
                Text.encodeUtf8(jsonText)
            };
        };

        // Call the management canister's http_request method with cycles
        ignore await (with cycles) http_request(request);

    };

    /// Creates list of users with given input array
    ///
    /// 
    public func createUsersWithArrayInput(config : Config, user : [User]) : async* () {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/user/createWithArray";

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
                let encoded = Base64.encode(Text.encodeUtf8(user # ":" # password));
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
                let jsonValue = Array.map<User, User.JSON>(user, User.toJSON);
                let candidBlob = to_candid(jsonValue);
                let #ok(jsonText) = JSON.toText(candidBlob, [], ?{ Candid.defaultOptions with skip_null_fields = true }) else throw Error.reject("Failed to serialize to JSON");
                Text.encodeUtf8(jsonText)
            };
        };

        // Call the management canister's http_request method with cycles
        ignore await (with cycles) http_request(request);

    };

    /// Creates list of users with given input array
    ///
    /// 
    public func createUsersWithListInput(config : Config, user : [User]) : async* () {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/user/createWithList";

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
                let encoded = Base64.encode(Text.encodeUtf8(user # ":" # password));
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
                let jsonValue = Array.map<User, User.JSON>(user, User.toJSON);
                let candidBlob = to_candid(jsonValue);
                let #ok(jsonText) = JSON.toText(candidBlob, [], ?{ Candid.defaultOptions with skip_null_fields = true }) else throw Error.reject("Failed to serialize to JSON");
                Text.encodeUtf8(jsonText)
            };
        };

        // Call the management canister's http_request method with cycles
        ignore await (with cycles) http_request(request);

    };

    /// Delete user
    ///
    /// This can only be done by the logged in user.
    public func deleteUser(config : Config, username : Text) : async* () {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/user/{username}"
            |> Text.replace(_, #text "{username}", username);

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
                let encoded = Base64.encode(Text.encodeUtf8(user # ":" # password));
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

    /// Get user by user name
    ///
    /// 
    public func getUserByName(config : Config, username : Text) : async* User {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/user/{username}"
            |> Text.replace(_, #text "{username}", username);

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
                let encoded = Base64.encode(Text.encodeUtf8(user # ":" # password));
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
            from_candid(_) : ?User.JSON |>
            (switch (_) {
                case (?jsonValue) {
                    switch (User.fromJSON(jsonValue)) {
                        case (?value) value;
                        case null throw Error.reject("HTTP " # Int.toText(response.status) # ": Failed to convert response to User");
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

            // 400: Invalid username supplied (no response body model defined)
            if (response.status == 400) {
                throw Error.reject("HTTP 400: Invalid username supplied");
            };
            // 404: User not found (no response body model defined)
            if (response.status == 404) {
                throw Error.reject("HTTP 404: User not found");
            };

            // Fallback for status codes not defined in OpenAPI spec
            throw Error.reject("HTTP " # Int.toText(response.status) # ": Unexpected error" #
                (if (responseText != "") { " - " # responseText } else { "" }));
        }
    };

    /// Logs user into the system
    ///
    /// 
    public func loginUser(config : Config, username : Text, password : Text) : async* Text {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/user/login"
            # "?" # "username=" # username # "&" # "password=" # password;

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
                let encoded = Base64.encode(Text.encodeUtf8(user # ":" # password));
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
            from_candid(_) : ?Text |>
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

            // 400: Invalid username/password supplied (no response body model defined)
            if (response.status == 400) {
                throw Error.reject("HTTP 400: Invalid username/password supplied");
            };

            // Fallback for status codes not defined in OpenAPI spec
            throw Error.reject("HTTP " # Int.toText(response.status) # ": Unexpected error" #
                (if (responseText != "") { " - " # responseText } else { "" }));
        }
    };

    /// Logs out current logged in user session
    ///
    /// 
    public func logoutUser(config : Config) : async* () {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/user/logout";

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
                let encoded = Base64.encode(Text.encodeUtf8(user # ":" # password));
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
        ignore await (with cycles) http_request(request);

    };

    /// Updated user
    ///
    /// This can only be done by the logged in user.
    public func updateUser(config : Config, username : Text, user : User) : async* () {
        let {baseUrl; cycles} = config;
        let baseUrl__ = baseUrl # "/user/{username}"
            |> Text.replace(_, #text "{username}", username);

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
                let encoded = Base64.encode(Text.encodeUtf8(user # ":" # password));
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
            method = #put;
            headers;
            body = do ? {
                let jsonValue = User.toJSON(user);
                let candidBlob = to_candid(jsonValue);
                let #ok(jsonText) = JSON.toText(candidBlob, ["id", "username", "firstName", "lastName", "email", "password", "phone", "userStatus"], ?{ Candid.defaultOptions with skip_null_fields = true }) else throw Error.reject("Failed to serialize to JSON");
                Text.encodeUtf8(jsonText)
            };
        };

        // Call the management canister's http_request method with cycles
        ignore await (with cycles) http_request(request);

    };


    let operations__ = {
        createUser;
        createUsersWithArrayInput;
        createUsersWithListInput;
        deleteUser;
        getUserByName;
        loginUser;
        logoutUser;
        updateUser;
    };

    public module class UserApi(config : Config) {
        /// Create user
        ///
        /// This can only be done by the logged in user.
        public func createUser(user : User) : async () {
            await* operations__.createUser(config, user)
        };

        /// Creates list of users with given input array
        ///
        /// 
        public func createUsersWithArrayInput(user : [User]) : async () {
            await* operations__.createUsersWithArrayInput(config, user)
        };

        /// Creates list of users with given input array
        ///
        /// 
        public func createUsersWithListInput(user : [User]) : async () {
            await* operations__.createUsersWithListInput(config, user)
        };

        /// Delete user
        ///
        /// This can only be done by the logged in user.
        public func deleteUser(username : Text) : async () {
            await* operations__.deleteUser(config, username)
        };

        /// Get user by user name
        ///
        /// 
        public func getUserByName(username : Text) : async User {
            await* operations__.getUserByName(config, username)
        };

        /// Logs user into the system
        ///
        /// 
        public func loginUser(username : Text, password : Text) : async Text {
            await* operations__.loginUser(config, username, password)
        };

        /// Logs out current logged in user session
        ///
        /// 
        public func logoutUser() : async () {
            await* operations__.logoutUser(config)
        };

        /// Updated user
        ///
        /// This can only be done by the logged in user.
        public func updateUser(username : Text, user : User) : async () {
            await* operations__.updateUser(config, username, user)
        };

    }
}
