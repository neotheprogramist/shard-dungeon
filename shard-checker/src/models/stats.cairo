use starknet::ContractAddress;

#[derive(Drop, Serde)]
pub struct Stats {
    pub player: ContractAddress,
    pub experience: u64,
}
