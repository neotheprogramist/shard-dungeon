use starknet::ContractAddress;
use option::Option;

#[derive(Drop, Serde)]
#[dojo::model]
pub struct Inventory {
    #[key]
    pub player: ContractAddress,
    pub gold: u64,
}
