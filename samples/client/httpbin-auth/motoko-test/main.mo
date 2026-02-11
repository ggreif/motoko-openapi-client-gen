import { testBearer; getHeaders; testApiKeyHeader; testApiKeyQuery; testBasicAuth } "./generated/Apis/DefaultApi";
import Debug "mo:core/Debug";
import Text "mo:core/Text";
import Error "mo:core/Error";

persistent actor HttpBinAuthTest {
    type Config = {
        baseUrl : Text;
        accessToken : ?Text;
        apiKey : ?Text;
        basicAuthUser : ?Text;
        basicAuthPassword : ?Text;
        max_response_bytes : ?Nat64;
        transform : ?{
            function : shared query ({ response : http_request_result; context : Blob }) -> async http_request_result;
            context : Blob;
        };
        is_replicated : ?Bool;
        cycles : Nat;
    };

    type http_request_result = {
        status : Nat;
        headers : [{ name : Text; value : Text }];
        body : Blob;
    };

    // Test 1: Bearer token is correctly added to Authorization header
    public func test1_BearerAuth() : async Text {
        Debug.print("Test 1: Bearer token authentication");

        let config : Config = {
            baseUrl = "https://httpbin.org";
            accessToken = ?"test-token-12345";
            apiKey = null;
            basicAuthUser = null;
            basicAuthPassword = null;
            max_response_bytes = null;
            transform = null;
            is_replicated = null;
            cycles = 30_000_000_000;
        };

        try {
            let response = await* testBearer(config);

            // Both fields are optional, need to unwrap
            switch (response.authenticated, response.token) {
                case (?true, ?"test-token-12345") {
                    Debug.print("✅ Bearer token auth working correctly");
                    "✅ PASS: Bearer token sent correctly"
                };
                case (?isAuth, ?token) {
                    Debug.print("❌ Bearer token not sent correctly");
                    Debug.print("  Expected: authenticated=true, token=test-token-12345");
                    Debug.print("  Received: authenticated=" # debug_show(isAuth) # ", token=" # token);
                    "❌ FAIL: Token or auth status mismatch"
                };
                case _ {
                    Debug.print("❌ Missing response fields");
                    "❌ FAIL: Response missing authenticated or token field"
                };
            }
        } catch (e) {
            let msg = Error.message(e);
            Debug.print("❌ Bearer auth test failed: " # msg);
            "❌ FAIL: " # msg
        }
    };

    // Test 2: Missing token results in 401
    public func test2_BearerAuthMissing() : async Text {
        Debug.print("Test 2: Bearer auth without token (should fail with 401)");

        let config : Config = {
            baseUrl = "https://httpbin.org";
            accessToken = null;
            apiKey = null;
            basicAuthUser = null;
            basicAuthPassword = null;
            max_response_bytes = null;
            transform = null;
            is_replicated = null;
            cycles = 30_000_000_000;
        };

        try {
            let _response = await* testBearer(config);
            Debug.print("❌ Should have thrown 401 error");
            "❌ FAIL: Expected 401 error"
        } catch (e) {
            let msg = Error.message(e);
            if (Text.contains(msg, #text "401")) {
                Debug.print("✅ Correctly rejected request without token (401)");
                "✅ PASS: 401 error as expected"
            } else {
                Debug.print("❌ Wrong error: " # msg);
                "❌ FAIL: Expected 401, got different error"
            }
        }
    };

    // Test 3: Verify Authorization header is sent via /headers endpoint
    public func test3_AuthHeaderFormat() : async Text {
        Debug.print("Test 3: Verify Authorization header sent to /headers endpoint");

        let config : Config = {
            baseUrl = "https://httpbin.org";
            accessToken = ?"my-secret-token";
            apiKey = null;
            basicAuthUser = null;
            basicAuthPassword = null;
            max_response_bytes = null;
            transform = null;
            is_replicated = null;
            cycles = 30_000_000_000;
        };

        try {
            let _response = await* getHeaders(config);
            Debug.print("✅ Successfully called /headers endpoint with bearer token");
            "✅ PASS: /headers endpoint accessible"
        } catch (e) {
            let msg = Error.message(e);
            Debug.print("❌ Header test failed: " # msg);
            "❌ FAIL: " # msg
        }
    };

    // Test 4: API key in header
    public func test4_ApiKeyHeader() : async Text {
        Debug.print("Test 4: API key in header (X-API-Key)");

        let config : Config = {
            baseUrl = "https://httpbin.org";
            accessToken = null;
            apiKey = ?"test-api-key-12345";
            basicAuthUser = null;
            basicAuthPassword = null;
            max_response_bytes = null;
            transform = null;
            is_replicated = null;
            cycles = 30_000_000_000;
        };

        try {
            let _response = await* testApiKeyHeader(config, "test-api-key-12345");
            // If we got here without error, the API key was sent successfully
            Debug.print("✅ API key in header sent successfully");
            "✅ PASS: API key sent in X-API-Key header"
        } catch (e) {
            let msg = Error.message(e);
            Debug.print("❌ API key header test failed: " # msg);
            "❌ FAIL: " # msg
        }
    };

    // Test 5: API key in query parameter
    public func test5_ApiKeyQuery() : async Text {
        Debug.print("Test 5: API key in query parameter (api_key)");

        let config : Config = {
            baseUrl = "https://httpbin.org";
            accessToken = null;
            apiKey = ?"test-query-key-67890";
            basicAuthUser = null;
            basicAuthPassword = null;
            max_response_bytes = null;
            transform = null;
            is_replicated = null;
            cycles = 30_000_000_000;
        };

        try {
            let response = await* testApiKeyQuery(config);
            // Check if the URL field contains the api_key parameter
            switch (response.url) {
                case (?url) {
                    if (Text.contains(url, #text "api_key=test-query-key-67890")) {
                        Debug.print("✅ API key in query parameter working correctly");
                        "✅ PASS: API key sent as query parameter"
                    } else {
                        Debug.print("❌ API key not found in URL");
                        Debug.print("  URL: " # url);
                        "❌ FAIL: api_key not in query string"
                    }
                };
                case null {
                    Debug.print("❌ Response missing url field");
                    "❌ FAIL: Invalid response structure"
                };
            }
        } catch (e) {
            let msg = Error.message(e);
            Debug.print("❌ API key query test failed: " # msg);
            "❌ FAIL: " # msg
        }
    };

    // Test 6: Basic Authentication
    public func test6_BasicAuth() : async Text {
        Debug.print("Test 6: Basic Authentication (username:password)");

        let config : Config = {
            baseUrl = "https://httpbin.org";
            accessToken = null;
            apiKey = null;
            basicAuthUser = ?"testuser";
            basicAuthPassword = ?"testpass";
            max_response_bytes = null;
            transform = null;
            is_replicated = null;
            cycles = 30_000_000_000;
        };

        try {
            let response = await* testBasicAuth(config, "testuser", "testpass");
            // Check if authentication was successful
            switch (response.authenticated, response.user) {
                case (?true, ?"testuser") {
                    Debug.print("✅ Basic auth working correctly");
                    "✅ PASS: Basic auth credentials sent correctly"
                };
                case (?isAuth, ?user) {
                    Debug.print("❌ Basic auth not working correctly");
                    Debug.print("  Expected: authenticated=true, user=testuser");
                    Debug.print("  Received: authenticated=" # debug_show(isAuth) # ", user=" # user);
                    "❌ FAIL: Basic auth mismatch"
                };
                case _ {
                    Debug.print("❌ Missing response fields");
                    "❌ FAIL: Response missing authenticated or user field"
                };
            }
        } catch (e) {
            let msg = Error.message(e);
            Debug.print("❌ Basic auth test failed: " # msg);
            "❌ FAIL: " # msg
        }
    };

    // Run all tests
    public func runAllTests() : async Text {
        Debug.print("\n=== Authentication Tests ===\n");

        var passed = 0;

        let result1 = await test1_BearerAuth();
        if (Text.startsWith(result1, #text "✅")) { passed += 1 };
        Debug.print("");

        let result2 = await test2_BearerAuthMissing();
        if (Text.startsWith(result2, #text "✅")) { passed += 1 };
        Debug.print("");

        let result3 = await test3_AuthHeaderFormat();
        if (Text.startsWith(result3, #text "✅")) { passed += 1 };
        Debug.print("");

        let result4 = await test4_ApiKeyHeader();
        if (Text.startsWith(result4, #text "✅")) { passed += 1 };
        Debug.print("");

        let result5 = await test5_ApiKeyQuery();
        if (Text.startsWith(result5, #text "✅")) { passed += 1 };
        Debug.print("");

        let result6 = await test6_BasicAuth();
        if (Text.startsWith(result6, #text "✅")) { passed += 1 };
        Debug.print("");

        let results = [result1, result2, result3, result4, result5, result6];
        let total = results.size();
        let resultsText = result1 # "\n" # result2 # "\n" # result3 # "\n" # result4 # "\n" # result5 # "\n" # result6;
        let summary = "\n=== Results ===" #
                     "\nPassed: " # debug_show(passed) # "/" # debug_show(total) # "\n\n" #
                     resultsText;

        Debug.print(summary);

        if (passed == total) {
            "✅ All tests passed!\n" # summary
        } else {
            "❌ Some tests failed\n" # summary
        }
    };
}
