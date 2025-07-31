#[cfg(feature = "mqtt")]
use rumqttc::{AsyncClient, Event, EventLoop, MqttOptions, Packet, QoS};
#[cfg(feature = "mqtt")]
use url::Url;

use crate::protocol::{MeshMessage, MeshPacket, MessageProcessor, MessageType, PayloadVariant};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{mpsc, RwLock};
use tokio::time::{interval, Duration};
use base64::prelude::*;

#[derive(Debug, thiserror::Error)]
pub enum MqttError {
    #[error("Connection failed: {0}")]
    ConnectionFailed(String),
    #[cfg(feature = "mqtt")]
    #[error("MQTT error: {0}")]
    Mqtt(#[from] rumqttc::ClientError),
    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
    #[error("Invalid URL: {0}")]
    InvalidUrl(String),
    #[error("Configuration error: {0}")]
    Configuration(String),
}

/// MQTT Gateway configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MqttConfig {
    /// MQTT broker URL (e.g., "mqtt://broker.example.com:1883")
    pub broker_url: String,
    /// Client ID for MQTT connection
    pub client_id: String,
    /// Username for authentication (optional)
    pub username: Option<String>,
    /// Password for authentication (optional)
    pub password: Option<String>,
    /// Topic prefix for Meshtastic messages
    pub topic_prefix: String,
    /// Whether to use TLS
    pub use_tls: bool,
    /// Keep alive interval in seconds
    pub keep_alive: u64,
    /// QoS level for published messages
    pub qos: u8,
    /// Whether to retain messages
    pub retain: bool,
}

impl Default for MqttConfig {
    fn default() -> Self {
        Self {
            broker_url: "mqtt://localhost:1883".to_string(),
            client_id: format!("lora-comms-{}", uuid::Uuid::new_v4()),
            username: None,
            password: None,
            topic_prefix: "msh".to_string(),
            use_tls: false,
            keep_alive: 60,
            qos: 1,
            retain: false,
        }
    }
}

/// MQTT message wrapper for Meshtastic data
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MqttMeshtasticMessage {
    /// Timestamp of the message
    pub timestamp: chrono::DateTime<chrono::Utc>,
    /// Source node ID
    pub from: u32,
    /// Destination node ID (0xFFFFFFFF for broadcast)
    pub to: u32,
    /// Message ID
    pub id: u32,
    /// Channel number
    pub channel: u8,
    /// Payload type
    pub payload_type: String,
    /// Message payload
    pub payload: serde_json::Value,
    /// Signal quality information
    pub rssi: Option<i32>,
    pub snr: Option<f32>,
    /// Hop information
    pub hop_limit: u8,
    /// Gateway identifier
    pub gateway_id: String,
}

/// MQTT Gateway for bridging Meshtastic mesh network to MQTT broker
pub struct MqttGateway {
    config: MqttConfig,
    #[cfg(feature = "mqtt")]
    client: Option<AsyncClient>,
    #[cfg(feature = "mqtt")]
    eventloop: Option<EventLoop>,
    message_processor: Arc<MessageProcessor>,
    node_database: Arc<RwLock<HashMap<u32, crate::protocol::User>>>,
    message_tx: Option<mpsc::UnboundedSender<MeshMessage>>,
    stats: Arc<RwLock<GatewayStats>>,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct GatewayStats {
    pub messages_received: u64,
    pub messages_published: u64,
    pub mqtt_connections: u64,
    pub mqtt_disconnections: u64,
    pub last_message_time: Option<chrono::DateTime<chrono::Utc>>,
    pub uptime_seconds: u64,
    pub connected_nodes: u64,
}

#[cfg(feature = "mqtt")]
impl MqttGateway {
    pub fn new(config: MqttConfig) -> Result<Self, MqttError> {
        let message_processor = Arc::new(MessageProcessor::new());
        
        Ok(Self {
            config,
            client: None,
            eventloop: None,
            message_processor,
            node_database: Arc::new(RwLock::new(HashMap::new())),
            message_tx: None,
            stats: Arc::new(RwLock::new(GatewayStats::default())),
        })
    }

