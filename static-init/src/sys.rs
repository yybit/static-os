use std::fs;
use std::{
    fs::File,
    io::{self, BufRead},
};

const PROC_MOUNTS: &str = "/proc/mounts";

use crate::errors::InitError;
#[cfg(target_os = "linux")]
use nix::mount::MsFlags;

#[cfg(target_os = "linux")]
pub fn mount(src: &str, dst: &str, typ: &str, options: &str) -> Result<(), InitError> {
    if is_mounted(dst)? {
        return Ok(());
    }

    println!("Mount {} to {}", src, dst);

    let mut flags = MsFlags::empty();
    let opts = options
        .split(",")
        .into_iter()
        .filter(|&x| {
            let flag = match x {
                "ro" => Some(MsFlags::MS_RDONLY),
                "nosuid" => Some(MsFlags::MS_NOSUID),
                "nodev" => Some(MsFlags::MS_NODEV),
                "noexec" => Some(MsFlags::MS_NOEXEC),
                "relatime" => Some(MsFlags::MS_RELATIME),
                "bind" => Some(MsFlags::MS_BIND),
                "exec" | "rw" => Some(MsFlags::empty()),
                _ => None,
            };
            match flag {
                Some(f) => {
                    flags |= f;
                    false
                }
                None => true,
            }
        })
        .collect::<Vec<_>>()
        .join(",");

    nix::mount::mount(Some(src), dst, Some(typ), flags, Some(opts.as_str()))
        .map_err(|e| InitError::Raw(format!("failed to mount {} to {}: {}", src, dst, e)))?;

    Ok(())
}

#[cfg(not(target_os = "linux"))]
pub fn mount(src: &str, dst: &str, typ: &str, options: &str) -> Result<(), InitError> {
    Ok(())
}

fn is_mounted(path: &str) -> Result<bool, InitError> {
    if !fs::metadata(PROC_MOUNTS).is_ok() {
        return Ok(false);
    }
    let file = File::open(PROC_MOUNTS)?;
    let lines = io::BufReader::new(file).lines();
    let found = lines.flatten().any(|x| {
        let items = x.split(' ').collect::<Vec<_>>();
        items.len() > 2 && items[1] == path
    });

    Ok(found)
}

pub fn set_hostname(name: &str) -> Result<(), InitError> {
    nix::unistd::sethostname(name)?;
    Ok(())
}

pub fn find_process(cmdline: &str) -> Option<u32> {
    if let Ok(entries) = fs::read_dir("/proc") {
        for entry in entries {
            if let Ok(entry) = entry {
                let path = entry.path();
                if path.is_dir()
                    && path
                        .file_name()
                        .unwrap()
                        .to_string_lossy()
                        .chars()
                        .all(char::is_numeric)
                {
                    let pid = path
                        .file_name()
                        .unwrap()
                        .to_string_lossy()
                        .parse::<u32>()
                        .unwrap();
                    if let Ok(c) = fs::read_to_string(path.join("cmdline")) {
                        if c == cmdline {
                            return Some(pid);
                        }
                    }
                }
            }
        }
    }
    None
}
