use crate::{LoraCommsManager, DeviceInfo, MeshMessage, NodeInfo, LoraCommsError};
use crate::radio::{RadioConfig, RadioManager, Region, RadioPreset};
#[cfg(feature = "mqtt")]
use crate::mqtt::{MqttGateway, MqttConfig, MqttGatewayManager, GatewayStats};
use crate::protocol::{MessageType, PayloadVariant, MeshPacket, User, Position, TelemetryData};
use std::sync::{Arc, Mutex};
use libc::c_void;
use std::ffi::{CStr, CString};
use std::ptr;
use std::mem;
use std::slice;
use std::collections::HashMap;
use libc::c_char;

// Simple test function to verify FFI is working
#[no_mangle]
pub extern "C" fn lora_comms_test() -> *mut c_char {
    println!("[RUST] lora_comms_test called!");
    match CString::new("Hello from Rust!") {
        Ok(s) => s.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}
// Global manager instance for C FFI
static mut GLOBAL_MANAGER: Option<Arc<Mutex<LoraCommsManager>>> = None;

/// Initialize the global manager
#[no_mangle]
pub extern "C" fn lora_comms_init() -> *mut c_void {
    println!("[Bridge] lora_comms_init called");
    unsafe {
        let manager = Arc::new(Mutex::new(LoraCommsManager::new()));
        GLOBAL_MANAGER = Some(manager.clone());
        let ptr = Arc::into_raw(manager) as *mut c_void;
        println!("[Bridge] lora_comms_init returning manager pointer: {:p}", ptr);
        ptr
    }
}

/// Cleanup and free the global manager
#[no_mangle]
pub extern "C" fn lora_comms_cleanup(manager: *mut c_void) {
    unsafe {
        if !manager.is_null() {
            let _ = Arc::from_raw(manager as *const Mutex<LoraCommsManager>);
        }
        GLOBAL_MANAGER = None;
    }
}

/// C representation of DeviceInfo for FFI
#[repr(C)]
pub struct CDeviceInfo {
    pub id: *mut c_char,
    pub name: *mut c_char,
    pub path: *mut c_char,
    pub device_type: u32, // 0=Serial, 1=Bluetooth, 2=TCP
    pub manufacturer: *mut c_char,
    pub vendor_id: *mut c_char,
    pub product_id: *mut c_char,
    pub is_available: bool,
}

/// C representation of enhanced MeshMessage for FFI
#[repr(C)]
pub struct CMeshMessage {
    pub from: *mut c_char,
    pub to: *mut c_char,
    pub text: *mut c_char,
    pub timestamp: i64, // Unix timestamp
    pub message_type: u32, // 0=Text, 1=Position, 2=NodeInfo, 3=Telemetry, 4=Routing, 5=Admin
    pub want_ack: bool,
    pub packet_id: u32,
    pub hop_limit: u8,
    pub channel: u8,
    pub rssi: i32,
    pub snr: f32,
}

/// C representation of enhanced NodeInfo for FFI
#[repr(C)]
pub struct CNodeInfo {
    pub id: *mut c_char,
    pub name: *mut c_char,
    pub short_name: *mut c_char,
    pub is_online: bool,
    pub hw_model: u32,
    pub role: u32,
    pub battery_level: u32,
    pub voltage: f32,
    pub last_seen: i64,
}

/// C representation of RadioConfig for FFI
#[repr(C)]
pub struct CRadioConfig {
    pub frequency: f32,
    pub bandwidth: u32,
    pub spreading_factor: u8,
    pub coding_rate: u8,
    pub tx_power: u8,
    pub region: u32, // 0=US, 1=EU433, 2=EU868, etc.
    pub preset: u32, // 0=ShortFast, 1=ShortSlow, etc.
}

/// C representation of MqttConfig for FFI
#[repr(C)]
pub struct CMqttConfig {
    pub broker_url: *mut c_char,
    pub client_id: *mut c_char,
    pub username: *mut c_char, // NULL if not used
    pub password: *mut c_char, // NULL if not used
    pub topic_prefix: *mut c_char,
    pub use_tls: bool,
    pub keep_alive: u64,
    pub qos: u8,
    pub retain: bool,
}

/// C representation of Gateway Stats for FFI
#[repr(C)]
pub struct CGatewayStats {
    pub messages_received: u64,
    pub messages_published: u64,
    pub mqtt_connections: u64,
    pub mqtt_disconnections: u64,
    pub uptime_seconds: u64,
    pub connected_nodes: u64,
    pub last_message_time: i64, // Unix timestamp, 0 if no messages
}

/// C array wrapper
#[repr(C)]
pub struct CDeviceArray {
    pub devices: *mut CDeviceInfo,
    pub count: usize,
}

#[repr(C)]
pub struct CNodeArray {
    pub nodes: *mut CNodeInfo,
    pub count: usize,
}

/// Convert Rust DeviceInfo to C representation
fn device_info_to_c(device: &DeviceInfo) -> CDeviceInfo {
    CDeviceInfo {
        id: CString::new(device.id.clone()).unwrap().into_raw(),
        name: CString::new(device.name.clone()).unwrap().into_raw(),
        path: CString::new(device.path.clone()).unwrap().into_raw(),
        device_type: match device.device_type {
            crate::DeviceType::Serial => 0,
            crate::DeviceType::Bluetooth => 1,
            crate::DeviceType::Tcp => 2,
        },
        manufacturer: device.manufacturer.as_ref()
            .map(|s| CString::new(s.clone()).unwrap().into_raw())
            .unwrap_or(ptr::null_mut()),
        vendor_id: device.vendor_id.as_ref()
            .map(|s| CString::new(s.clone()).unwrap().into_raw())
            .unwrap_or(ptr::null_mut()),
        product_id: device.product_id.as_ref()
            .map(|s| CString::new(s.clone()).unwrap().into_raw())
            .unwrap_or(ptr::null_mut()),
        is_available: device.is_available,
    }
}

/// Convert Rust NodeInfo to C representation
fn node_info_to_c(node: &NodeInfo) -> CNodeInfo {
    CNodeInfo {
        id: CString::new(node.id.clone()).unwrap().into_raw(),
        name: CString::new(node.name.clone()).unwrap().into_raw(),
        short_name: CString::new(node.short_name.clone()).unwrap().into_raw(),
        is_online: node.is_online,
        hw_model: 0, // Default values for now
        role: 0,
        battery_level: 0,
        voltage: 0.0,
        last_seen: 0,
    }
}

/// Convert C RadioConfig to Rust RadioConfig
fn c_radio_config_to_rust(c_config: &CRadioConfig) -> RadioConfig {
    let region = match c_config.region {
        0 => Region::US,
        1 => Region::EU433,
        2 => Region::EU868,
        3 => Region::CN,
        4 => Region::JP,
        5 => Region::ANZ,
        6 => Region::KR,
        7 => Region::TW,
        8 => Region::RU,
        9 => Region::IN,
        _ => Region::US,
    };
    
    let preset = match c_config.preset {
        0 => RadioPreset::ShortFast,
        1 => RadioPreset::ShortSlow,
        2 => RadioPreset::MediumFast,
        3 => RadioPreset::MediumSlow,
        4 => RadioPreset::LongFast,
        5 => RadioPreset::LongSlow,
        6 => RadioPreset::VeryLongSlow,
        _ => RadioPreset::MediumSlow,
    };
    
    RadioConfig {
        frequency: c_config.frequency,
        bandwidth: c_config.bandwidth,
        spreading_factor: c_config.spreading_factor,
        coding_rate: c_config.coding_rate,
        tx_power: c_config.tx_power,
        region,
        preset: Some(preset),
    }
}

/// Convert Rust RadioConfig to C RadioConfig
fn rust_radio_config_to_c(config: &RadioConfig) -> CRadioConfig {
    let region = match config.region {
        Region::US => 0,
        Region::EU433 => 1,
        Region::EU868 => 2,
        Region::CN => 3,
        Region::JP => 4,
        Region::ANZ => 5,
        Region::KR => 6,
        Region::TW => 7,
        Region::RU => 8,
        Region::IN => 9,
        _ => 0,
    };
    
    let preset = match config.preset {
        Some(RadioPreset::ShortFast) => 0,
        Some(RadioPreset::ShortSlow) => 1,
        Some(RadioPreset::MediumFast) => 2,
        Some(RadioPreset::MediumSlow) => 3,
        Some(RadioPreset::LongFast) => 4,
        Some(RadioPreset::LongSlow) => 5,
        Some(RadioPreset::VeryLongSlow) => 6,
        None => 3,
    };
    
    CRadioConfig {
        frequency: config.frequency,
        bandwidth: config.bandwidth,
        spreading_factor: config.spreading_factor,
        coding_rate: config.coding_rate,
        tx_power: config.tx_power,
        region,
        preset,
    }
}

#[cfg(feature = "mqtt")]
/// Convert C MqttConfig to Rust MqttConfig
fn c_mqtt_config_to_rust(c_config: &CMqttConfig) -> Result<MqttConfig, std::ffi::NulError> {
    unsafe {
        Ok(MqttConfig {
            broker_url: CStr::from_ptr(c_config.broker_url).to_string_lossy().to_string(),
            client_id: CStr::from_ptr(c_config.client_id).to_string_lossy().to_string(),
            username: if c_config.username.is_null() {
                None
            } else {
                Some(CStr::from_ptr(c_config.username).to_string_lossy().to_string())
            },
            password: if c_config.password.is_null() {
                None
            } else {
                Some(CStr::from_ptr(c_config.password).to_string_lossy().to_string())
            },
            topic_prefix: CStr::from_ptr(c_config.topic_prefix).to_string_lossy().to_string(),
            use_tls: c_config.use_tls,
            keep_alive: c_config.keep_alive,
            qos: c_config.qos,
            retain: c_config.retain,
        })
    }
}

#[cfg(feature = "mqtt")]
/// Convert Rust GatewayStats to C GatewayStats
fn rust_gateway_stats_to_c(stats: &GatewayStats) -> CGatewayStats {
    CGatewayStats {
        messages_received: stats.messages_received,
        messages_published: stats.messages_published,
        mqtt_connections: stats.mqtt_connections,
        mqtt_disconnections: stats.mqtt_disconnections,
        uptime_seconds: stats.uptime_seconds,
        connected_nodes: stats.connected_nodes,
        last_message_time: stats.last_message_time
            .map(|t| t.timestamp())
            .unwrap_or(0),
    }
}

/// Scan for devices
#[no_mangle]
pub extern "C" fn lora_comms_scan_devices(manager: *mut c_void) -> CDeviceArray {
    println!("[Bridge] lora_comms_scan_devices called with manager: {:p}", manager);
    unsafe {
        if manager.is_null() {
            println!("[Bridge] ERROR: Manager pointer is null!");
            return CDeviceArray {
                devices: ptr::null_mut(),
                count: 0,
            };
        }

        println!("[Bridge] Manager pointer is valid, attempting to lock");
        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = match manager_arc.lock() {
            Ok(guard) => {
                println!("[Bridge] Successfully locked manager");
                guard
            },
            Err(e) => {
                println!("[Bridge] ERROR: Failed to lock manager: {:?}", e);
                return CDeviceArray {
                    devices: ptr::null_mut(),
                    count: 0,
                };
            }
        };
        
        // This is a blocking call - in a real implementation, you'd want to use async
        println!("[Bridge] Creating tokio runtime");
        let rt = match tokio::runtime::Runtime::new() {
            Ok(rt) => {
                println!("[Bridge] Tokio runtime created successfully");
                rt
            },
            Err(e) => {
                println!("[Bridge] ERROR: Failed to create tokio runtime: {:?}", e);
                return CDeviceArray {
                    devices: ptr::null_mut(),
                    count: 0,
                };
            }
        };
        
        println!("[Bridge] About to call scan_devices on manager");
        let devices = match rt.block_on(manager_guard.scan_devices()) {
            Ok(devices) => {
                println!("[Bridge] scan_devices returned {} devices", devices.len());
                for (i, device) in devices.iter().enumerate() {
                    println!("[Bridge]   Device {}: {} at {}", i, device.name, device.path);
                }
                devices
            },
            Err(e) => {
                println!("[Bridge] ERROR: scan_devices failed: {:?}", e);
                return CDeviceArray {
                    devices: ptr::null_mut(),
                    count: 0,
                };
            }
        };

        if devices.is_empty() {
            println!("[Bridge] WARNING: No devices found, returning empty array");
            return CDeviceArray {
                devices: ptr::null_mut(),
                count: 0,
            };
        }

        println!("[Bridge] Converting {} devices to C representation", devices.len());
        let c_devices: Vec<CDeviceInfo> = devices.iter().map(device_info_to_c).collect();
        let count = c_devices.len();
        
        // Allocate and copy to heap
        let boxed_slice = c_devices.into_boxed_slice();
        let ptr = Box::into_raw(boxed_slice) as *mut CDeviceInfo;

        println!("[Bridge] SUCCESS: Returning CDeviceArray with {} devices at ptr {:p}", count, ptr);
        CDeviceArray {
            devices: ptr,
            count,
        }
    }
}

/// Connect to a device
#[no_mangle]
pub extern "C" fn lora_comms_connect_device(
    manager: *mut c_void,
    device_path: *const c_char,
    device_type: u32,
) -> *mut c_char {
    unsafe {
        if manager.is_null() || device_path.is_null() {
            return ptr::null_mut();
        }

        let path_str = CStr::from_ptr(device_path).to_string_lossy().to_string();
        let device_type = match device_type {
            0 => crate::DeviceType::Serial,
            1 => crate::DeviceType::Bluetooth,
            2 => crate::DeviceType::Tcp,
            _ => return ptr::null_mut(),
        };

        let device_info = DeviceInfo::new(
            path_str.clone(),
            path_str.clone(),
            path_str,
            device_type,
        );

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let mut manager_guard = manager_arc.lock().unwrap();
        
        let rt = tokio::runtime::Runtime::new().unwrap();
        match rt.block_on(manager_guard.connect_device(&device_info)) {
            Ok(device_id) => CString::new(device_id).unwrap().into_raw(),
            Err(_) => ptr::null_mut(),
        }
    }
}

/// Send a message
#[no_mangle]
pub extern "C" fn lora_comms_send_message(
    manager: *mut c_void,
    device_id: *const c_char,
    message: *const c_char,
    destination: *const c_char, // NULL for broadcast
) -> bool {
    unsafe {
        if manager.is_null() || device_id.is_null() || message.is_null() {
            return false;
        }

        let device_id_str = CStr::from_ptr(device_id).to_string_lossy().to_string();
        let message_str = CStr::from_ptr(message).to_string_lossy().to_string();
        let destination_str = if destination.is_null() {
            None
        } else {
            Some(CStr::from_ptr(destination).to_string_lossy().to_string())
        };

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = manager_arc.lock().unwrap();
        
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(manager_guard.send_message(
            &device_id_str,
            &message_str,
            destination_str.as_deref(),
        )).is_ok()
    }
}

/// Get nodes for a device
#[no_mangle]
pub extern "C" fn lora_comms_get_nodes(
    manager: *mut c_void,
    device_id: *const c_char,
) -> CNodeArray {
    unsafe {
        if manager.is_null() || device_id.is_null() {
            return CNodeArray {
                nodes: ptr::null_mut(),
                count: 0,
            };
        }

        let device_id_str = CStr::from_ptr(device_id).to_string_lossy().to_string();

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = manager_arc.lock().unwrap();
        
        let rt = tokio::runtime::Runtime::new().unwrap();
        let nodes = match rt.block_on(manager_guard.get_nodes(&device_id_str)) {
            Ok(nodes) => nodes,
            Err(_) => return CNodeArray {
                nodes: ptr::null_mut(),
                count: 0,
            },
        };

        if nodes.is_empty() {
            return CNodeArray {
                nodes: ptr::null_mut(),
                count: 0,
            };
        }

        let c_nodes: Vec<CNodeInfo> = nodes.iter().map(node_info_to_c).collect();
        let count = c_nodes.len();
        
        let boxed_slice = c_nodes.into_boxed_slice();
        let ptr = Box::into_raw(boxed_slice) as *mut CNodeInfo;

        CNodeArray {
            nodes: ptr,
            count,
        }
    }
}

/// Free device array
#[no_mangle]
pub extern "C" fn lora_comms_free_device_array(array: CDeviceArray) {
    unsafe {
        if !array.devices.is_null() {
            let _ = Box::from_raw(std::slice::from_raw_parts_mut(array.devices, array.count));
        }
    }
}

/// Free node array
#[no_mangle]
pub extern "C" fn lora_comms_free_node_array(array: CNodeArray) {
    unsafe {
        if !array.nodes.is_null() {
            let _ = Box::from_raw(std::slice::from_raw_parts_mut(array.nodes, array.count));
        }
    }
}

/// Free a C string
#[no_mangle]
pub extern "C" fn lora_comms_free_string(s: *mut c_char) {
    unsafe {
        if !s.is_null() {
            let _ = CString::from_raw(s);
        }
    }
}

// =============================================================================
// RADIO CONFIGURATION FFI FUNCTIONS
// =============================================================================

/// Set radio configuration for a device
#[no_mangle]
pub extern "C" fn lora_comms_set_radio_config(
    manager: *mut c_void,
    device_id: *const c_char,
    config: *const CRadioConfig,
) -> bool {
    unsafe {
        if manager.is_null() || device_id.is_null() || config.is_null() {
            return false;
        }

        let device_id_str = CStr::from_ptr(device_id).to_string_lossy().to_string();
        let rust_config = c_radio_config_to_rust(&*config);

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = manager_arc.lock().unwrap();
        
        let rt = tokio::runtime::Runtime::new().unwrap();
        
        // Create a RadioManager and apply configuration
        let radio_manager = RadioManager::new();
        rt.block_on(radio_manager.set_device_config(&device_id_str, rust_config)).is_ok()
    }
}

/// Get radio configuration for a device
#[no_mangle]
pub extern "C" fn lora_comms_get_radio_config(
    manager: *mut c_void,
    device_id: *const c_char,
) -> *mut CRadioConfig {
    unsafe {
        if manager.is_null() || device_id.is_null() {
            return ptr::null_mut();
        }

        let device_id_str = CStr::from_ptr(device_id).to_string_lossy().to_string();

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = manager_arc.lock().unwrap();
        
        let rt = tokio::runtime::Runtime::new().unwrap();
        
        // Create a RadioManager and get configuration
        let radio_manager = RadioManager::new();
        match rt.block_on(radio_manager.get_device_config(&device_id_str)) {
            Ok(Some(config)) => {
                let c_config = rust_radio_config_to_c(&config);
                Box::into_raw(Box::new(c_config))
            },
            _ => ptr::null_mut(),
        }
    }
}

/// Validate radio configuration
#[no_mangle]
pub extern "C" fn lora_comms_validate_radio_config(
    config: *const CRadioConfig,
) -> bool {
    unsafe {
        if config.is_null() {
            return false;
        }

        let rust_config = c_radio_config_to_rust(&*config);
        rust_config.validate().is_ok()
    }
}

/// Get available radio presets for a region
#[no_mangle]
pub extern "C" fn lora_comms_get_radio_presets(
    region: u32,
) -> *mut c_char {
    let region = match region {
        0 => Region::US,
        1 => Region::EU433,
        2 => Region::EU868,
        3 => Region::CN,
        4 => Region::JP,
        5 => Region::ANZ,
        6 => Region::KR,
        7 => Region::TW,
        8 => Region::RU,
        9 => Region::IN,
        _ => Region::US,
    };
    
    let presets = RadioManager::get_region_presets(&region);
    let preset_names: Vec<String> = presets.iter().map(|p| format!("{:?}", p)).collect();
    let json_string = serde_json::to_string(&preset_names).unwrap_or_default();
    
    CString::new(json_string).unwrap().into_raw()
}

/// Free radio config
#[no_mangle]
pub extern "C" fn lora_comms_free_radio_config(config: *mut CRadioConfig) {
    unsafe {
        if !config.is_null() {
            let _ = Box::from_raw(config);
        }
    }
}

// =============================================================================
// MQTT GATEWAY FFI FUNCTIONS (conditionally compiled)
// =============================================================================

#[cfg(feature = "mqtt")]
/// Create MQTT gateway
#[no_mangle]
pub extern "C" fn lora_comms_create_mqtt_gateway(
    manager: *mut c_void,
    gateway_id: *const c_char,
    config: *const CMqttConfig,
) -> bool {
    unsafe {
        if manager.is_null() || gateway_id.is_null() || config.is_null() {
            return false;
        }

        let gateway_id_str = CStr::from_ptr(gateway_id).to_string_lossy().to_string();
        let rust_config = match c_mqtt_config_to_rust(&*config) {
            Ok(config) => config,
            Err(_) => return false,
        };

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let mut manager_guard = manager_arc.lock().unwrap();
        
        let rt = tokio::runtime::Runtime::new().unwrap();
        
        // Create MQTT gateway and add to manager
        match rt.block_on(MqttGateway::new(rust_config)) {
            Ok(gateway) => {
                // For now, we'll just return true as the gateway creation succeeded
                // In a real implementation, you'd want to store this in the manager
                true
            },
            Err(_) => false,
        }
    }
}

#[cfg(feature = "mqtt")]
/// Connect MQTT gateway
#[no_mangle]
pub extern "C" fn lora_comms_connect_mqtt_gateway(
    manager: *mut c_void,
    gateway_id: *const c_char,
) -> bool {
    unsafe {
        if manager.is_null() || gateway_id.is_null() {
            return false;
        }

        let gateway_id_str = CStr::from_ptr(gateway_id).to_string_lossy().to_string();

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = manager_arc.lock().unwrap();
        
        let rt = tokio::runtime::Runtime::new().unwrap();
        
        // In a real implementation, you'd retrieve the gateway from the manager
        // and call its connect method
        // For now, return true as a placeholder
        true
    }
}

#[cfg(feature = "mqtt")]
/// Disconnect MQTT gateway
#[no_mangle]
pub extern "C" fn lora_comms_disconnect_mqtt_gateway(
    manager: *mut c_void,
    gateway_id: *const c_char,
) -> bool {
    unsafe {
        if manager.is_null() || gateway_id.is_null() {
            return false;
        }

        let gateway_id_str = CStr::from_ptr(gateway_id).to_string_lossy().to_string();

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = manager_arc.lock().unwrap();
        
        // In a real implementation, you'd retrieve the gateway from the manager
        // and call its disconnect method
        // For now, return true as a placeholder
        true
    }
}

#[cfg(feature = "mqtt")]
/// Get MQTT gateway statistics
#[no_mangle]
pub extern "C" fn lora_comms_get_mqtt_gateway_stats(
    manager: *mut c_void,
    gateway_id: *const c_char,
) -> *mut CGatewayStats {
    unsafe {
        if manager.is_null() || gateway_id.is_null() {
            return ptr::null_mut();
        }

        let gateway_id_str = CStr::from_ptr(gateway_id).to_string_lossy().to_string();

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = manager_arc.lock().unwrap();
        
        // In a real implementation, you'd retrieve the gateway from the manager
        // and get its statistics
        // For now, return a placeholder with zero values
        let placeholder_stats = GatewayStats {
            messages_received: 0,
            messages_published: 0,
            mqtt_connections: 0,
            mqtt_disconnections: 0,
            uptime_seconds: 0,
            connected_nodes: 0,
            last_message_time: None,
        };
        
        let c_stats = rust_gateway_stats_to_c(&placeholder_stats);
        Box::into_raw(Box::new(c_stats))
    }
}

#[cfg(feature = "mqtt")]
/// List all MQTT gateways
#[no_mangle]
pub extern "C" fn lora_comms_list_mqtt_gateways(
    manager: *mut c_void,
) -> *mut c_char {
    unsafe {
        if manager.is_null() {
            return ptr::null_mut();
        }

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = manager_arc.lock().unwrap();
        
        // In a real implementation, you'd get the list of gateways from the manager
        // For now, return an empty JSON array
        let empty_list: Vec<String> = vec![];
        let json_string = serde_json::to_string(&empty_list).unwrap_or_default();
        
        CString::new(json_string).unwrap().into_raw()
    }
}

#[cfg(feature = "mqtt")]
/// Free MQTT gateway stats
#[no_mangle]
pub extern "C" fn lora_comms_free_mqtt_gateway_stats(stats: *mut CGatewayStats) {
    unsafe {
        if !stats.is_null() {
            let _ = Box::from_raw(stats);
        }
    }
}

// =============================================================================
// MESSAGE PROCESSING FFI FUNCTIONS
// =============================================================================

/// Set message callback for receiving messages
#[no_mangle]
pub extern "C" fn lora_comms_set_message_callback(
    manager: *mut c_void,
    callback: extern "C" fn(*const CMeshMessage),
) -> bool {
    unsafe {
        if manager.is_null() {
            return false;
        }

        // In a real implementation, you'd store this callback in the manager
        // and call it when messages are received
        // For now, just return true
        true
    }
}

/// Get message history for a device
#[no_mangle]
pub extern "C" fn lora_comms_get_message_history(
    manager: *mut c_void,
    device_id: *const c_char,
    limit: u32,
) -> *mut c_char {
    unsafe {
        if manager.is_null() || device_id.is_null() {
            return ptr::null_mut();
        }

        let device_id_str = CStr::from_ptr(device_id).to_string_lossy().to_string();

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = manager_arc.lock().unwrap();
        
        // In a real implementation, you'd retrieve message history from the manager
        // For now, return an empty JSON array
        let empty_history: Vec<String> = vec![];
        let json_string = serde_json::to_string(&empty_history).unwrap_or_default();
        
        CString::new(json_string).unwrap().into_raw()
    }
}

/// Clear message history for a device
#[no_mangle]
pub extern "C" fn lora_comms_clear_message_history(
    manager: *mut c_void,
    device_id: *const c_char,
) -> bool {
    unsafe {
        if manager.is_null() || device_id.is_null() {
            return false;
        }

        let device_id_str = CStr::from_ptr(device_id).to_string_lossy().to_string();

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let mut manager_guard = manager_arc.lock().unwrap();
        
        // In a real implementation, you'd clear the message history in the manager
        // For now, return true
        true
    }
}

/// Get device statistics
#[no_mangle]
pub extern "C" fn lora_comms_get_device_stats(
    manager: *mut c_void,
    device_id: *const c_char,
) -> *mut c_char {
    unsafe {
        if manager.is_null() || device_id.is_null() {
            return ptr::null_mut();
        }

        let device_id_str = CStr::from_ptr(device_id).to_string_lossy().to_string();

        let manager_arc = &*(manager as *const Mutex<LoraCommsManager>);
        let manager_guard = manager_arc.lock().unwrap();
        
        // In a real implementation, you'd get device stats from the manager
        // For now, return placeholder stats as JSON
        let placeholder_stats = serde_json::json!({
            "messages_sent": 0,
            "messages_received": 0,
            "connection_time": 0,
            "last_heartbeat": null,
            "signal_strength": null,
            "battery_level": null
        });
        
        let json_string = placeholder_stats.to_string();
        CString::new(json_string).unwrap().into_raw()
    }
}
