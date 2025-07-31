use super::{Device, DeviceError, DeviceInfo, DeviceType};
use crate::protocol::{MeshMessage, NodeInfo, ProtocolHandler, MeshPacket, decode_packet, encode_packet, extract_frame_from_buffer};
use crate::radio::RadioConfig;
use async_trait::async_trait;
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio_serial::{SerialPortBuilderExt, SerialStream};
use tokio::sync::mpsc;
use tokio::time::{timeout, sleep};
use bytes::BytesMut;
use crc::{Crc, CRC_16_IBM_3740};
use std::sync::Arc;
use tokio::sync::Mutex;

pub struct SerialDevice {
    path: String,
    port: Option<Arc<Mutex<SerialStream>>>,
    is_connected: bool,
    protocol_handler: ProtocolHandler,
    message_tx: Option<mpsc::UnboundedSender<MeshPacket>>,
    config_id: u32,
    my_node_num: u32,
    buffer: BytesMut,
}

impl SerialDevice {
    pub async fn new(path: &str) -> Result<Self, DeviceError> {
        Ok(Self {
            path: path.to_string(),
            port: None,
            is_connected: false,
            protocol_handler: ProtocolHandler::new(),
            message_tx: None,
            config_id: rand::random(),
            my_node_num: 0,
            buffer: BytesMut::new(),
        })
    }

    /// Send a protobuf message with proper framing
    async fn send_protobuf_message(&self, packet: &MeshPacket) -> Result<(), DeviceError> {
        if let Some(port) = &self.port {
            let encoded = encode_packet(packet).map_err(|e| DeviceError::ConnectionFailed {
                message: format!("Failed to encode packet: {}", e),
            })?;
            
            // Meshtastic serial protocol uses HDLC-like framing
            let framed = self.frame_message(&encoded);
            
            let mut port_guard = port.lock().await;
            port_guard.write_all(&framed).await.map_err(|e| DeviceError::ConnectionFailed {
                message: format!("Failed to write to serial port: {}", e),
            })?;
            port_guard.flush().await.map_err(|e| DeviceError::ConnectionFailed {
                message: format!("Failed to flush serial port: {}", e),
            })?;
            
            Ok(())
        } else {
            Err(DeviceError::ConnectionFailed {
                message: "Device not connected".to_string(),
            })
        }
    }
    
    /// Frame a message using HDLC-like framing for Meshtastic serial protocol
    fn frame_message(&self, data: &[u8]) -> Vec<u8> {
        const FRAME_START: u8 = 0x94;
        const FRAME_END: u8 = 0x7E;
        const ESCAPE: u8 = 0x7D;
        const ESCAPE_XOR: u8 = 0x20;
        
        let mut framed = Vec::new();
        framed.push(FRAME_START);
        
        // Calculate CRC16
        let crc = Crc::<u16>::new(&CRC_16_IBM_3740);
        let checksum = crc.checksum(data);
        
        // Escape and add data
        for &byte in data {
            if byte == FRAME_START || byte == FRAME_END || byte == ESCAPE {
                framed.push(ESCAPE);
                framed.push(byte ^ ESCAPE_XOR);
            } else {
                framed.push(byte);
            }
        }
        
        // Add CRC (little endian)
        let crc_bytes = checksum.to_le_bytes();
        for &byte in &crc_bytes {
            if byte == FRAME_START || byte == FRAME_END || byte == ESCAPE {
                framed.push(ESCAPE);
                framed.push(byte ^ ESCAPE_XOR);
            } else {
                framed.push(byte);
            }
        }
        
        framed.push(FRAME_END);
        framed
    }
    
    /// Process incoming serial data and extract complete frames
    async fn process_incoming_data(&mut self, new_data: &[u8]) -> Result<Vec<MeshPacket>, DeviceError> {
        self.buffer.extend_from_slice(new_data);
        let mut packets = Vec::new();
        
        while let Some(frame) = self.extract_frame() {
            if let Ok(packet) = decode_packet(&frame) {
                packets.push(packet);
            }
        }
        
        Ok(packets)
    }
    
    /// Extract a complete frame from the buffer
    fn extract_frame(&mut self) -> Option<Vec<u8>> {
        const FRAME_START: u8 = 0x94;
        const FRAME_END: u8 = 0x7E;
        const ESCAPE: u8 = 0x7D;
        const ESCAPE_XOR: u8 = 0x20;
        
        // Find frame boundaries
        let start_pos = self.buffer.iter().position(|&b| b == FRAME_START)?;
        let end_pos = self.buffer[start_pos + 1..].iter().position(|&b| b == FRAME_END)? + start_pos + 1;
        
        // Extract and remove the frame from buffer
        let frame_data = self.buffer[start_pos + 1..end_pos].to_vec();
        self.buffer = self.buffer.split_off(end_pos + 1);
        
        // Unescape the frame
        let mut unescaped = Vec::new();
        let mut i = 0;
        while i < frame_data.len() {
            if frame_data[i] == ESCAPE && i + 1 < frame_data.len() {
                unescaped.push(frame_data[i + 1] ^ ESCAPE_XOR);
                i += 2;
            } else {
                unescaped.push(frame_data[i]);
                i += 1;
            }
        }
        
        // Verify CRC and return payload (without CRC)
        if unescaped.len() >= 2 {
            let payload_len = unescaped.len() - 2;
            let payload = &unescaped[..payload_len];
            let received_crc = u16::from_le_bytes([unescaped[payload_len], unescaped[payload_len + 1]]);
            
            let crc = Crc::<u16>::new(&CRC_16_IBM_3740);
            let calculated_crc = crc.checksum(payload);
            
            if received_crc == calculated_crc {
                Some(payload.to_vec())
            } else {
                eprintln!("CRC mismatch: received {:04x}, calculated {:04x}", received_crc, calculated_crc);
                None
            }
        } else {
            None
        }
    }
    
