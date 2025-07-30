pub mod serial;
#[cfg(feature = "bluetooth")]
pub mod bluetooth;
#[cfg(feature = "tcp")]
pub mod tcp;

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use crate::protocol::{MeshMessage, NodeInfo};

#[derive(Debug, thiserror::Error)]
pub enum DeviceError {
    #[error("Connection failed: {message}")]
    ConnectionFailed { message: String },
    #[error("Device not found")]
    NotFound,
    #[error("Permission denied")]
    PermissionDenied,
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Timeout")]
    Timeout,
    #[error("Invalid response")]
    InvalidResponse,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceType {
    Serial,
    Bluetooth,
    Tcp,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceInfo {
    pub id: String,
    pub name: String,
    pub path: String,
    pub device_type: DeviceType,
    pub manufacturer: Option<String>,
    pub vendor_id: Option<String>,
    pub product_id: Option<String>,
    pub is_available: bool,
}

impl DeviceInfo {
    pub fn new(
        id: String,
        name: String,
        path: String,
        device_type: DeviceType,
    ) -> Self {
        Self {
            id,
            name,
            path,
            device_type,
            manufacturer: None,
            vendor_id: None,
            product_id: None,
            is_available: true,
        }
    }

    pub fn with_manufacturer(mut self, manufacturer: String) -> Self {
        self.manufacturer = Some(manufacturer);
        self
    }

    pub fn with_vendor_id(mut self, vendor_id: String) -> Self {
        self.vendor_id = Some(vendor_id);
        self
    }

    pub fn with_product_id(mut self, product_id: String) -> Self {
        self.product_id = Some(product_id);
        self
    }
}

/// Trait for all device types that can communicate with Meshtastic devices
#[async_trait]
pub trait Device {
    /// Connect to the device
    async fn connect(&mut self) -> Result<(), DeviceError>;
    
    /// Disconnect from the device
    async fn disconnect(&mut self) -> Result<(), DeviceError>;
    
    /// Check if the device is connected
    fn is_connected(&self) -> bool;
    
    /// Send a message through the device
    async fn send_message(&self, message: &MeshMessage) -> Result<(), DeviceError>;
    
    /// Get the list of nodes visible to this device
    async fn get_nodes(&self) -> Result<Vec<NodeInfo>, DeviceError>;
    
    /// Get device information
    async fn get_device_info(&self) -> Result<String, DeviceError>;
    
    /// Start listening for incoming messages
    async fn start_listening(&mut self) -> Result<(), DeviceError>;
    
    /// Stop listening for incoming messages
    async fn stop_listening(&mut self) -> Result<(), DeviceError>;
}

/// Connection status for a device
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConnectionStatus {
    Disconnected,
    Connecting,
    Connected,
    Error(String),
}

/// Device connection state
#[derive(Debug, Clone)]
pub struct DeviceConnection {
    pub device_info: DeviceInfo,
    pub status: ConnectionStatus,
    pub connected_at: Option<DateTime<Utc>>,
    pub last_activity: Option<DateTime<Utc>>,
}

impl DeviceConnection {
    pub fn new(device_info: DeviceInfo) -> Self {
        Self {
            device_info,
            status: ConnectionStatus::Disconnected,
            connected_at: None,
            last_activity: None,
        }
    }

    pub fn set_connected(&mut self) {
        self.status = ConnectionStatus::Connected;
        self.connected_at = Some(Utc::now());
        self.last_activity = Some(Utc::now());
    }

    pub fn set_disconnected(&mut self) {
        self.status = ConnectionStatus::Disconnected;
        self.connected_at = None;
    }

    pub fn set_error(&mut self, error: String) {
        self.status = ConnectionStatus::Error(error);
    }

    pub fn update_activity(&mut self) {
        self.last_activity = Some(Utc::now());
    }
}
