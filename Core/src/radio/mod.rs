pub mod config;

pub use config::{RadioConfig, Region, RadioPreset};

use crate::protocol::{MeshPacket, AdminMessage};
use crate::device::{Device, DeviceError};

/// Advanced radio configuration and management
pub struct RadioManager {
    /// Current radio configuration
    config: RadioConfig,
    /// Device reference for sending configuration commands
    device: Option<Box<dyn Device>>,
}

impl RadioManager {
    pub fn new() -> Self {
        Self {
            config: RadioConfig::default(),
            device: None,
        }
    }

    pub fn with_device(mut self, device: Box<dyn Device>) -> Self {
        self.device = Some(device);
        self
    }

    /// Set radio configuration
    pub fn set_config(&mut self, config: RadioConfig) {
        self.config = config;
    }

    /// Get current radio configuration
    pub fn get_config(&self) -> &RadioConfig {
        &self.config
    }

    /// Apply configuration to connected device
    pub async fn apply_configuration(&self) -> Result<(), DeviceError> {
        if let Some(device) = &self.device {
            // Create admin message for radio configuration
            let config_packet = MeshPacket {
                from: 0, // Will be set by device
                to: 0, // Send to self
                id: rand::random(),
                payload: Some(crate::protocol::PayloadVariant::Admin(
                    self.config.to_admin_message()
                )),
                hop_limit: 1,
                want_ack: true,
                priority: crate::protocol::MeshPacket_Priority::RELIABLE,
                rx_time: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_secs() as u32,
                ..Default::default()
            };

            // Send configuration via device's message system
            let message = crate::protocol::MeshMessage {
                from: "config".to_string(),
                to: "self".to_string(),
                text: "Radio configuration update".to_string(),
                timestamp: chrono::Utc::now(),
                want_ack: Some(true),
                packet_id: Some(config_packet.id),
                hop_limit: Some(1),
                channel: Some(0),
                message_type: crate::protocol::MessageType::Admin,
            };

            device.send_message(&message).await
        } else {
            Err(DeviceError::ConnectionFailed {
                message: "No device connected".to_string(),
            })
        }
    }

    /// Get recommended configurations for different use cases
    pub fn get_recommendations() -> Vec<(String, RadioConfig)> {
        vec![
            (
                "City/Urban - Short Range".to_string(),
                RadioConfig::default().with_preset(RadioPreset::ShortFast)
            ),
            (
                "Suburban - Medium Range".to_string(),
                RadioConfig::default().with_preset(RadioPreset::MediumSlow)
            ),
            (
                "Rural - Long Range".to_string(),
                RadioConfig::default().with_preset(RadioPreset::LongSlow)
            ),
            (
                "Remote - Maximum Range".to_string(),
                RadioConfig::default().with_preset(RadioPreset::VeryLongSlow)
            ),
        ]
    }

    /// Set device-specific radio configuration
    pub async fn set_device_config(&self, device_id: &str, config: RadioConfig) -> Result<(), DeviceError> {
        // In a real implementation, this would store the config per device
        // For now, just validate the config
        let mut temp_manager = RadioManager::new();
        temp_manager.config = config;
        temp_manager.validate_config().map_err(|e| DeviceError::InvalidConfiguration { message: e })?;
        Ok(())
    }

    /// Get device-specific radio configuration
    pub async fn get_device_config(&self, device_id: &str) -> Result<Option<RadioConfig>, DeviceError> {
        // In a real implementation, this would retrieve the config for the specific device
        // For now, return the current config if device_id is valid
        if !device_id.is_empty() {
            Ok(Some(self.config.clone()))
        } else {
            Ok(None)
        }
    }

    /// Get available presets for a region
    pub fn get_region_presets(region: &Region) -> Vec<RadioPreset> {
        // All presets are generally available for all regions
        // Some regions might have restrictions, but for now return all
        vec![
            RadioPreset::ShortFast,
            RadioPreset::ShortSlow,
            RadioPreset::MediumFast,
            RadioPreset::MediumSlow,
            RadioPreset::LongFast,
            RadioPreset::LongSlow,
            RadioPreset::VeryLongSlow,
        ]
    }

