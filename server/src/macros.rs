/// Handles the given `Result` value by
/// logging the error with given message
/// or returning the inner value.
#[macro_export]
macro_rules! fallable {
    ($call:expr) => {{
        match $call {
            Err(err) => {
                tracing::error!("{err}");

                anyhow::bail!(err);
            }
            Ok(data) => data,
        }
    }};
    ($call:expr, $err_msg:expr) => {{
        match $call {
            Err(err) => {
                tracing::error!("{}\nError: {err}", $err_msg);

                anyhow::bail!(err);
            }
            Ok(data) => data,
        }
    }};
}