    /// Configure device settings
    pub async fn configure_radio(&self, config: &RadioConfig) -> Result<(), DeviceError> {
        let config_packet = MeshPacket {
            from: self.my_node_num,
            to: self.my_node_num, // Send to self for configuration
            id: self.config_id,
            payload: Some(crate::protocol::PayloadVariant::Admin(config.to_admin_message())),
            hop_limit: 3,
            want_ack: true,
            priority: crate::protocol::MeshPacket_Priority::RELIABLE,
            rx_time: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs() as u32,
            ..Default::default()
        };
        
        self.send_protobuf_message(&config_packet).await
    }

    async fn write_command(&mut self, command: &str) -> Result<(), DeviceError> {
        if let Some(port) = &self.port {
            let command_bytes = format!("{}\n", command).into_bytes();
            let mut port_guard = port.lock().await;
            port_guard.write_all(&command_bytes).await?;
            port_guard.flush().await?;
            Ok(())
        } else {
            Err(DeviceError::ConnectionFailed {
                message: "Device not connected".to_string(),
            })
        }
    }

    async fn read_response(&mut self) -> Result<String, DeviceError> {
        if let Some(port) = &self.port {
            let mut buffer = vec![0; 1024];
            let mut port_guard = port.lock().await;
            let n = port_guard.read(&mut buffer).await?;
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
        // Try different baud rates commonly used by Meshtastic devices
        let baud_rates = [115200, 921600, 57600, 38400, 19200];
        let mut last_error = None;
        
        for &baud_rate in &baud_rates {
            println!("[DEBUG] Trying to connect at {} baud", baud_rate);
            
            match tokio_serial::new(&self.path, baud_rate)
                .timeout(Duration::from_secs(2))
                .open_native_async()
            {
                Ok(port) => {
                    self.port = Some(Arc::new(Mutex::new(port)));
                    self.is_connected = true;
                    
                    // Test connection by checking if we can communicate
                    if self.is_connected() {
                        println!("[DEBUG] Successfully connected at {} baud", baud_rate);
                        return Ok(());
                    } else {
                        self.disconnect().await?;
                    }
                }
                Err(e) => {
                    last_error = Some(e);
                    continue;
                }
            }
        }
        
        Err(DeviceError::ConnectionFailed {
            message: format!("Failed to connect at any baud rate: {:?}", last_error),
        })
    }
    

    async fn disconnect(&mut self) -> Result<(), DeviceError> {
        if let Some(port) = self.port.take() {
            drop(port);
        }
        self.is_connected = false;
        self.message_tx = None;
        self.buffer.clear();
        Ok(())
    }

    fn is_connected(&self) -> bool {
        self.is_connected
    }

    async fn send_message(&self, message: &MeshMessage) -> Result<(), DeviceError> {
        let mesh_packet = MeshPacket {
            from: self.my_node_num,
            to: if message.to == "broadcast" { 0xFFFFFFFF } else { 
                message.to.parse().unwrap_or(0xFFFFFFFF) 
            },
            id: rand::random(),
            payload: Some(crate::protocol::PayloadVariant::Text(message.text.clone())),
            hop_limit: 3,
            want_ack: message.want_ack.unwrap_or(false),
            priority: crate::protocol::MeshPacket_Priority::DEFAULT,
            rx_time: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs() as u32,
            ..Default::default()
        };
        
        self.send_protobuf_message(&mesh_packet).await
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
        if let Some(port) = &self.port {
            let (tx, mut rx) = mpsc::unbounded_channel();
            self.message_tx = Some(tx);
            
            let port_clone = Arc::clone(port);
            let tx_clone = self.message_tx.as_ref().unwrap().clone();
            
            // Spawn background task to read from serial port
            tokio::spawn(async move {
                let mut buffer = [0u8; 1024];
                let mut frame_buffer = BytesMut::new();
                
                loop {
                    let mut port_guard = port_clone.lock().await;
                    match port_guard.read(&mut buffer).await {
                        Ok(n) if n > 0 => {
                            drop(port_guard); // Release lock before processing
                            
                            frame_buffer.extend_from_slice(&buffer[..n]);
                            
                            // Process complete frames
                            while let Some(frame) = extract_frame_from_buffer(&mut frame_buffer) {
                                if let Ok(packet) = decode_packet(&frame) {
                                    if tx_clone.send(packet).is_err() {
                                        break; // Channel closed, exit task
                                    }
                                }
                            }
                        }
                        Ok(_) => {
                            // No data read, continue
                            drop(port_guard);
                            sleep(Duration::from_millis(10)).await;
                        }
                        Err(e) => {
                            eprintln!("Serial read error: {}", e);
                            break;
                        }
                    }
                }
            });
            
            Ok(())
        } else {
            Err(DeviceError::ConnectionFailed {
                message: "Device not connected".to_string(),
            })
        }
    }

    async fn stop_listening(&mut self) -> Result<(), DeviceError> {
        self.message_tx = None;
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
