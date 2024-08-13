use starknet::{ContractAddress, contract_address_const};

#[derive(Drop, Serde, Clone)]
pub struct Inventory {
    pub player: ContractAddress,
    pub gold: u64,
}

pub trait InventoryTrait {
    fn default() -> Inventory;
}

pub impl InventoryImpl of InventoryTrait {
    fn default() -> Inventory {
        Inventory {
            player: contract_address_const::<0>(),
            gold: 0,
        }
    }
}
