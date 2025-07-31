use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;
use std::collections::HashMap;
use tokio::sync::{mpsc, RwLock};
use std::sync::Arc;

#[derive(Debug, thiserror::Error)]
pub enum ProtocolError {
    #[error("Invalid message format")]
    InvalidFormat,
    #[error("Unsupported message type")]
    UnsupportedType,
    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
    #[error("Encoding error: {0}")]
    Encoding(String),
    #[error("Decoding error: {0}")]
    Decoding(String),
    #[error("Protobuf error: {0}")]
    Protobuf(String),
    #[error("Invalid node ID")]
    InvalidNodeId,
}

/// Represents a message in the mesh network
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MeshMessage {
    pub from: String,
    pub to: String,
    pub text: String,
    pub timestamp: DateTime<Utc>,
    pub want_ack: Option<bool>,
    pub packet_id: Option<u32>,
    pub hop_limit: Option<u8>,
    pub channel: Option<u8>,
    pub message_type: MessageType,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MessageType {
    Text,
    Position,
    NodeInfo,
    Telemetry,
    Routing,
    Admin,
    Unknown,
}

impl MeshMessage {
    pub fn new_text(from: String, to: String, text: String) -> Self {
        Self {
            from,
            to,
            text,
            timestamp: Utc::now(),
            want_ack: Some(false),
            packet_id: Some(rand::random()),
            hop_limit: Some(3),
            channel: Some(0),
            message_type: MessageType::Text,
        }
    }

    pub fn new_broadcast(from: String, text: String) -> Self {
        Self::new_text(from, "broadcast".to_string(), text)
    }

    pub fn is_broadcast(&self) -> bool {
        self.to == "broadcast" || self.to == "^all"
    }

    pub fn requires_ack(&self) -> bool {
        self.want_ack.unwrap_or(false)
    }
}

/// Represents a node in the mesh network
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeInfo {
    pub id: String,
    pub name: String,
    pub short_name: String,
    pub is_online: bool,
}

impl NodeInfo {
    pub fn new(id: String, name: String, short_name: String) -> Self {
        Self {
            id,
            name,
            short_name,
            is_online: false,
        }
    }

    pub fn broadcast_node() -> Self {
        Self {
            id: "broadcast".to_string(),
            name: "All Nodes".to_string(),
            short_name: "ALL".to_string(),
            is_online: true,
        }
    }
}

/// Enhanced Meshtastic packet structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MeshPacket {
    pub from: u32,
    pub to: u32,
    pub id: u32,
    pub payload: Option<PayloadVariant>,
    pub hop_limit: u8,
    pub want_ack: bool,
    pub priority: MeshPacket_Priority,
    pub rx_time: u32,
    pub rx_snr: f32,
    pub rx_rssi: i32,
    pub channel: u8,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PayloadVariant {
    Text(String),
    Position(Position),
    NodeInfo(User),
    Telemetry(TelemetryData),
    Routing(Routing),
    Admin(AdminMessage),
    Raw(Vec<u8>),
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub enum MeshPacket_Priority {
    #[default]
    DEFAULT = 64,
    MIN = 1,
    BACKGROUND = 10,
    RELIABLE = 70,
    ACK = 120,
    MAX = 127,
}

/// User information for node identification
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct User {
    pub id: String,
    pub long_name: String,
    pub short_name: String,
    pub macaddr: Vec<u8>,
    pub hw_model: HardwareModel,
    pub is_licensed: bool,
    pub role: Role,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub enum HardwareModel {
    #[default]
    UNSET = 0,
    TLORA_V2 = 1,
    TLORA_V1 = 2,
    TBEAM = 3,
    HELTEC_V2_0 = 4,
    TBEAM_V0_7 = 5,
    T_ECHO = 6,
    TLORA_V2_1_1P6 = 7,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub enum Role {
    #[default]
    CLIENT = 0,
    CLIENT_MUTE = 1,
    ROUTER = 2,
    ROUTER_CLIENT = 3,
    REPEATER = 4,
}

/// Position information
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Position {
    pub latitude_i: i32,
    pub longitude_i: i32,
    pub altitude: i32,
    pub battery_level: u32,
    pub time: u32,
    pub PDOP: u32,
    pub ground_speed: u32,
    pub ground_track: u32,
    pub sats_in_view: u32,
    pub precision_bits: u32,
}

/// Telemetry data from device sensors
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TelemetryData {
    pub time: u32,
    pub variant: Option<TelemetryVariant>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TelemetryVariant {
    DeviceMetrics(DeviceMetrics),
    EnvironmentMetrics(EnvironmentMetrics),
    PowerMetrics(PowerMetrics),
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct DeviceMetrics {
    pub battery_level: u32,
    pub voltage: f32,
    pub channel_utilization: f32,
    pub air_util_tx: f32,
    pub uptime_seconds: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EnvironmentMetrics {
    pub temperature: f32,
    pub relative_humidity: f32,
    pub barometric_pressure: f32,
    pub gas_resistance: f32,
    pub voltage: f32,
    pub current: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PowerMetrics {
    pub ch1_voltage: f32,
    pub ch1_current: f32,
    pub ch2_voltage: f32,
    pub ch2_current: f32,
    pub ch3_voltage: f32,
    pub ch3_current: f32,
}

/// Routing information
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Routing {
    pub variant: Option<RoutingVariant>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RoutingVariant {
    RouteRequest(RouteDiscovery),
    RouteReply(RouteDiscovery),
    ErrorReason(Routing_Error),
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct RouteDiscovery {
    pub route: Vec<u32>,
    pub snr_towards: Vec<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub enum Routing_Error {
    #[default]
    NONE = 0,
    NO_ROUTE = 1,
    GOT_NAK = 2,
    TIMEOUT = 3,
    NO_INTERFACE = 4,
    MAX_RETRANSMIT = 5,
    NO_CHANNEL = 6,
    TOO_LARGE = 7,
    NO_RESPONSE = 8,
    DUTY_CYCLE_LIMIT = 9,
    BAD_REQUEST = 32,
    NOT_AUTHORIZED = 33,
}

/// Administrative messages for device configuration
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AdminMessage {
    pub variant: Option<admin_message::Variant>,
}

pub mod admin_message {
    use super::*;
    
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub enum Variant {
        GetChannel(GetChannelRequest),
        GetOwner(GetOwnerRequest),
        GetConfig(GetConfigRequest),
        GetModuleConfig(GetModuleConfigRequest),
        GetCannedMessageModuleMessages(GetCannedMessageModuleMessagesRequest),
        GetDeviceMetadata(GetDeviceMetadataRequest),
        SetOwner(User),
        SetChannel(Channel),
        SetConfig(Config),
        SetModuleConfig(ModuleConfig),
        SetCannedMessageModuleMessages(String),
        SetRingtone(String),
        RemoveByNodenum(u32),
        SetFavoriteNode(u32),
        RemoveFavoriteNode(u32),
        SetFixedPosition(Position),
        RemoveFixedPosition(bool),
        SetTime(u32),
        Shutdown(u32),
        Reboot(u32),
        RebootOta(u32),
        ExitSimulator(bool),
        LoadUrl(String),
        FactoryReset(u32),
        NodedbReset(u32),
        BeginEditSettings(bool),
        CommitEditSettings(bool),
        SetRadio(RadioConfig),
    }
}

// Placeholder types for admin messages
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GetChannelRequest { pub index: u32 }

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GetOwnerRequest {}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GetConfigRequest { pub config_type: u32 }

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GetModuleConfigRequest { pub config_type: u32 }

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GetCannedMessageModuleMessagesRequest {}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GetDeviceMetadataRequest {}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Channel {
    pub index: u32,
    pub settings: Option<ChannelSettings>,
    pub role: Channel_Role,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub enum Channel_Role {
    #[default]
    DISABLED = 0,
    PRIMARY = 1,
    SECONDARY = 2,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ChannelSettings {
    pub psk: Vec<u8>,
    pub name: String,
    pub id: u32,
    pub uplink_enabled: bool,
    pub downlink_enabled: bool,
    pub module_settings: Option<ModuleSettings>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ModuleSettings {
    // Placeholder for module-specific settings
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Config {
    // Configuration payload variant would go here
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ModuleConfig {
    // Module configuration payload variant would go here
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct RadioConfig {
    pub use_preset: bool,
    pub modem_preset: i32,
    pub bandwidth: u32,
    pub spread_factor: u32,
    pub coding_rate: u32,
    pub frequency_offset: f32,
    pub region: i32,
    pub hop_limit: u32,
    pub tx_enabled: bool,
    pub tx_power: i32,
    pub sx126x_rx_boosted_gain: bool,
    pub override_duty_cycle: bool,
}

// Additional enums for configuration
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub enum Config_LoRaConfig_RegionCode {
    #[default]
    UNSET = 0,
    US = 1,
    EU_433 = 2,
    EU_868 = 3,
    CN = 4,
    JP = 5,
    ANZ = 6,
    KR = 7,
    TW = 8,
    RU = 9,
    IN = 10,
    NZ_865 = 11,
    TH = 12,
    LORA_24 = 13,
    UA_433 = 14,
    UA_868 = 15,
    MY_433 = 16,
    MY_919 = 17,
    SG_923 = 18,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub enum Config_LoRaConfig_ModemPreset {
    #[default]
    LONG_FAST = 0,
    LONG_SLOW = 1,
    VERY_LONG_SLOW = 2,
    MEDIUM_SLOW = 3,
    MEDIUM_FAST = 4,
    SHORT_SLOW = 5,
    SHORT_FAST = 6,
}

impl Default for MeshPacket {
    fn default() -> Self {
        Self {
            from: 0,
            to: 0xFFFFFFFF,
            id: rand::random(),
            payload: None,
            hop_limit: 3,
            want_ack: false,
            priority: MeshPacket_Priority::DEFAULT,
            rx_time: 0,
            rx_snr: 0.0,
            rx_rssi: 0,
            channel: 0,
        }
    }
}

impl MeshPacket {
    pub fn new_text_message(from: u32, to: u32, text: &str) -> Self {
        Self {
            from,
            to,
            id: rand::random(),
            payload: Some(PayloadVariant::Text(text.to_string())),
            hop_limit: 3,
            want_ack: false,
            priority: MeshPacket_Priority::DEFAULT,
            rx_time: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs() as u32,
            rx_snr: 0.0,
            rx_rssi: 0,
            channel: 0,
        }
    }

    pub fn new_node_info(from: u32, user: User) -> Self {
        Self {
            from,
            to: 0xFFFFFFFF, // Broadcast
            id: rand::random(),
            payload: Some(PayloadVariant::NodeInfo(user)),
            hop_limit: 3,
            want_ack: false,
            priority: MeshPacket_Priority::DEFAULT,
            rx_time: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs() as u32,
            rx_snr: 0.0,
            rx_rssi: 0,
            channel: 0,
        }
    }

    pub fn new_position(from: u32, position: Position) -> Self {
        Self {
            from,
            to: 0xFFFFFFFF, // Broadcast
            id: rand::random(),
            payload: Some(PayloadVariant::Position(position)),
            hop_limit: 3,
            want_ack: false,
            priority: MeshPacket_Priority::BACKGROUND,
            rx_time: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs() as u32,
            rx_snr: 0.0,
            rx_rssi: 0,
            channel: 0,
        }
    }

    pub fn new_telemetry(from: u32, telemetry: TelemetryData) -> Self {
        Self {
            from,
            to: 0xFFFFFFFF, // Broadcast
            id: rand::random(),
            payload: Some(PayloadVariant::Telemetry(telemetry)),
            hop_limit: 3,
            want_ack: false,
            priority: MeshPacket_Priority::BACKGROUND,
            rx_time: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs() as u32,
            rx_snr: 0.0,
            rx_rssi: 0,
            channel: 0,
        }
    }

    pub fn is_broadcast(&self) -> bool {
        self.to == 0xFFFFFFFF
    }

    pub fn get_message_type(&self) -> MessageType {
        match &self.payload {
            Some(PayloadVariant::Text(_)) => MessageType::Text,
            Some(PayloadVariant::Position(_)) => MessageType::Position,
            Some(PayloadVariant::NodeInfo(_)) => MessageType::NodeInfo,
            Some(PayloadVariant::Telemetry(_)) => MessageType::Telemetry,
            Some(PayloadVariant::Routing(_)) => MessageType::Routing,
            Some(PayloadVariant::Admin(_)) => MessageType::Admin,
            _ => MessageType::Unknown,
        }
    }
}

/// Protocol handler for encoding/decoding messages
pub struct ProtocolHandler {
    local_node_id: u32,
}

impl ProtocolHandler {
    pub fn new() -> Self {
        Self {
            local_node_id: rand::random(),
        }
    }

    pub fn encode_text_message(&self, message: &MeshMessage) -> Result<Vec<u8>, ProtocolError> {
        let to_node = if message.to == "broadcast" { 0xFFFFFFFF } else {
            message.to.parse().unwrap_or(0xFFFFFFFF)
        };
        
        let packet = MeshPacket::new_text_message(
            self.local_node_id,
            to_node,
            &message.text,
        );
        
        // For now, use JSON encoding (in production, this would be protobuf)
        let json_data = serde_json::to_vec(&packet).map_err(ProtocolError::from)?;
        
        // Add simple framing: [START][LENGTH][DATA][CHECKSUM]
        let mut framed = Vec::new();
        framed.push(0x94); // Start byte 1
        framed.push(0xC3); // Start byte 2
        
        let len = json_data.len() as u16;
        framed.extend_from_slice(&len.to_le_bytes());
        framed.extend_from_slice(&json_data);
        
        // Simple XOR checksum
        let checksum = json_data.iter().fold(0u8, |acc, &b| acc ^ b);
        framed.push(checksum);
        
        Ok(framed)
    }

    pub fn decode_message(&self, data: &[u8]) -> Result<MeshMessage, ProtocolError> {
        // Remove framing
        let json_data = self.unframe_data(data)?;
        
        // Parse JSON (in production, this would be protobuf)
        let packet: MeshPacket = serde_json::from_slice(&json_data)?;
        
        match &packet.payload {
            Some(crate::protocol::PayloadVariant::Text(text)) => {
                Ok(MeshMessage {
                    from: packet.from.to_string(),
                    to: if packet.to == 0xFFFFFFFF { "broadcast".to_string() } else { packet.to.to_string() },
                    text: text.clone(),
                    timestamp: chrono::Utc::now(),
                    want_ack: Some(packet.want_ack),
                    packet_id: Some(packet.id),
                    hop_limit: Some(packet.hop_limit),
                    channel: Some(packet.channel),
                    message_type: MessageType::Text,
                })
            }
            _ => Err(ProtocolError::UnsupportedType),
        }
    }

    fn unframe_data(&self, data: &[u8]) -> Result<Vec<u8>, ProtocolError> {
        if data.len() < 5 {
            return Err(ProtocolError::InvalidFormat);
        }

        // Check start bytes
        if data[0] != 0x94 || data[1] != 0xC3 {
            return Err(ProtocolError::InvalidFormat);
        }

        // Get length
        let len = u16::from_le_bytes([data[2], data[3]]) as usize;
        
        if data.len() < 4 + len + 1 {
            return Err(ProtocolError::InvalidFormat);
        }

        let json_data = &data[4..4 + len];
        let received_checksum = data[4 + len];
        
        // Verify checksum
        let calculated_checksum = json_data.iter().fold(0u8, |acc, &b| acc ^ b);
        if received_checksum != calculated_checksum {
            return Err(ProtocolError::InvalidFormat);
        }

        Ok(json_data.to_vec())
    }

    pub fn get_local_node_id(&self) -> u32 {
        self.local_node_id
    }
}

impl Default for ProtocolHandler {
    fn default() -> Self {
        Self::new()
    }
}

/// Encode a MeshPacket to bytes (placeholder for protobuf encoding)
pub fn encode_packet(packet: &MeshPacket) -> Result<Vec<u8>, ProtocolError> {
    // In a real implementation, this would use protobuf encoding
    // For now, use JSON as a placeholder
    serde_json::to_vec(packet)
        .map_err(|e| ProtocolError::Encoding(format!("JSON encoding failed: {}", e)))
}

/// Decode bytes to a MeshPacket (placeholder for protobuf decoding)
pub fn decode_packet(data: &[u8]) -> Result<MeshPacket, ProtocolError> {
    // In a real implementation, this would use protobuf decoding
    // For now, use JSON as a placeholder
    serde_json::from_slice(data)
        .map_err(|e| ProtocolError::Decoding(format!("JSON decoding failed: {}", e)))
}

/// Extract complete frame from buffer (helper function for serial processing)
pub fn extract_frame_from_buffer(buffer: &mut bytes::BytesMut) -> Option<Vec<u8>> {
    const FRAME_START: u8 = 0x94;
    const FRAME_END: u8 = 0x7E;
    const ESCAPE: u8 = 0x7D;
    const ESCAPE_XOR: u8 = 0x20;
    
    // Find frame boundaries
    let start_pos = buffer.iter().position(|&b| b == FRAME_START)?;
    let end_pos = buffer[start_pos + 1..].iter().position(|&b| b == FRAME_END)? + start_pos + 1;
    
    // Extract and remove the frame from buffer
    let frame_data = buffer[start_pos + 1..end_pos].to_vec();
    let _ = buffer.split_to(end_pos + 1);
    
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
        
        // Simple CRC check (in real implementation would use proper CRC16)
        let calculated_crc = payload.iter().fold(0u16, |acc, &b| acc.wrapping_add(b as u16));
        
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

/// Message processor for handling incoming packets
#[derive(Debug)]
pub struct MessageProcessor {
    node_database: Arc<RwLock<HashMap<u32, User>>>,
    message_history: Arc<RwLock<Vec<MeshMessage>>>,
    packet_cache: Arc<RwLock<HashMap<u32, MeshPacket>>>, // For deduplication
    message_tx: Option<mpsc::UnboundedSender<MeshMessage>>,
}

impl MessageProcessor {
    pub fn new() -> Self {
        Self {
            node_database: Arc::new(RwLock::new(HashMap::new())),
            message_history: Arc::new(RwLock::new(Vec::new())),
            packet_cache: Arc::new(RwLock::new(HashMap::new())),
            message_tx: None,
        }
    }

    pub fn with_message_channel(mut self, tx: mpsc::UnboundedSender<MeshMessage>) -> Self {
        self.message_tx = Some(tx);
        self
    }

    /// Process incoming packet and extract relevant information
    pub async fn process_packet(&self, packet: MeshPacket) -> Result<(), ProtocolError> {
        // Check for duplicate packets
        {
            let mut cache = self.packet_cache.write().await;
            if cache.contains_key(&packet.id) {
                // Duplicate packet, ignore
                return Ok(());
            }
            cache.insert(packet.id, packet.clone());
            
            // Keep cache size reasonable
            if cache.len() > 1000 {
                cache.clear();
            }
        }

        match &packet.payload {
            Some(PayloadVariant::Text(text)) => {
                let message = MeshMessage {
                    from: packet.from.to_string(),
                    to: if packet.is_broadcast() { "broadcast".to_string() } else { packet.to.to_string() },
                    text: text.clone(),
                    timestamp: Utc::now(),
                    want_ack: Some(packet.want_ack),
                    packet_id: Some(packet.id),
                    hop_limit: Some(packet.hop_limit),
                    channel: Some(packet.channel),
                    message_type: MessageType::Text,
                };
                
                self.store_message(message.clone()).await;
                
                if let Some(tx) = &self.message_tx {
                    let _ = tx.send(message);
                }
            }
            Some(PayloadVariant::NodeInfo(user)) => {
                self.update_node_info(packet.from, user.clone()).await;
                
                let message = MeshMessage {
                    from: packet.from.to_string(),
                    to: "broadcast".to_string(),
                    text: format!("Node info: {} ({})", user.long_name, user.short_name),
                    timestamp: Utc::now(),
                    want_ack: Some(false),
                    packet_id: Some(packet.id),
                    hop_limit: Some(packet.hop_limit),
                    channel: Some(packet.channel),
                    message_type: MessageType::NodeInfo,
                };
                
                if let Some(tx) = &self.message_tx {
                    let _ = tx.send(message);
                }
            }
            Some(PayloadVariant::Position(position)) => {
                let lat = position.latitude_i as f64 / 1e7;
                let lon = position.longitude_i as f64 / 1e7;
                
                let message = MeshMessage {
                    from: packet.from.to_string(),
                    to: "broadcast".to_string(),
                    text: format!("Position: {:.6}, {:.6} (alt: {}m)", lat, lon, position.altitude),
                    timestamp: Utc::now(),
                    want_ack: Some(false),
                    packet_id: Some(packet.id),
                    hop_limit: Some(packet.hop_limit),
                    channel: Some(packet.channel),
                    message_type: MessageType::Position,
                };
                
                if let Some(tx) = &self.message_tx {
                    let _ = tx.send(message);
                }
            }
            Some(PayloadVariant::Telemetry(telemetry)) => {
                let telemetry_text = match &telemetry.variant {
                    Some(TelemetryVariant::DeviceMetrics(metrics)) => {
                        format!("Battery: {}%, Voltage: {:.2}V, Uptime: {}s", 
                            metrics.battery_level, metrics.voltage, metrics.uptime_seconds)
                    }
                    Some(TelemetryVariant::EnvironmentMetrics(metrics)) => {
                        format!("Temp: {:.1}°C, Humidity: {:.1}%, Pressure: {:.1}hPa", 
                            metrics.temperature, metrics.relative_humidity, metrics.barometric_pressure)
                    }
                    Some(TelemetryVariant::PowerMetrics(metrics)) => {
                        format!("Power: {:.2}V/{:.2}A", metrics.ch1_voltage, metrics.ch1_current)
                    }
                    None => "Telemetry data".to_string(),
                };
                
                let message = MeshMessage {
                    from: packet.from.to_string(),
                    to: "broadcast".to_string(),
                    text: telemetry_text,
                    timestamp: Utc::now(),
                    want_ack: Some(false),
                    packet_id: Some(packet.id),
                    hop_limit: Some(packet.hop_limit),
                    channel: Some(packet.channel),
                    message_type: MessageType::Telemetry,
                };
                
                if let Some(tx) = &self.message_tx {
                    let _ = tx.send(message);
                }
            }
            Some(PayloadVariant::Admin(_admin)) => {
                // Handle admin messages (configuration, etc.)
                let message = MeshMessage {
                    from: packet.from.to_string(),
                    to: packet.to.to_string(),
                    text: "Admin message".to_string(),
                    timestamp: Utc::now(),
                    want_ack: Some(packet.want_ack),
                    packet_id: Some(packet.id),
                    hop_limit: Some(packet.hop_limit),
                    channel: Some(packet.channel),
                    message_type: MessageType::Admin,
                };
                
                if let Some(tx) = &self.message_tx {
                    let _ = tx.send(message);
                }
            }
            Some(PayloadVariant::Routing(_routing)) => {
                // Handle routing messages
                println!("Received routing message from node {}", packet.from);
            }
            Some(PayloadVariant::Raw(_data)) => {
                // Handle raw data
                println!("Received raw data from node {}", packet.from);
            }
            None => {
                println!("Received packet with no payload from node {}", packet.from);
            }
        }

        Ok(())
    }

    async fn store_message(&self, message: MeshMessage) {
        let mut history = self.message_history.write().await;
        history.push(message);
        
        // Keep history size reasonable
        if history.len() > 10000 {
            history.remove(0);
        }
    }

    async fn update_node_info(&self, node_id: u32, user: User) {
        let mut db = self.node_database.write().await;
        db.insert(node_id, user);
    }

    pub async fn get_node_info(&self, node_id: u32) -> Option<User> {
        let db = self.node_database.read().await;
        db.get(&node_id).cloned()
    }

    pub async fn get_all_nodes(&self) -> Vec<(u32, User)> {
        let db = self.node_database.read().await;
        db.iter().map(|(&id, user)| (id, user.clone())).collect()
    }

    pub async fn get_message_history(&self) -> Vec<MeshMessage> {
        let history = self.message_history.read().await;
        history.clone()
    }

    pub async fn get_recent_messages(&self, limit: usize) -> Vec<MeshMessage> {
        let history = self.message_history.read().await;
        let start = if history.len() > limit { history.len() - limit } else { 0 };
        history[start..].to_vec()
    }
}

impl Default for MessageProcessor {
    fn default() -> Self {
        Self::new()
    }
}
