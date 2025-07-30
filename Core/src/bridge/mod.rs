use crate::{LoraCommsManager, DeviceInfo, MeshMessage, NodeInfo, LoraCommsError};
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

/// C representation of MeshMessage for FFI
#[repr(C)]
pub struct CMeshMessage {
    pub id: *mut c_char,
    pub text: *mut c_char,
    pub sender: *mut c_char,
    pub destination: *mut c_char, // NULL if broadcast
    pub timestamp: i64, // Unix timestamp
    pub is_from_me: bool,
}

/// C representation of NodeInfo for FFI
#[repr(C)]
pub struct CNodeInfo {
    pub id: *mut c_char,
    pub name: *mut c_char,
    pub short_name: *mut c_char,
    pub is_online: bool,
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
