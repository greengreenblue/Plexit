using Toybox.Communications;

module Plexit {
	
	class Error {
		static enum {
			HTTP,
			API,
		}

		// map errors to string representation
		static private var stringmap = {
			HTTP => "HTTP",
			API => "API",
		};

		static private var s_name = "Error";
		private var d_type;
		
		function initialize(type) {
			d_type = type;
		}
		
		function type() {
			return d_type;
		}
		
		function shortString() {
			return s_name + " " + Error.typeToString(d_type);
	    }
	    
	    function toString() {
	    	return s_name + " " + Error.typeToString(d_type);
	    }

		static function typeToString(type) {
			var string = stringmap.get(type);
			if (string == null) {
				string = "Unknown";
			}
			return string;
		}
	}
	
	class ApiError extends Error {
		
		static enum {
			LOGIN,
			ACCESS,
			NOTFOUND,
			SERVERCLIENT,
			BADREQUEST,
			BADRESPONSE,
			UNKNOWN,
		}

		// map errors to string representation
		static private var stringmap = {
			LOGIN 			=> "LOGIN",
	    	ACCESS 			=> "ACCESS",
	    	NOTFOUND 		=> "NOTFOUND",
	    	SERVERCLIENT 	=> "SERVERCLIENT",
	    	BADREQUEST 		=> "BADREQUEST",
	    	BADRESPONSE 	=> "BADRESPONSE",
	    	UNKNOWN 		=> "UNKNOWN",
		};
		private var d_type;
		static private var s_name = "ApiError";
		
		function initialize(type) {
			Error.initialize(Error.API);

			d_type = type;
		}
		
		function shortString() {
	    	return s_name + "::" + ApiError.typeToString(d_type);
	    }

		function toString() {
			return Plexit.Error.toString() + 
					" --> " + 
					s_name + "::" + ApiError.typeToString(d_type);
		}
	    
	    function type() {
	    	return d_type;
	    }

		function api_type() {
			return ApiError.type();
		}
	    
	    static function typeToString(type) {
			var string = stringmap.get(type);
			if (string == null) {
				string = "Unknown";
			}
			return string;
	    }
	}
	
	class HttpError extends Error {
		
		static enum {
			BAD_REQUEST = 400,
			UNAUTHORIZED = 401,
			FORBIDDEN = 403,
			NOT_FOUND = 404,
		}

		// map errors to string representation
		static private var stringmap = {
			BAD_REQUEST => "Bad Request",
			UNAUTHORIZED => "Unauthorized",
			FORBIDDEN => "Forbidden",
			NOT_FOUND => "Not Found",
		};

		private var d_type;
		static private var s_name = "HttpError";
		
		function initialize(type) {
			Error.initialize(Error.HTTP);
			d_type = type;
		}

		function http_type() {
			return d_type;
		}
		
		static function is(responseCode) {
		
			// only error if > 0 but not 200
			if ((responseCode == 200)
				|| (responseCode <= 0)) {
				return null;
			}
			return new HttpError(responseCode);
		}
		
		function shortString() {
			return s_name + "::" + d_type.toString();
		}

		function toString() {
			return Error.toString() +
					" --> " + 
					s_name + "::" + HttpError.typeToString(d_type);
		}
		
		static function typeToString(type) {
			var string = stringmap.get(type);
			if (string == null) {
				string = "Unknown";
			}
			return string;
		}
	}
	
	class GarminSdkError extends Error {
	
		// enum for possible errors can be found in module Communications

