use std::{
    collections::HashMap,
    env,
    fs::{self, File},
    io::{self, BufRead},
    os::unix::fs::PermissionsExt,
    path::Path,
    process::{Command, Stdio},
    thread,
    time::Duration,
};

use errors::InitError;
use nix::{
    libc::{SIGINT, SIGTERM, SIGTSTP, SIGUSR1, SIGUSR2},
    sys::{
        reboot::{reboot, RebootMode},
        signal::{kill, Signal},
    },
    unistd::Pid,
};
use signal_hook::iterator::Signals;

use crate::{
    cloudconfig::{MetaData, UserData},
    codec::{Decoder, Encoder},
    compose::Compose,
};

mod cloudconfig;
mod codec;
mod compose;
mod errors;
mod sys;

const DEFAULT_LIMA_CIDATA_DEV: &str = "/dev/sr0";
const DEFAULT_LIMA_CIDATA_MNT: &str = "/var/mnt/lima-cidata";
const AUTHORIZED_KEYS_PATH: &str = "/var/authorized_keys";
const EMPTY_IMAGE_TAR: &str = "/opt/images/empty-image.tar";
const EMPTY_IMAGE_TAG: &str = "empty:latest";

const OPENSSH_IMAGE_TAR: &str = "/opt/images/openssh-server.tar";
const OPENSSH_IMAGE_TAG: &str = "linuxserver/openssh-server:latest";
const OPENSSH_COMPOSE_FILE: &str = "/etc/openssh-compose.yaml";

const LIMA_COMPOSE_FILE: &str = "/etc/lima-compose.yaml";

const VIRTIO_PORTS_PATH: &str = "/sys/class/virtio-ports";
const CNI_CONF_PATH: &str = "/etc/cni";
const NERDCTL_PATH: &str = "/bin/nerdctl";

const VAR_DIR: &str = "/var";
const ETC_DIR: &str = "/var/etc";
const LOG_DIR: &str = "/var/log";

fn mount_bind_var(dst: &str, is_dir: bool) -> Result<(), InitError> {
    let src = format!("{}{}", VAR_DIR, dst);
    if is_dir {
        fs::create_dir_all(&src)
            .map_err(|e| InitError::Raw(format!("failed to create dir {}: {}", &src, e)))?;
    } else {
        File::create(&src)
            .map_err(|e| InitError::Raw(format!("failed to create file {}: {}", &src, e)))?;
    }
    sys::mount(&src, dst, "", "bind")?;
    Ok(())
}

fn init() -> Result<(), InitError> {
    sys::mount("proc", "/proc", "proc", "")?;
    sys::mount("sysfs", "/sys", "sysfs", "")?;
    sys::mount("/dev/vda2", "/", "ext4", "")?;
    sys::mount("/dev/vda3", "/var", "ext4", "")?;

    fs::create_dir_all(LOG_DIR)?;
    fs::create_dir_all(ETC_DIR)?;

    mount_bind_var("/tmp", true)?;
    mount_bind_var("/run", true)?;
    mount_bind_var("/etc/resolv.conf", false)?;

    env::set_var("PATH", "/sbin:/usr/sbin:/bin:/usr/bin");

    Ok(())
}

fn conn_network() -> Result<(), InitError> {
    Command::new("/bin/udhcpc")
        .args(["-i", "eth0", "-s", "/sbin/udhcpc-default.script"])
        .status()?;
    Ok(())
}

fn start_shell() -> Result<(), InitError> {
    Command::new("/bin/sh").status()?;
    Ok(())
}

fn handle_signals() -> Result<(), InitError> {
    let mut signals = Signals::new(&[SIGTERM, SIGUSR1, SIGUSR2, SIGINT, SIGTSTP])?;

    thread::spawn(move || {
        for sig in signals.forever() {
            println!("Received signal {:?}", sig);
            if let Ok(s) = sig.try_into() {
                match s {
                    Signal::SIGUSR1 | Signal::SIGUSR2 | Signal::SIGTERM => {
                        if let Err(err) = kill(Pid::from_raw(-1), Signal::SIGTERM) {
                            eprintln!("Failed to send SIGTERM to child processes: {}", err);
                        }
                        thread::sleep(Duration::from_secs(3));
                        let mode = match s {
                            Signal::SIGUSR1 => RebootMode::RB_HALT_SYSTEM,
                            Signal::SIGUSR2 => RebootMode::RB_POWER_OFF,
                            Signal::SIGTERM => RebootMode::RB_AUTOBOOT,
                            _ => RebootMode::RB_AUTOBOOT,
                        };
                        if let Err(err) = reboot(mode) {
                            eprintln!(
                                "Failed to exec reboot syscall with mode {:?}: {}",
                                mode, err
                            );
                        }
                    }
                    _ => {}
                }
            }
        }
    });

    Ok(())
}

