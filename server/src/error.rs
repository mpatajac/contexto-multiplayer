pub struct ErrorResponse(axum::http::StatusCode, String);

impl axum::response::IntoResponse for ErrorResponse {
    fn into_response(self) -> axum::response::Response {
        (self.0, self.1).into_response()
    }
}

macro_rules! generate_error_response_impl {
    ($name:ident, $code:ident) => {
        pub fn $name<S>(msg: S) -> Self
        where
            S: Into<String>,
        {
            Self(axum::http::StatusCode::$code, msg.into())
        }
    };
}

impl ErrorResponse {
    // generate_error_response_impl!(bad_request, BAD_REQUEST);
    generate_error_response_impl!(not_found, NOT_FOUND);
    generate_error_response_impl!(_internal_server_error, INTERNAL_SERVER_ERROR);

    pub fn internal_server_error() -> Self {
        Self::_internal_server_error("Oops... there was an error!")
    }
}