    pub async fn connect(&mut self) -> Result<(), MqttError> {
        let url = Url::parse(&self.config.broker_url)
            .map_err(|e| MqttError::InvalidUrl(format!("Invalid broker URL: {}", e)))?;

        let host = url.host_str()
            .ok_or_else(|| MqttError::InvalidUrl("No host in URL".to_string()))?;
        let port = url.port().unwrap_or(1883);

        let mut mqttoptions = MqttOptions::new(&self.config.client_id, host, port);
        mqttoptions.set_keep_alive(Duration::from_secs(self.config.keep_alive));

        if let Some(username) = &self.config.username {
            mqttoptions.set_credentials(
                username, 
                self.config.password.as_deref().unwrap_or("")
            );
        }

        if self.config.use_tls {
            mqttoptions.set_transport(rumqttc::Transport::Tls(rumqttc::TlsConfiguration::default()));
        }

        let (client, eventloop) = AsyncClient::new(mqttoptions, 100);
        
        // Subscribe to incoming message topics
        let subscribe_topics = vec![
            format!("{}/2/c/LongFast/+/+", self.config.topic_prefix),
            format!("{}/2/e/LongFast/+/+", self.config.topic_prefix),
            format!("{}/2/stat/+", self.config.topic_prefix),
        ];

        for topic in subscribe_topics {
            client.subscribe(&topic, QoS::AtMostOnce).await
                .map_err(|e| MqttError::ConnectionFailed(format!("Failed to subscribe to {}: {}", topic, e)))?;
        }

        self.client = Some(client);
        self.eventloop = Some(eventloop);

        // Update stats
        {
            let mut stats = self.stats.write().await;
            stats.mqtt_connections += 1;
        }

        println!("Connected to MQTT broker at {}", self.config.broker_url);
        Ok(())
    }

    pub async fn disconnect(&mut self) -> Result<(), MqttError> {
        if let Some(client) = &self.client {
            client.disconnect().await
                .map_err(|e| MqttError::ConnectionFailed(format!("Failed to disconnect: {}", e)))?;
        }

        self.client = None;
        self.eventloop = None;

        // Update stats
        {
            let mut stats = self.stats.write().await;
            stats.mqtt_disconnections += 1;
        }

        Ok(())
    }

    pub async fn start_event_loop(&mut self) -> Result<(), MqttError> {
        if let Some(mut eventloop) = self.eventloop.take() {
            tokio::spawn(async move {
                loop {
                    match eventloop.poll().await {
                        Ok(Event::Incoming(Packet::Publish(publish))) => {
                            println!("Received MQTT message on topic: {}", publish.topic);
                            
                            // Parse and process incoming MQTT messages
                            if let Ok(mqtt_msg) = serde_json::from_slice::<MqttMeshtasticMessage>(&publish.payload) {
                                println!("Parsed Meshtastic message from MQTT: {:?}", mqtt_msg);
                                // Convert to internal message format and process
                                // This would typically be forwarded to connected radio devices
                            }
                        }
                        Ok(Event::Incoming(packet)) => {
                            println!("Received MQTT packet: {:?}", packet);
                        }
                        Ok(Event::Outgoing(_)) => {
                            // Outgoing packet sent successfully
                        }
                        Err(e) => {
                            eprintln!("MQTT event loop error: {}", e);
                            break;
                        }
                    }
                }
            });
        }

        Ok(())
    }

    pub async fn publish_mesh_message(&self, packet: &MeshPacket) -> Result<(), MqttError> {
        if let Some(client) = &self.client {
            let mqtt_message = self.convert_to_mqtt_message(packet).await;
            
            let topic = match &packet.payload {
                Some(PayloadVariant::Text(_)) => {
                    format!("{}/2/c/LongFast/{}/{}", 
                        self.config.topic_prefix, 
                        self.config.client_id,
                        packet.from
                    )
                }
                Some(PayloadVariant::NodeInfo(_)) => {
                    format!("{}/2/e/LongFast/{}/{}", 
                        self.config.topic_prefix, 
                        self.config.client_id,
                        packet.from
                    )
                }
                Some(PayloadVariant::Telemetry(_)) => {
                    format!("{}/2/stat/{}", 
                        self.config.topic_prefix, 
                        packet.from
                    )
                }
                _ => {
                    format!("{}/2/c/LongFast/{}/{}", 
                        self.config.topic_prefix, 
                        self.config.client_id,
                        packet.from
                    )
                }
            };

            let payload = serde_json::to_vec(&mqtt_message)?;
            let qos = match self.config.qos {
                0 => QoS::AtMostOnce,
                1 => QoS::AtLeastOnce,
                2 => QoS::ExactlyOnce,
                _ => QoS::AtLeastOnce,
            };

            client.publish(&topic, qos, self.config.retain, payload).await
                .map_err(|e| MqttError::ConnectionFailed(format!("Failed to publish: {}", e)))?;

            // Update stats
            {
                let mut stats = self.stats.write().await;
                stats.messages_published += 1;
                stats.last_message_time = Some(chrono::Utc::now());
            }
        }

        Ok(())
    }