fn start_acpid() -> Result<(), InitError> {
    Command::new("/bin/acpid").status()?;
    Ok(())
}

fn start_containerd() -> Result<(), InitError> {
    sys::mount(
        "cgroup2",
        "/sys/fs/cgroup",
        "cgroup2",
        "rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot",
    )?;

    // mount --bind /var/etc/cni /etc/cni
    let var_cni_conf_path = format!("{}{}", VAR_DIR, CNI_CONF_PATH);
    fs::create_dir_all(&var_cni_conf_path)?;
    sys::mount(&var_cni_conf_path, CNI_CONF_PATH, "", "bind")?;

    // Start containerd
    let containerd_stdout = File::create(format!("{}/containerd.out", LOG_DIR))?;
    let cmdline = "/bin/containerd";
    println!("Check containerd process");
    if sys::find_process(cmdline) == None {
        println!("Start containerd");
        let _child = Command::new(cmdline)
            .stdout(Stdio::from(containerd_stdout.try_clone()?))
            .stderr(Stdio::from(containerd_stdout))
            .spawn()?;
        // wait child
    }

    Ok(())
}

fn lima() {
    // Find virtio device for lima guest agent
    let dirs = fs::read_dir(VIRTIO_PORTS_PATH).unwrap();
    let vport_device_name = dirs.into_iter().find_map(|d| {
        let p = d.unwrap().path().join("name");
        if let Ok(content) = fs::read_to_string(&p) {
            if content.trim() == "io.lima-vm.guest_agent.0" {
                return Some(
                    p.parent()
                        .unwrap()
                        .file_name()
                        .ok_or("empty file name")
                        .unwrap()
                        .to_str()
                        .unwrap_or("")
                        .to_string(),
                );
            }
        }
        None
    });

    if vport_device_name == None {
        println!("Ignore lima configuration.");
        return;
    }

    let dev = env::var("LIMA_CIDATA_DEV").unwrap_or(DEFAULT_LIMA_CIDATA_DEV.to_string());
    let mnt = env::var("LIMA_CIDATA_MNT").unwrap_or(DEFAULT_LIMA_CIDATA_MNT.to_string());

    // Mount lima cdrom
    fs::create_dir_all(&mnt).unwrap();
    sys::mount(
        dev.as_str(),
        mnt.as_str(),
        "iso9660",
        "ro,mode=0700,dmode=0700,overriderockperm,exec,uid=0",
    )
    .unwrap();

    // Set hostname
    let meta_data_reader = File::open(Path::new(&mnt).join("meta-data")).unwrap();
    let meta_data = MetaData::decode_from(meta_data_reader).unwrap();
    println!("Set hostname: {}", &meta_data.local_hostname);
    sys::set_hostname(&meta_data.local_hostname).unwrap();

    // Mount user-defined mountpoints
    let user_data_reader = File::open(Path::new(&mnt).join("user-data")).unwrap();
    let user_data = UserData::decode_from(user_data_reader).unwrap();
    let mut mounts_pair = Vec::new();
    for m in user_data.mounts {
        let src = m.0.as_str();
        let dst = format!("{}{}", VAR_DIR, m.1);
        let typ = m.2.as_str();
        let options = m.3.as_str();

        fs::create_dir_all(&dst).unwrap();
        sys::mount(src, dst.as_str(), typ, options).unwrap();

        mounts_pair.push((m.1, dst));
    }

    // Write ssh authorized keys
    if !user_data.users.is_empty() {
        println!("Write authorized keys to {}", AUTHORIZED_KEYS_PATH);
        let raw_keys = user_data.users[0].ssh_authorized_keys.join("\n");
        fs::write(AUTHORIZED_KEYS_PATH, raw_keys.as_bytes()).unwrap();
        fs::set_permissions(AUTHORIZED_KEYS_PATH, fs::Permissions::from_mode(0o600)).unwrap();
    }

    // Check containerd info
    for _ in 0..30 {
        let result = Command::new(NERDCTL_PATH).args(["info"]).output();
        if result.is_ok() {
            println!(
                "Check containerd info succeed:\n {}",
                String::from_utf8_lossy(&result.unwrap().stdout)
            );
            break;
        }
        println!("Check containerd info failed: {:?}", result);
        thread::sleep(Duration::from_secs(1));
    }

    // Load image into containerd
    let empty_image_exist = Command::new(NERDCTL_PATH)
        .args(["image", "inspect", EMPTY_IMAGE_TAG])
        .output()
        .unwrap();
    if !empty_image_exist.status.success() {
        println!(
            "{} not foud, load empty image from {}",
            EMPTY_IMAGE_TAG, EMPTY_IMAGE_TAR
        );
        let empty_image_reader = File::open(EMPTY_IMAGE_TAR).unwrap();
        Command::new(NERDCTL_PATH)
            .args(["load"])
            .stdin(empty_image_reader)
            .output()
            .unwrap();
    }
    let openssh_image_exist = Command::new(NERDCTL_PATH)
        .args(["image", "inspect", OPENSSH_IMAGE_TAG])
        .output()
        .unwrap();
    if !openssh_image_exist.status.success() {
        let openssh_image_reader = File::open(OPENSSH_IMAGE_TAR).unwrap();
        Command::new(NERDCTL_PATH)
            .args(["load"])
            .stdin(openssh_image_reader)
            .output()
            .unwrap();
    }

    let lima_env_reader = File::open(Path::new(&mnt).join("lima.env")).unwrap();
    let envs = io::BufReader::new(lima_env_reader)
        .lines()
        .map(|line| {
            line.unwrap()
                .split_once("=")
                .map(|(k, v)| (k.to_string(), v.to_string()))
                .unwrap_or_default()
        })
        .collect::<HashMap<String, String>>();

    // Start openssh container
    println!("Parse and modify openssh compose file");
    let openssh_compose_reader = File::open(OPENSSH_COMPOSE_FILE).unwrap();
    let mut compose = Compose::decode_from(openssh_compose_reader).unwrap();
    if let Some(s) = compose.services.get_mut("openssh-server") {
        for (origin_path, var_path) in mounts_pair {
            if let Some(volumes) = s.volumes.as_mut() {
                volumes.push(format!("{}:{}", var_path, origin_path));
            }
        }
    }
    let var_openssh_compose_file = format!("{}{}", VAR_DIR, OPENSSH_COMPOSE_FILE);
    let mut var_openssh_compose_writer = File::create(&var_openssh_compose_file).unwrap();
    compose.encode_to(&mut var_openssh_compose_writer).unwrap();
    var_openssh_compose_writer.sync_all().unwrap();

    println!("Start openssh container");
    let output = Command::new(NERDCTL_PATH)
        .args(["compose", "-f", &var_openssh_compose_file, "up", "-d"])
        .envs(&envs)
        .output()
        .unwrap();
    if !output.status.success() {
        println!(
            "Start openssh container failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }

    // Start lima-guestagent container
    println!("Start lima-guestagent container");
    if let Some(name) = vport_device_name {
        let output = Command::new(NERDCTL_PATH)
            .args(["compose", "-f", LIMA_COMPOSE_FILE, "up", "-d"])
            .envs(&envs)
            .env("VPORT_DEVICE_NAME", name)
            .output()
            .unwrap();
        if !output.status.success() {
            println!(
                "Start lima-guestagent container failed: {}",
                String::from_utf8_lossy(&output.stderr)
            );
        }
    }

    println!("Done!!!");
}

fn main() {
    println!("init......");
    init().unwrap();
    println!("handle signals......");
    handle_signals().unwrap();
    println!("acpid......");
    start_acpid().unwrap();
    println!("containerd......");
    start_containerd().unwrap();
    println!("Welcome to static os");
    println!("network......");
    conn_network().unwrap();
    println!("lima......");
    lima();
    println!("shell......");
    start_shell().unwrap();
}