    /// Validate configuration for a specific region
    pub fn validate_config(&self) -> Result<(), String> {
        // Check frequency is within allowed range for region
        let allowed_freq_range = match self.config.region {
            Region::US => (902.0, 928.0),
            Region::EU433 => (433.05, 434.79),
            Region::EU868 => (863.0, 870.0),
            Region::CN => (470.0, 510.0),
            Region::JP => (920.0, 925.0),
            Region::ANZ => (915.0, 928.0),
            Region::KR => (920.0, 925.0),
            Region::TW => (920.0, 925.0),
            Region::RU => (868.0, 870.0),
            Region::IN => (865.0, 867.0),
            Region::NZ865 => (864.0, 868.0),
            Region::TH => (920.0, 925.0),
            Region::UA433 => (433.05, 434.79),
            Region::UA868 => (868.0, 870.0),
            Region::MY433 => (433.05, 434.79),
            Region::MY919 => (919.0, 924.0),
            Region::SG923 => (917.0, 925.0),
            Region::Custom(_) => return Ok(()), // Skip validation for custom frequencies
        };

        if self.config.frequency < allowed_freq_range.0 || self.config.frequency > allowed_freq_range.1 {
            return Err(format!(
                "Frequency {:.1} MHz is outside allowed range {:.1}-{:.1} MHz for region {:?}",
                self.config.frequency, allowed_freq_range.0, allowed_freq_range.1, self.config.region
            ));
        }

        // Validate spreading factor
        if !(7..=12).contains(&self.config.spreading_factor) {
            return Err(format!(
                "Spreading factor {} is invalid. Must be between 7 and 12",
                self.config.spreading_factor
            ));
        }

        // Validate bandwidth
        let valid_bandwidths = [7800, 10400, 15600, 20800, 31250, 41700, 62500, 125000, 250000, 500000];
        if !valid_bandwidths.contains(&self.config.bandwidth) {
            return Err(format!(
                "Bandwidth {} is invalid. Must be one of: {:?}",
                self.config.bandwidth, valid_bandwidths
            ));
        }

        // Validate coding rate
        if !(5..=8).contains(&self.config.coding_rate) {
            return Err(format!(
                "Coding rate {} is invalid. Must be between 5 and 8",
                self.config.coding_rate
            ));
        }

        // Validate TX power
        if self.config.tx_power > 30 {
            return Err(format!(
                "TX power {} dBm is too high. Maximum is 30 dBm",
                self.config.tx_power
            ));
        }

        Ok(())
    }

    /// Calculate air time for a message of given length
    pub fn calculate_air_time_ms(&self, payload_bytes: usize) -> f32 {
        let sf = self.config.spreading_factor as f32;
        let bw = self.config.bandwidth as f32;
        let cr = self.config.coding_rate as f32;
        
        // LoRa symbol time
        let ts = (2.0_f32.powf(sf)) / bw;
        
        // Preamble time (typically 8 symbols + 4.25 symbols)
        let t_preamble = (8.0 + 4.25) * ts;
        
        // Payload symbols calculation
        let payload_symbols = {
            let pl = payload_bytes as f32;
            let de = if bw < 125000.0 { 1.0 } else { 0.0 }; // Low data rate optimization
            let ih = 0.0; // Implicit header disabled
            let crc = 1.0; // CRC enabled
            
            8.0 + ((8.0 * pl - 4.0 * sf + 28.0 + 16.0 * crc - 20.0 * ih) / (4.0 * (sf - 2.0 * de))).ceil() * (cr + 4.0)
        };
        
        let t_payload = payload_symbols * ts;
        
        (t_preamble + t_payload) * 1000.0 // Convert to milliseconds
    }

    /// Check if configuration violates duty cycle limits
    pub fn check_duty_cycle(&self, messages_per_hour: u32, avg_message_size: usize) -> Result<(), String> {
        let duty_cycle_limit = self.config.duty_cycle_percent();
        
        if duty_cycle_limit >= 100.0 {
            return Ok(()); // No duty cycle restrictions
        }
        
        let air_time_per_message = self.calculate_air_time_ms(avg_message_size);
        let total_air_time_per_hour = (messages_per_hour as f32) * air_time_per_message;
        let duty_cycle_used = (total_air_time_per_hour / (60.0 * 60.0 * 1000.0)) * 100.0;
        
        if duty_cycle_used > duty_cycle_limit {
            Err(format!(
                "Duty cycle violation: {:.2}% used, {:.1}% allowed. Reduce message frequency or size.",
                duty_cycle_used, duty_cycle_limit
            ))
        } else {
            Ok(())
        }
    }
}

impl Default for RadioManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_radio_manager_creation() {
        let manager = RadioManager::new();
        assert_eq!(manager.config.frequency, 915.0);
    }

    #[test]
    fn test_config_validation() {
        let mut manager = RadioManager::new();
        
        // Valid configuration
        assert!(manager.validate_config().is_ok());
        
        // Invalid spreading factor
        manager.config.spreading_factor = 15;
        assert!(manager.validate_config().is_err());
    }

    #[test]
    fn test_air_time_calculation() {
        let manager = RadioManager::new();
        let air_time = manager.calculate_air_time_ms(50); // 50 byte message
        assert!(air_time > 0.0);
        assert!(air_time < 10000.0); // Should be reasonable
    }

    #[test]
    fn test_duty_cycle_check() {
        let mut manager = RadioManager::new();
        manager.config.region = Region::EU868; // Has 1% duty cycle limit
        
        // Should pass with low message rate
        assert!(manager.check_duty_cycle(10, 50).is_ok());
        
        // Should fail with high message rate
        assert!(manager.check_duty_cycle(1000, 200).is_err());
    }
}
