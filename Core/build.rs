use std::env;
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    
    prost_build::Config::new()
        .out_dir(&out_dir)
        .compile_protos(&["proto/meshtastic.proto"], &["proto/"])?;

    // Tell Cargo to rerun this build script if the proto file changes
    println!("cargo:rerun-if-changed=proto/meshtastic.proto");
    
    Ok(())
}
