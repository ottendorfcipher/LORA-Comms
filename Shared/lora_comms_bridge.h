#ifndef LORA_COMMS_BRIDGE_H
#define LORA_COMMS_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

// Opaque pointer for the manager
typedef void* LoraManagerPtr;

// C structures matching Rust FFI
typedef struct {
    char* id;
    char* name;
    char* path;
    uint32_t device_type;
    char* manufacturer;
    char* vendor_id;
    char* product_id;
    bool is_available;
} CDeviceInfo;

typedef struct {
    CDeviceInfo* devices;
    size_t count;
} CDeviceArray;

typedef struct {
    char* id;
    char* name;
    char* short_name;
    bool is_online;
} CNodeInfo;

typedef struct {
    CNodeInfo* nodes;
    size_t count;
} CNodeArray;

// Function declarations
char* lora_comms_test(void);
LoraManagerPtr lora_comms_init(void);
void lora_comms_cleanup(LoraManagerPtr manager);
CDeviceArray lora_comms_scan_devices(LoraManagerPtr manager);
char* lora_comms_connect_device(LoraManagerPtr manager, const char* device_path, uint32_t device_type);
bool lora_comms_send_message(LoraManagerPtr manager, const char* device_id, const char* message, const char* destination);
CNodeArray lora_comms_get_nodes(LoraManagerPtr manager, const char* device_id);
void lora_comms_free_device_array(CDeviceArray array);
void lora_comms_free_node_array(CNodeArray array);
void lora_comms_free_string(char* string);

#endif // LORA_COMMS_BRIDGE_H
