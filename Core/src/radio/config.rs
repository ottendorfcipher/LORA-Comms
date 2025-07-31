use serde::{Deserialize, Serialize};

/// Radio configuration settings for Meshtastic devices
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RadioConfig {
    /// LoRa frequency in MHz (e.g., 915.0 for US, 868.0 for EU)
    pub frequency: f32,
    /// Bandwidth in Hz (e.g., 125000, 250000, 500000)
    pub bandwidth: u32,
    /// Spreading factor (7-12, higher = longer range but slower)
    pub spreading_factor: u8,
    /// Coding rate (5-8, higher = more error correction)
    pub coding_rate: u8,
    /// TX power in dBm (typically 0-20)
    pub tx_power: u8,
    /// Region-specific settings
    pub region: Region,
    /// Preset configuration
    pub preset: Option<RadioPreset>,
}

/// Geographical regions with specific frequency regulations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Region {
    US,        // 902-928 MHz
    EU433,     // 433.05-434.79 MHz
    EU868,     // 863-870 MHz
    CN,        // 470-510 MHz
    JP,        // 920-925 MHz
    ANZ,       // 915-928 MHz (Australia/New Zealand)
    KR,        // 920-925 MHz
    TW,        // 920-925 MHz
    RU,        // 868-870 MHz
    IN,        // 865-867 MHz
    NZ865,     // 864-868 MHz
    TH,        // 920-925 MHz
    UA433,     // 433.05-434.79 MHz
    UA868,     // 868-870 MHz
    MY433,     // 433.05-434.79 MHz
    MY919,     // 919-924 MHz
    SG923,     // 917-925 MHz
    Custom(f32), // Custom frequency
}

/// Predefined radio configurations optimized for different use cases
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RadioPreset {
    /// Short range, fast data rate (SF7, BW250)
    ShortFast,
    /// Short range, slow data rate (SF8, BW125)
    ShortSlow,
    /// Medium range, fast data rate (SF9, BW125)
    MediumFast,
    /// Medium range, slow data rate (SF10, BW125)
    MediumSlow,
    /// Long range, fast data rate (SF11, BW125)
    LongFast,
    /// Long range, slow data rate (SF12, BW125)
    LongSlow,
    /// Very long range, very slow (SF12, BW62.5)
    VeryLongSlow,
}

impl Default for RadioConfig {
    fn default() -> Self {
        Self {
            frequency: 915.0, // Default to US frequency
            bandwidth: 125000,
            spreading_factor: 10,
            coding_rate: 8,
            tx_power: 17,
            region: Region::US,
            preset: Some(RadioPreset::MediumSlow),
        }
    }
}

impl RadioConfig {
    /// Create a new radio configuration for a specific region
    pub fn for_region(region: Region) -> Self {
        let frequency = match region {
            Region::US | Region::ANZ => 915.0,
            Region::EU433 | Region::UA433 | Region::MY433 => 433.175,
            Region::EU868 | Region::RU | Region::IN | Region::NZ865 | Region::UA868 => 868.0,
            Region::CN => 490.0,
            Region::JP | Region::KR | Region::TW | Region::TH => 923.0,
            Region::MY919 => 919.0,
            Region::SG923 => 923.0,
            Region::Custom(freq) => freq,
        };

        Self {
            frequency,
            region,
            ..Default::default()
        }
    }

