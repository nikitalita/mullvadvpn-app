use crate::{
    routing::{self, RouteManagerHandle},
    tunnel_state_machine::TunnelCommand,
};
use futures::{channel::mpsc::UnboundedSender, StreamExt};
use std::{
    net::{IpAddr, Ipv4Addr},
    sync::Weak,
};
use talpid_types::ErrorExt;

pub type Result<T> = std::result::Result<T, Error>;

#[derive(err_derive::Error, Debug)]
#[error(no_from)]
pub enum Error {
    #[error(display = "The route manager returned an error")]
    RouteManagerError(#[error(source)] routing::Error),
}

pub struct MonitorHandle {
    route_manager: RouteManagerHandle,
}

// Mullvad API's public IP address, correct at the time of writing, but any public IP address will
// work.
const PUBLIC_INTERNET_ADDRESS: IpAddr = IpAddr::V4(Ipv4Addr::new(193, 138, 218, 78));

impl MonitorHandle {
    pub async fn is_offline(&mut self) -> bool {
        match public_ip_unreachable(&self.route_manager).await {
            Ok(is_offline) => is_offline,
            Err(err) => {
                log::error!(
                    "Failed to verify offline state: {}. Presuming connectivity",
                    err
                );
                false
            }
        }
    }
}

pub async fn spawn_monitor(
    sender: Weak<UnboundedSender<TunnelCommand>>,
    route_manager: RouteManagerHandle,
) -> Result<MonitorHandle> {
    let mut is_offline = public_ip_unreachable(&route_manager).await?;

    let mut listener = route_manager
        .change_listener()
        .await
        .map_err(Error::RouteManagerError)?;

    let monitor_handle = MonitorHandle {
        route_manager: route_manager.clone(),
    };

    tokio::spawn(async move {
        while let Some(_event) = listener.next().await {
            match sender.upgrade() {
                Some(sender) => {
                    let new_offline_state = public_ip_unreachable(&route_manager)
                        .await
                        .unwrap_or_else(|err| {
                            log::error!(
                                "{}",
                                err.display_chain_with_msg("Failed to infer offline state")
                            );
                            false
                        });
                    if new_offline_state != is_offline {
                        is_offline = new_offline_state;
                        let _ = sender.unbounded_send(TunnelCommand::IsOffline(is_offline));
                    }
                }
                None => return,
            }
        }
    });

    Ok(monitor_handle)
}


async fn public_ip_unreachable(handle: &RouteManagerHandle) -> Result<bool> {
    Ok(handle
        .get_destination_route(PUBLIC_INTERNET_ADDRESS, true)
        .await
        .map_err(Error::RouteManagerError)?
        .is_none())
}
