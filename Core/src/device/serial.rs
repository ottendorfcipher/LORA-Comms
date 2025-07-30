use super::{Device, DeviceError, DeviceInfo, DeviceType};
use crate::protocol::{MeshMessage, NodeInfo, ProtocolHandler};
use async_trait::async_trait;
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio_serial::{SerialPortBuilderExt, SerialStream};

pub struct SerialDevice {
    path: String,
    port: Option<SerialStream>,
    is_connected: bool,
    protocol_handler: ProtocolHandler,
}

impl SerialDevice {
    pub async fn new(path: &str) -> Result<Self, DeviceError> {
        Ok(Self {
            path: path.to_string(),
            port: None,
            is_connected: false,
            protocol_handler: ProtocolHandler::new(),
        })
    }

    async fn write_command(&mut self, command: &str) -> Result<(), DeviceError> {
        if let Some(ref mut port) = self.port {
            let command_bytes = format!("{}\n", command).into_bytes();
            port.write_all(&command_bytes).await?;
            port.flush().await?;
            Ok(())
        } else {
            Err(DeviceError::ConnectionFailed {
                message: "Device not connected".to_string(),
            })
        }
    }

    async fn read_response(&mut self) -> Result<String, DeviceError> {
        if let Some(ref mut port) = self.port {
            let mut buffer = vec![0; 1024];
            let n = port.read(&mut buffer).await?;
            let response = String::from_utf8_lossy(&buffer[..n]).to_string();
            Ok(response)
        } else {
            Err(DeviceError::ConnectionFailed {
                message: "Device not connected".to_string(),
            })
        }
    }
}

#[async_trait]
impl Device for SerialDevice {
    async fn connect(&mut self) -> Result<(), DeviceError> {
        let port = tokio_serial::new(&self.path, 115200)
            .timeout(Duration::from_secs(5))
            .open_native_async()
            .map_err(|e| DeviceError::ConnectionFailed {
                message: format!("Failed to open serial port: {}", e),
            })?;

        self.port = Some(port);
        self.is_connected = true;

        // Test connection by getting device info
        match self.get_device_info().await {
            Ok(_) => Ok(()),
            Err(e) => {
                self.disconnect().await?;
                Err(e)
            }
        }
    }

    async fn disconnect(&mut self) -> Result<(), DeviceError> {
        if let Some(port) = self.port.take() {
            drop(port);
        }
        self.is_connected = false;
        Ok(())
    }

    fn is_connected(&self) -> bool {
        self.is_connected
    }

    async fn send_message(&self, message: &MeshMessage) -> Result<(), DeviceError> {
        // This would interface with the actual Meshtastic CLI or protocol
        // For now, simulate the command
        println!("Sending message: {}", message.text);
        
        // In a real implementation, this would:
        // 1. Format the message according to Meshtastic protocol
        // 2. Send it via the serial connection
        // 3. Wait for confirmation
        
        Ok(())
    }

    async fn get_nodes(&self) -> Result<Vec<NodeInfo>, DeviceError> {
        // This would query the device for node information
        // For now, return a mock node
        Ok(vec![NodeInfo {
            id: "broadcast".to_string(),
            name: "All Nodes".to_string(),
            short_name: "ALL".to_string(),
            is_online: true,
        }])
    }

    async fn get_device_info(&self) -> Result<String, DeviceError> {
        // This would query device information
        // For now, return basic info
        Ok(format!("Serial device connected on {}", self.path))
    }

    async fn start_listening(&mut self) -> Result<(), DeviceError> {
        // This would start a background task to listen for incoming messages
        // and forward them to the message channel
        Ok(())
    }

    async fn stop_listening(&mut self) -> Result<(), DeviceError> {
        // This would stop the listening task
        Ok(())
    }
}

