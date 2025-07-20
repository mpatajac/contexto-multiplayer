mod api;
mod config;
mod data;
mod error;
mod game;
mod macros;
mod router;
mod sse;

use std::{net::SocketAddr, sync::Arc};

use config::CONFIG;
use data::AppState;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    init_tracing();

    tracing::info!("Initializing server state...");

    let app_state = fallable! { AppState::init() };
    let dist_root = std::path::PathBuf::from(CONFIG.dist_root_path.clone());

    let app = router::router(app_state.clone(), &dist_root);

    let port = std::env::var("PORT")
        .ok()
        .and_then(|raw_port| raw_port.parse().ok())
        .unwrap_or(3000);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = fallable! {
        tokio::net::TcpListener::bind(addr).await,
        "Failed to create a TcpListener."
    };

    tracing::info!("Starting server on `{addr}`...");

    fallable! {
        axum::serve(listener, app.into_make_service_with_connect_info::<SocketAddr>())
            .with_graceful_shutdown(shutdown_signal(app_state))
            .await
    };

    // TODO!: clean-up job

    Ok(())
}

/// Initialize tracing configuration
fn init_tracing() {
    // TODO: replace with proper tracing (e.g. write logs in a file or a db)
    tracing_subscriber::fmt()
        .pretty()
        .with_target(false)
        .with_file(false)
        .with_line_number(false)
        .with_max_level(tracing::Level::DEBUG)
        .init();
}

/// Handle Ctrl+c signal for server graceful shutdown
async fn shutdown_signal(app_state: Arc<AppState>) {
    // TODO: check do we (and do we need to) handle "os termination"
    // (e.g. when stopping a deployed instance)
    tokio::signal::ctrl_c()
        .await
        .expect("shutdown signal should be properly handled");

    // NOTE: keep this in a block to try and release the `Mutex` lock ASAP
    // (don't know if this actually makes any difference)
    {
        // send a `Shutdown` message to all clients
        app_state.sse.lock().await.shutdown();
    }

    tracing::error!("Received shutdown signal - stopping server...");
}