		// map errors to string representation
		static private var stringmap = {
			Communications.UNKNOWN_ERROR 									=> "UNKNOWN_ERROR",
	    	Communications.BLE_ERROR 										=> "BLE_ERROR",
	    	Communications.BLE_HOST_TIMEOUT 								=> "BLE_HOST_TIMEOUT",
	    	Communications.BLE_SERVER_TIMEOUT 								=> "BLE_SERVER_TIMEOUT",
	    	Communications.BLE_NO_DATA 										=> "BLE_NO_DATA",
	    	Communications.BLE_REQUEST_CANCELLED 							=> "BLE_REQUEST_CANCELLED",
	    	Communications.BLE_QUEUE_FULL 									=> "BLE_QUEUE_FULL",
	    	Communications.BLE_REQUEST_TOO_LARGE 							=> "BLE_REQUEST_TOO_LARGE",
	    	Communications.BLE_UNKNOWN_SEND_ERROR 							=> "BLE_UNKNOWN_SEND_ERROR",
	    	Communications.BLE_CONNECTION_UNAVAILABLE 						=> "BLE_CONNECTION_UNAVAILABLE",
	    	Communications.INVALID_HTTP_HEADER_FIELDS_IN_REQUEST 			=> "INVALID_HTTP_HEADER_FIELDS_IN_REQUEST",
	    	Communications.INVALID_HTTP_BODY_IN_REQUEST 					=> "INVALID_HTTP_BODY_IN_REQUEST",
	    	Communications.INVALID_HTTP_METHOD_IN_REQUEST 					=> "INVALID_HTTP_METHOD_IN_REQUEST",
	    	Communications.NETWORK_REQUEST_TIMED_OUT 						=> "NETWORK_REQUEST_TIMED_OUT",
	    	Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE 			=> "INVALID_HTTP_BODY_IN_NETWORK_RESPONSE",
	    	Communications.INVALID_HTTP_HEADER_FIELDS_IN_NETWORK_RESPONSE	=> "INVALID_HTTP_HEADER_FIELDS_IN_NETWORK_RESPONSE",
	    	Communications.NETWORK_RESPONSE_TOO_LARGE 						=> "NETWORK_RESPONSE_TOO_LARGE",
	    	Communications.NETWORK_RESPONSE_OUT_OF_MEMORY 					=> "NETWORK_RESPONSE_OUT_OF_MEMORY",
	    	Communications.STORAGE_FULL 									=> "STORAGE_FULL",
	    	Communications.SECURE_CONNECTION_REQUIRED 						=> "SECURE_CONNECTION_REQUIRED",
	    	Communications.UNSUPPORTED_CONTENT_TYPE_IN_RESPONSE 			=> "UNSUPPORTED_CONTENT_TYPE_IN_RESPONSE",
	    	Communications.REQUEST_CANCELLED 								=> "REQUEST_CANCELLED",
	    	Communications.REQUEST_CONNECTION_DROPPED 						=> "REQUEST_CONNECTION_DROPPED",
	    	Communications.UNABLE_TO_PROCESS_MEDIA 							=> "UNABLE_TO_PROCESS_MEDIA",
	    	Communications.UNABLE_TO_PROCESS_IMAGE 							=> "UNABLE_TO_PROCESS_IMAGE",
	    	Communications.UNABLE_TO_PROCESS_HLS 							=> "UNABLE_TO_PROCESS_HLS",
		};
		private var d_responseCode;
		static private var s_name = "GarminSdkError";

		function initialize(responseCode) {
			Error.initialize(Error.HTTP);
			d_responseCode = responseCode;
		}
	
		static function is(responseCode) {
		
			// Sdk errors are always smaller or equal to zero
			if (responseCode > 0) {
				return null;
			}
			
			return new GarminSdkError(responseCode);
		}
		
		function respCode() {
			return d_responseCode;
		}
		
		function shortString() {
			return s_name + "::" + d_responseCode.toString();
		}
		
		function toString() {
			return Error.toString() + 
					" --> " + 
					s_name + "::" + GarminSdkError.respCodeToString(d_responseCode);
		}
	
		// move to somewhere else later, but now this is one of the two places this is used
	    static function respCodeToString(responseCode) {
			var string = stringmap.get(responseCode);
			if (string == null) {
				string = "Unknown";
			}
			return string;
	    }
	}
}