    /// Apply a preset configuration
    pub fn with_preset(mut self, preset: RadioPreset) -> Self {
        match preset {
            RadioPreset::ShortFast => {
                self.spreading_factor = 7;
                self.bandwidth = 250000;
                self.coding_rate = 5;
            }
            RadioPreset::ShortSlow => {
                self.spreading_factor = 8;
                self.bandwidth = 125000;
                self.coding_rate = 8;
            }
            RadioPreset::MediumFast => {
                self.spreading_factor = 9;
                self.bandwidth = 125000;
                self.coding_rate = 5;
            }
            RadioPreset::MediumSlow => {
                self.spreading_factor = 10;
                self.bandwidth = 125000;
                self.coding_rate = 8;
            }
            RadioPreset::LongFast => {
                self.spreading_factor = 11;
                self.bandwidth = 125000;
                self.coding_rate = 5;
            }
            RadioPreset::LongSlow => {
                self.spreading_factor = 12;
                self.bandwidth = 125000;
                self.coding_rate = 8;
            }
            RadioPreset::VeryLongSlow => {
                self.spreading_factor = 12;
                self.bandwidth = 62500;
                self.coding_rate = 8;
            }
        }
        self.preset = Some(preset);
        self
    }

    /// Convert to Meshtastic admin message for device configuration
    pub fn to_admin_message(&self) -> crate::protocol::AdminMessage {
        crate::protocol::AdminMessage {
            variant: Some(crate::protocol::admin_message::Variant::SetRadio(
                crate::protocol::RadioConfig {
                    use_preset: false,
                    modem_preset: self.preset.as_ref().map(|p| match p {
                        RadioPreset::ShortFast => crate::protocol::Config_LoRaConfig_ModemPreset::SHORT_FAST,
                        RadioPreset::ShortSlow => crate::protocol::Config_LoRaConfig_ModemPreset::SHORT_SLOW,
                        RadioPreset::MediumFast => crate::protocol::Config_LoRaConfig_ModemPreset::MEDIUM_FAST,
                        RadioPreset::MediumSlow => crate::protocol::Config_LoRaConfig_ModemPreset::MEDIUM_SLOW,
                        RadioPreset::LongFast => crate::protocol::Config_LoRaConfig_ModemPreset::LONG_FAST,
                        RadioPreset::LongSlow => crate::protocol::Config_LoRaConfig_ModemPreset::LONG_SLOW,
                        RadioPreset::VeryLongSlow => crate::protocol::Config_LoRaConfig_ModemPreset::VERY_LONG_SLOW,
                    }).unwrap_or(crate::protocol::Config_LoRaConfig_ModemPreset::LONG_FAST) as i32,
                    bandwidth: self.bandwidth,
                    spread_factor: self.spreading_factor as u32,
                    coding_rate: self.coding_rate as u32,
                    frequency_offset: 0.0,
                    region: match self.region {
                        Region::US => crate::protocol::Config_LoRaConfig_RegionCode::US,
                        Region::EU433 => crate::protocol::Config_LoRaConfig_RegionCode::EU_433,
                        Region::EU868 => crate::protocol::Config_LoRaConfig_RegionCode::EU_868,
                        Region::CN => crate::protocol::Config_LoRaConfig_RegionCode::CN,
                        Region::JP => crate::protocol::Config_LoRaConfig_RegionCode::JP,
                        Region::ANZ => crate::protocol::Config_LoRaConfig_RegionCode::ANZ,
                        Region::KR => crate::protocol::Config_LoRaConfig_RegionCode::KR,
                        Region::TW => crate::protocol::Config_LoRaConfig_RegionCode::TW,
                        Region::RU => crate::protocol::Config_LoRaConfig_RegionCode::RU,
                        Region::IN => crate::protocol::Config_LoRaConfig_RegionCode::IN,
                        Region::NZ865 => crate::protocol::Config_LoRaConfig_RegionCode::NZ_865,
                        Region::TH => crate::protocol::Config_LoRaConfig_RegionCode::TH,
                        Region::UA433 => crate::protocol::Config_LoRaConfig_RegionCode::UA_433,
                        Region::UA868 => crate::protocol::Config_LoRaConfig_RegionCode::UA_868,
                        Region::MY433 => crate::protocol::Config_LoRaConfig_RegionCode::MY_433,
                        Region::MY919 => crate::protocol::Config_LoRaConfig_RegionCode::MY_919,
                        Region::SG923 => crate::protocol::Config_LoRaConfig_RegionCode::SG_923,
                        Region::Custom(_) => crate::protocol::Config_LoRaConfig_RegionCode::UNSET,
                    } as i32,
                    hop_limit: 3,
                    tx_enabled: true,
                    tx_power: self.tx_power as i32,
                    sx126x_rx_boosted_gain: false,
                    override_duty_cycle: false,
                    ..Default::default()
                }
            )),
        }
    }