/// Known Meshtastic device VID/PID combinations
const MESHTASTIC_DEVICE_IDS: &[(u16, u16)] = &[
    // Common ESP32 development boards used with Meshtastic
    (0x10c4, 0xea60), // Silicon Labs CP210x UART Bridge
    (0x1a86, 0x7523), // CH340 serial converter  
    (0x0403, 0x6001), // FTDI FT232R
    (0x0403, 0x6010), // FTDI FT2232C/D/H Dual UART/FIFO IC
    (0x0403, 0x6011), // FTDI FT4232H Quad HS USB-UART/FIFO IC
    (0x0403, 0x6014), // FTDI FT232H Single HS USB-UART/FIFO IC  
    (0x0403, 0x6015), // FTDI FT X-Series
    (0x239a, 0x80f2), // Adafruit Feather ESP32-S2
    (0x239a, 0x8014), // Adafruit ESP32-S2
    (0x303a, 0x1001), // Espressif ESP32-S2
    (0x303a, 0x0002), // Espressif ESP32-S3
    // Heltec and TTGO boards commonly used for LoRa
    (0x10c4, 0xea60), // Heltec WiFi LoRa 32
    (0x1a86, 0x55d4), // TTGO LoRa32
];

/// Scan for available serial devices that might be Meshtastic devices
pub async fn scan_serial_devices() -> Result<Vec<DeviceInfo>, DeviceError> {
    println!("[DEBUG] Starting serial device scan...");
    let ports = tokio_serial::available_ports()
        .map_err(|e| DeviceError::ConnectionFailed { 
            message: format!("Serial port error: {}", e) 
        })?;

    println!("[DEBUG] Found {} total serial ports", ports.len());
    let mut devices = Vec::new();
    
    for port in ports {
        println!("[DEBUG] Checking port: {}", port.port_name);
        
        let is_likely_meshtastic = match &port.port_type {
            tokio_serial::SerialPortType::UsbPort(usb_info) => {
                println!("[DEBUG] USB device: VID={:04x}, PID={:04x}, Product={:?}, Manufacturer={:?}", 
                    usb_info.vid, usb_info.pid, usb_info.product, usb_info.manufacturer);
                
                // Check if this device matches known Meshtastic VID/PID combinations
                let is_known_device = MESHTASTIC_DEVICE_IDS.iter()
                    .any(|(vid, pid)| *vid == usb_info.vid && *pid == usb_info.pid);
                
                // Also accept devices with Meshtastic-related product names
                let has_meshtastic_name = usb_info.product.as_ref()
                    .map(|p| p.to_lowercase().contains("meshtastic") || 
                             p.to_lowercase().contains("lora") ||
                             p.to_lowercase().contains("heltec") ||
                             p.to_lowercase().contains("ttgo"))
                    .unwrap_or(false);
                
                // For debugging, also accept any USB serial device temporarily
                // TODO: Remove this once we've identified the exact VID/PID of your device
                let is_generic_usb_serial = port.port_name.contains("usbserial");
                
                if is_known_device {
                    println!("[DEBUG] Device matches known Meshtastic VID/PID");
                } else if has_meshtastic_name {
                    println!("[DEBUG] Device has Meshtastic-related product name");
                } else if is_generic_usb_serial {
                    println!("[DEBUG] Generic USB serial device (debugging mode)");
                }
                
                is_known_device || has_meshtastic_name || is_generic_usb_serial
            }
            _ => {
                println!("[DEBUG] Non-USB device, checking name patterns");
                // Check if the port name contains common patterns
                let matches_pattern = port.port_name.contains("usbserial") ||
                    port.port_name.contains("ttyUSB") ||
                    port.port_name.contains("ttyACM") ||
                    port.port_name.contains("cu.usbserial") ||
                    port.port_name.contains("cu.wchusbserial");
                
                if matches_pattern {
                    println!("[DEBUG] Port name matches expected pattern");
                }
                matches_pattern
            }
        };

        if is_likely_meshtastic {
            let device_info = match &port.port_type {
                tokio_serial::SerialPortType::UsbPort(usb_info) => {
                    DeviceInfo::new(
                        port.port_name.clone(),
                        usb_info.product.clone().unwrap_or_else(|| port.port_name.clone()),
                        port.port_name.clone(),
                        DeviceType::Serial,
                    )
                    .with_manufacturer(usb_info.manufacturer.clone().unwrap_or_else(|| "Unknown".to_string()))
                    .with_vendor_id(format!("{:04x}", usb_info.vid))
                    .with_product_id(format!("{:04x}", usb_info.pid))
                }
                _ => DeviceInfo::new(
                    port.port_name.clone(),
                    port.port_name.clone(),
                    port.port_name.clone(),
                    DeviceType::Serial,
                ),
            };

            devices.push(device_info);
        }
    }

    Ok(devices)
}
