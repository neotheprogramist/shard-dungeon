use starknet::{ContractAddress, contract_address_const};

use super::models::profile::{Profile, ProfileTrait};
use super::models::inventory::{Inventory, InventoryTrait};
use super::models::dungeon::{Dungeon, DungeonTrait};

#[derive(Drop, Serde)]
pub struct Storage {
    pub player: ContractAddress,
    pub profile: Profile,
    pub inventory: Inventory,
    pub dungeon: Dungeon,
}

pub trait StorageTrait {
    fn default() -> Storage;
}

pub impl StorageImpl of StorageTrait {
    fn default() -> Storage {
        Storage {
            player: contract_address_const::<0>(),
            profile: ProfileTrait::default(),
            inventory: InventoryTrait::default(),
            dungeon: DungeonTrait::default()
        }
    }
}