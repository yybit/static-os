use std::io::{Read, Write};

use serde::{de::DeserializeOwned, Serialize};

use crate::errors::InitError;

pub trait Decoder: DeserializeOwned {
    #[inline]
    fn decode_from(mut reader: impl Read) -> Result<Self, InitError> {
        let obj: Self = serde_yaml::from_reader(&mut reader)?;
        Ok(obj)
    }
}

impl<T: DeserializeOwned> Decoder for T {}

pub trait Encoder: Serialize {
    #[inline]
    fn encode_to(&self, mut writer: impl Write) -> Result<(), InitError> {
        serde_yaml::to_writer(&mut writer, self)?;
        Ok(())
    }
}

impl<T: Serialize> Encoder for T {}