    async fn convert_to_mqtt_message(&self, packet: &MeshPacket) -> MqttMeshtasticMessage {
        let (payload_type, payload) = match &packet.payload {
            Some(PayloadVariant::Text(text)) => {
                ("TEXT_MESSAGE_APP".to_string(), serde_json::json!({"text": text}))
            }
            Some(PayloadVariant::NodeInfo(user)) => {
                ("NODEINFO_APP".to_string(), serde_json::to_value(user).unwrap_or_default())
            }
            Some(PayloadVariant::Position(pos)) => {
                ("POSITION_APP".to_string(), serde_json::to_value(pos).unwrap_or_default())
            }
            Some(PayloadVariant::Telemetry(tel)) => {
                ("TELEMETRY_APP".to_string(), serde_json::to_value(tel).unwrap_or_default())
            }
            Some(PayloadVariant::Admin(admin)) => {
                ("ADMIN_APP".to_string(), serde_json::to_value(admin).unwrap_or_default())
            }
            Some(PayloadVariant::Routing(routing)) => {
                ("ROUTING_APP".to_string(), serde_json::to_value(routing).unwrap_or_default())
            }
            Some(PayloadVariant::Raw(data)) => {
                ("RAW".to_string(), serde_json::json!({"data": base64::prelude::BASE64_STANDARD.encode(data)}))
            }
            None => {
                ("UNKNOWN".to_string(), serde_json::json!({}))
            }
        };

        MqttMeshtasticMessage {
            timestamp: chrono::Utc::now(),
            from: packet.from,
            to: packet.to,
            id: packet.id,
            channel: packet.channel,
            payload_type,
            payload,
            rssi: if packet.rx_rssi != 0 { Some(packet.rx_rssi) } else { None },
            snr: if packet.rx_snr != 0.0 { Some(packet.rx_snr) } else { None },
            hop_limit: packet.hop_limit,
            gateway_id: self.config.client_id.clone(),
        }
    }

    pub async fn process_mesh_packet(&self, packet: MeshPacket) -> Result<(), MqttError> {
        // Update node database
        if let Some(PayloadVariant::NodeInfo(user)) = &packet.payload {
            let mut db = self.node_database.write().await;
            db.insert(packet.from, user.clone());
        }

        // Publish to MQTT
        self.publish_mesh_message(&packet).await?;

        // Update stats
        {
            let mut stats = self.stats.write().await;
            stats.messages_received += 1;
            stats.connected_nodes = self.node_database.read().await.len() as u64;
        }

        Ok(())
    }

    pub async fn get_stats(&self) -> GatewayStats {
        self.stats.read().await.clone()
    }

    pub async fn start_heartbeat(&self, interval_seconds: u64) {
        let stats = Arc::clone(&self.stats);
        let client = self.client.clone();
        let topic_prefix = self.config.topic_prefix.clone();
        let client_id = self.config.client_id.clone();
        
        tokio::spawn(async move {
            let mut interval = interval(Duration::from_secs(interval_seconds));
            let start_time = chrono::Utc::now();
            
            loop {
                interval.tick().await;
                
                if let Some(client) = &client {
                    let current_stats = {
                        let mut stats_guard = stats.write().await;
                        stats_guard.uptime_seconds = chrono::Utc::now()
                            .signed_duration_since(start_time)
                            .num_seconds() as u64;
                        stats_guard.clone()
                    };
                    
                    let heartbeat_topic = format!("{}/2/stat/{}/heartbeat", topic_prefix, client_id);
                    let heartbeat_payload = serde_json::to_vec(&current_stats).unwrap_or_default();
                    
                    if let Err(e) = client.publish(&heartbeat_topic, QoS::AtMostOnce, false, heartbeat_payload).await {
                        eprintln!("Failed to publish heartbeat: {}", e);
                    }
                }
            }
        });
    }

