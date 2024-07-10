use starknet::{ContractAddress, contract_address_const};

#[derive(Drop, Serde, Clone)]
pub struct Profile {
    pub player: ContractAddress,
    pub name: ByteArray,
}

pub trait ProfileTrait {
    fn default() -> Profile;
}

pub impl ProfileImpl of ProfileTrait {
    fn default() -> Profile {
        Profile {
            player: contract_address_const::<0>(),
            name: Default::default(),
        }
    }
}