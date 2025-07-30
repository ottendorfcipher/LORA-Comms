pub mod device;
pub mod protocol;
pub mod bridge;

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tokio::sync::mpsc;
use uuid::Uuid;
use chrono::{DateTime, Utc};

pub use device::*;
pub use protocol::*;
pub use bridge::*;

/// Main error type for the library
#[derive(Debug, thiserror::Error)]
pub enum LoraCommsError {
    #[error("Device error: {0}")]
    Device(#[from] DeviceError),
    #[error("Protocol error: {0}")]
    Protocol(#[from] ProtocolError),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
    #[error("Connection error: {message}")]
    Connection { message: String },
    #[error("Timeout error")]
    Timeout,
}

pub type Result<T> = std::result::Result<T, LoraCommsError>;

/// Core communication manager
pub struct LoraCommsManager {
    devices: Arc<Mutex<HashMap<String, Box<dyn Device + Send + Sync>>>>,
    message_sender: Option<mpsc::UnboundedSender<MeshMessage>>,
    message_receiver: Option<mpsc::UnboundedReceiver<MeshMessage>>,
}

impl LoraCommsManager {
    pub fn new() -> Self {
        let (tx, rx) = mpsc::unbounded_channel();
        
        Self {
            devices: Arc::new(Mutex::new(HashMap::new())),
            message_sender: Some(tx),
            message_receiver: Some(rx),
        }
    }

    pub async fn scan_devices(&self) -> Result<Vec<DeviceInfo>> {
        let mut all_devices = Vec::new();
        
        // Scan serial devices
        #[cfg(feature = "serial")]
        {
            let serial_devices = device::serial::scan_serial_devices().await?;
            all_devices.extend(serial_devices);
        }

        // Scan Bluetooth devices
        #[cfg(feature = "bluetooth")]
        {
            let bluetooth_devices = device::bluetooth::scan_bluetooth_devices().await?;
            all_devices.extend(bluetooth_devices);
        }

        // Scan TCP devices
        #[cfg(feature = "tcp")]
        {
            let tcp_devices = device::tcp::scan_tcp_devices().await?;
            all_devices.extend(tcp_devices);
        }

        Ok(all_devices)
    }

    pub async fn connect_device(&mut self, device_info: &DeviceInfo) -> Result<String> {
        let device_id = Uuid::new_v4().to_string();
        
        let device: Box<dyn Device + Send + Sync> = match device_info.device_type {
            #[cfg(feature = "serial")]
            DeviceType::Serial => {
                Box::new(device::serial::SerialDevice::new(&device_info.path).await?)
            },
            #[cfg(feature = "bluetooth")]
            DeviceType::Bluetooth => {
                return Err(LoraCommsError::Connection { 
                    message: "Bluetooth not yet implemented".to_string() 
                })
            },
            #[cfg(feature = "tcp")]
            DeviceType::Tcp => {
                return Err(LoraCommsError::Connection { 
                    message: "TCP not yet implemented".to_string() 
                })
            },
            #[cfg(not(feature = "bluetooth"))]
            DeviceType::Bluetooth => {
                return Err(LoraCommsError::Connection { 
                    message: "Bluetooth feature not enabled".to_string() 
                })
            },
            #[cfg(not(feature = "tcp"))]
            DeviceType::Tcp => {
                return Err(LoraCommsError::Connection { 
                    message: "TCP feature not enabled".to_string() 
                })
            },
        };

        self.devices.lock().unwrap().insert(device_id.clone(), device);
        Ok(device_id)
    }

    pub async fn disconnect_device(&mut self, device_id: &str) -> Result<()> {
        self.devices.lock().unwrap().remove(device_id);
        Ok(())
    }

    pub async fn send_message(&self, device_id: &str, message: &str, destination: Option<&str>) -> Result<()> {
        let devices = self.devices.lock().unwrap();
        let device = devices.get(device_id)
            .ok_or_else(|| LoraCommsError::Connection { 
                message: "Device not found".to_string() 
            })?;

        let mesh_message = MeshMessage {
            id: Uuid::new_v4().to_string(),
            text: message.to_string(),
            sender: "local".to_string(),
            destination: destination.map(|s| s.to_string()),
            timestamp: Utc::now(),
            is_from_me: true,
        };

        device.send_message(&mesh_message).await?;
        Ok(())
    }

    pub async fn get_nodes(&self, device_id: &str) -> Result<Vec<NodeInfo>> {
        let devices = self.devices.lock().unwrap();
        let device = devices.get(device_id)
            .ok_or_else(|| LoraCommsError::Connection { 
                message: "Device not found".to_string() 
            })?;

        device.get_nodes().await.map_err(LoraCommsError::from)
    }

    pub fn get_message_receiver(&mut self) -> Option<mpsc::UnboundedReceiver<MeshMessage>> {
        self.message_receiver.take()
    }
}

impl Default for LoraCommsManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_manager_creation() {
        let manager = LoraCommsManager::new();
        assert!(manager.devices.lock().unwrap().is_empty());
    }

    #[tokio::test]
    async fn test_device_scanning() {
        let manager = LoraCommsManager::new();
        let devices = manager.scan_devices().await.unwrap();
        println!("Found {} devices:", devices.len());
        for device in &devices {
            println!("  - {} ({:?}): {}", device.name, device.device_type, device.path);
        }
    }
}
