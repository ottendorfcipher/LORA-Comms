use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Debug, thiserror::Error)]
pub enum ProtocolError {
    #[error("Invalid message format")]
    InvalidFormat,
    #[error("Unsupported message type")]
    UnsupportedType,
    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
    #[error("Encoding error")]
    Encoding,
    #[error("Decoding error")]
    Decoding,
}

/// Represents a message in the mesh network
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MeshMessage {
    pub id: String,
    pub text: String,
    pub sender: String,
    pub destination: Option<String>,
    pub timestamp: DateTime<Utc>,
    pub is_from_me: bool,
}

impl MeshMessage {
    pub fn new(text: String, sender: String, destination: Option<String>) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            text,
            sender,
            destination,
            timestamp: Utc::now(),
            is_from_me: false,
        }
    }

    pub fn new_outgoing(text: String, destination: Option<String>) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            text,
            sender: "local".to_string(),
            destination,
            timestamp: Utc::now(),
            is_from_me: true,
        }
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

/// Simplified Meshtastic packet structure for now
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MeshPacket {
    pub packet_type: String,
    pub from: u32,
    pub to: u32,
    pub id: u32,
    pub payload: Vec<u8>,
    pub hop_limit: u8,
    pub want_ack: bool,
}

impl MeshPacket {
    pub fn new_text_message(from: u32, to: u32, text: &str) -> Self {
        Self {
            packet_type: "TEXT".to_string(),
            from,
            to,
            id: rand::random(),
            payload: text.as_bytes().to_vec(),
            hop_limit: 3,
            want_ack: false,
        }
    }

    pub fn new_node_info(from: u32, name: &str, short_name: &str) -> Self {
        let payload = format!("{}|{}", name, short_name);
        Self {
            packet_type: "NODE_INFO".to_string(),
            from,
            to: 0xFFFFFFFF, // Broadcast
            id: rand::random(),
            payload: payload.as_bytes().to_vec(),
            hop_limit: 3,
            want_ack: false,
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
        let packet = MeshPacket::new_text_message(
            self.local_node_id,
            message.destination
                .as_ref()
                .and_then(|d| d.parse().ok())
                .unwrap_or(0xFFFFFFFF), // Broadcast
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
        
        match packet.packet_type.as_str() {
            "TEXT" => {
                let text = String::from_utf8_lossy(&packet.payload).to_string();
                Ok(MeshMessage::new(
                    text,
                    packet.from.to_string(),
                    if packet.to == 0xFFFFFFFF {
                        None
                    } else {
                        Some(packet.to.to_string())
                    },
                ))
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