    /// Calculate approximate range in km based on configuration
    pub fn estimated_range_km(&self) -> f32 {
        // Very rough estimation based on spreading factor and TX power
        let sf_factor = match self.spreading_factor {
            7 => 1.0,
            8 => 1.4,
            9 => 2.0,
            10 => 2.8,
            11 => 4.0,
            12 => 5.6,
            _ => 1.0,
        };
        
        let power_factor = (self.tx_power as f32) / 20.0;
        let base_range = 2.0; // Base range of ~2km in ideal conditions
        
        base_range * sf_factor * power_factor
    }

    /// Calculate approximate data rate in bits per second
    pub fn data_rate_bps(&self) -> f32 {
        let sf = self.spreading_factor as f32;
        let bw = self.bandwidth as f32;
        let cr = self.coding_rate as f32;
        
        // LoRa data rate formula: DR = SF * (BW / 2^SF) * (CR / (CR + 4))
        sf * (bw / (2.0_f32.powf(sf))) * (4.0 / cr)
    }

    /// Get duty cycle percentage for the region
    pub fn duty_cycle_percent(&self) -> f32 {
        match self.region {
            Region::EU433 | Region::EU868 | Region::UA433 | Region::UA868 => 1.0, // 1% duty cycle in EU
            _ => 100.0, // No duty cycle restrictions in most other regions
        }
    }

    /// Validate the radio configuration
    pub fn validate(&self) -> Result<(), String> {
        // Check frequency is within allowed range for region
        let allowed_freq_range = match self.region {
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

        if self.frequency < allowed_freq_range.0 || self.frequency > allowed_freq_range.1 {
            return Err(format!(
                "Frequency {:.1} MHz is outside allowed range {:.1}-{:.1} MHz for region {:?}",
                self.frequency, allowed_freq_range.0, allowed_freq_range.1, self.region
            ));
        }

        // Validate spreading factor
        if !(7..=12).contains(&self.spreading_factor) {
            return Err(format!(
                "Spreading factor {} is invalid. Must be between 7 and 12",
                self.spreading_factor
            ));
        }

        // Validate bandwidth
        let valid_bandwidths = [7800, 10400, 15600, 20800, 31250, 41700, 62500, 125000, 250000, 500000];
        if !valid_bandwidths.contains(&self.bandwidth) {
            return Err(format!(
                "Bandwidth {} is invalid. Must be one of: {:?}",
                self.bandwidth, valid_bandwidths
            ));
        }

        // Validate coding rate
        if !(5..=8).contains(&self.coding_rate) {
            return Err(format!(
                "Coding rate {} is invalid. Must be between 5 and 8",
                self.coding_rate
            ));
        }

        // Validate TX power
        if self.tx_power > 30 {
            return Err(format!(
                "TX power {} dBm is too high. Maximum is 30 dBm",
                self.tx_power
            ));
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_radio_config_creation() {
        let config = RadioConfig::for_region(Region::EU868);
        assert_eq!(config.frequency, 868.0);
        assert!(matches!(config.region, Region::EU868));
    }

    #[test]
    fn test_preset_application() {
        let config = RadioConfig::default().with_preset(RadioPreset::LongSlow);
        assert_eq!(config.spreading_factor, 12);
        assert_eq!(config.bandwidth, 125000);
    }

    #[test]
    fn test_range_estimation() {
        let short_config = RadioConfig::default().with_preset(RadioPreset::ShortFast);
        let long_config = RadioConfig::default().with_preset(RadioPreset::LongSlow);
        
        assert!(long_config.estimated_range_km() > short_config.estimated_range_km());
    }
}