    pub async fn get_connected_nodes(&self) -> Vec<(u32, crate::protocol::User)> {
        let db = self.node_database.read().await;
        db.iter().map(|(&id, user)| (id, user.clone())).collect()
    }
}

#[cfg(not(feature = "mqtt"))]
impl MqttGateway {
    pub fn new(_config: MqttConfig) -> Result<Self, MqttError> {
        Err(MqttError::Configuration("MQTT feature not enabled".to_string()))
    }

    pub async fn connect(&mut self) -> Result<(), MqttError> {
        Err(MqttError::Configuration("MQTT feature not enabled".to_string()))
    }

    pub async fn disconnect(&mut self) -> Result<(), MqttError> {
        Err(MqttError::Configuration("MQTT feature not enabled".to_string()))
    }

    pub async fn start_event_loop(&mut self) -> Result<(), MqttError> {
        Err(MqttError::Configuration("MQTT feature not enabled".to_string()))
    }

    pub async fn publish_mesh_message(&self, _packet: &MeshPacket) -> Result<(), MqttError> {
        Err(MqttError::Configuration("MQTT feature not enabled".to_string()))
    }

    pub async fn process_mesh_packet(&self, _packet: MeshPacket) -> Result<(), MqttError> {
        Err(MqttError::Configuration("MQTT feature not enabled".to_string()))
    }

    pub async fn get_stats(&self) -> GatewayStats {
        GatewayStats::default()
    }

    pub async fn start_heartbeat(&self, _interval_seconds: u64) {}

    pub async fn get_connected_nodes(&self) -> Vec<(u32, crate::protocol::User)> {
        Vec::new()
    }
}

/// MQTT Gateway manager for handling multiple gateway instances
pub struct MqttGatewayManager {
    gateways: Arc<RwLock<HashMap<String, MqttGateway>>>,
}

impl MqttGatewayManager {
    pub fn new() -> Self {
        Self {
            gateways: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn add_gateway(&self, name: String, config: MqttConfig) -> Result<(), MqttError> {
        let gateway = MqttGateway::new(config)?;
        let mut gateways = self.gateways.write().await;
        gateways.insert(name, gateway);
        Ok(())
    }

    pub async fn connect_gateway(&self, name: &str) -> Result<(), MqttError> {
        let mut gateways = self.gateways.write().await;
        if let Some(gateway) = gateways.get_mut(name) {
            gateway.connect().await?;
            gateway.start_event_loop().await?;
            gateway.start_heartbeat(300).await; // 5 minute heartbeat
            Ok(())
        } else {
            Err(MqttError::Configuration(format!("Gateway '{}' not found", name)))
        }
    }

    pub async fn disconnect_gateway(&self, name: &str) -> Result<(), MqttError> {
        let mut gateways = self.gateways.write().await;
        if let Some(gateway) = gateways.get_mut(name) {
            gateway.disconnect().await
        } else {
            Err(MqttError::Configuration(format!("Gateway '{}' not found", name)))
        }
    }

    pub async fn process_packet(&self, gateway_name: &str, packet: MeshPacket) -> Result<(), MqttError> {
        let gateways = self.gateways.read().await;
        if let Some(gateway) = gateways.get(gateway_name) {
            gateway.process_mesh_packet(packet).await
        } else {
            Err(MqttError::Configuration(format!("Gateway '{}' not found", gateway_name)))
        }
    }

    pub async fn get_gateway_stats(&self, name: &str) -> Option<GatewayStats> {
        let gateways = self.gateways.read().await;
        if let Some(gateway) = gateways.get(name) {
            Some(gateway.get_stats().await)
        } else {
            None
        }
    }

    pub async fn list_gateways(&self) -> Vec<String> {
        let gateways = self.gateways.read().await;
        gateways.keys().cloned().collect()
    }
}

impl Default for MqttGatewayManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mqtt_config_default() {
        let config = MqttConfig::default();
        assert_eq!(config.broker_url, "mqtt://localhost:1883");
        assert_eq!(config.topic_prefix, "msh");
        assert!(!config.use_tls);
    }

    #[tokio::test]
    async fn test_gateway_manager() {
        let manager = MqttGatewayManager::new();
        
        let config = MqttConfig {
            broker_url: "mqtt://test.mosquitto.org:1883".to_string(),
            ..Default::default()
        };
        
        assert!(manager.add_gateway("test".to_string(), config).is_ok());
        assert_eq!(manager.list_gateways().await, vec!["test"]);
    }
}
