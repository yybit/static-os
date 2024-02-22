use serde::Deserialize;

#[derive(Deserialize, Debug)]
pub struct User {
    pub name: String,
    pub uid: String,
    pub homedir: String,
    pub shell: String,
    pub sudo: String,
    pub lock_passwd: bool,
    #[serde(rename = "ssh-authorized-keys")]
    pub ssh_authorized_keys: Vec<String>,
}

#[derive(Deserialize, Debug)]
pub struct UserData {
    pub mounts: Vec<(String, String, String, String, String, String)>,
    pub users: Vec<User>,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "kebab-case")]
pub struct MetaData {
    pub instance_id: String,
    pub local_hostname: String,
}

#[cfg(test)]
mod tests {
    use std::fs::File;

    use crate::codec::Decoder;

    use super::{MetaData, UserData};

    #[test]
    fn test_user_data() {
        let file = File::open("testdata/user-data").unwrap();
        let user_data = UserData::decode_from(file).unwrap();
        println!("user-data: {:?}", user_data);
    }

    #[test]
    fn test_meta_data() {
        let file = File::open("testdata/meta-data").unwrap();
        let meta_data = MetaData::decode_from(file).unwrap();
        println!("meta-data: {:?}", meta_data);
    }
}
