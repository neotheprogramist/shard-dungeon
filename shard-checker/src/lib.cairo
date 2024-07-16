use core::traits::TryInto;
pub mod models {
    pub mod dungeon;
    pub mod inventory;
    pub mod profile;
    pub mod stats;
}
pub mod storage;

use core::array::SpanTrait;
use core::clone::Clone;
use core::array::ArrayTrait;
use starknet::{
    ContractAddress, contract_address_const
};

use models::profile::{Profile, ProfileTrait};
use models::inventory::{Inventory, InventoryTrait};
use models::dungeon::{Dungeon, DungeonTrait};

use storage::{Storage, StorageTrait};

#[derive(Clone, Debug, Drop, Serde)]
struct Call {
    to: felt252,
    selector: felt252,
    calldata: Span<felt252>,
    // context: Span<felt252>, // State needed for the call execution.
}

#[derive(Clone, Debug, Drop, Serde)]
struct Diff {
    key: felt252,
    value: felt252,
    // before: felt252, // The `upgrade_state` function could assert that state did not change during commitment.
}

fn main(input: Array<felt252>) -> Array<felt252> {
    let mut input = input.span();
    let mut calls = Serde::<Array<Call>>::deserialize(ref input).unwrap();

    let mut diffs = array![];
    /// TODO: Loading from incoming storage.
    let mut storage = StorageTrait::default();

    loop {
        let call = match calls.pop_front() {
            Option::Some(call) => call,
            Option::None => { break; },
        };

        let method = *call.calldata.at(2);

        if method == 1259008560618804745770255768445176861078101720763151456759359170279920395577 {
            diffs.append_span(register_player(call, ref storage));
        } else if method == 1620375350641424823692909544079593651472683473485402590040799191658387808581 {
            diffs.append_span(enter_dungeons(call, ref storage));
        } else if method == 138085521528844465635707021766388533460333160809770824619362347246155055131 {
            diffs.append_span(fate_strike(call, ref storage));
        } else {
            panic!("Unknown method.");
        }
    };

    let mut output = array![];
    diffs.serialize(ref output);
    output
}

fn register_player(call: Call, ref storage: Storage) -> Span<Diff> {
    let player = contract_address_const::<'p1'>();
    let mut name: ByteArray = Default::default();
    let name_len: u32 = (*call.calldata.at(6)).try_into().unwrap();

    assert(name_len == 0, 'Name length is 0.');

    name.append_word(*call.calldata.at(5), name_len);

    storage.profile = Profile { player, name };
    storage.inventory = Inventory { player, gold: 100 };

    get_diff(ref storage)
}

fn enter_dungeons(call: Call, ref storage: Storage) -> Span<Diff> {
    assert(storage.dungeon.moves > 0, 'Already in a dungeon.');

    storage.dungeon = DungeonTrait::enter(ref storage.inventory);

    get_diff(ref storage)
}

fn fate_strike(call: Call, ref storage: Storage) -> Span<Diff> {
    let block_timestamp: u64 = 2;
    let has_won_round = block_timestamp % 2 == 0;

    assert(storage.dungeon.moves == 0, 'Not in the dungeon yet.');

    storage.dungeon.moves += 1;

    if storage.dungeon.gold_in_purse == 0 {
        return get_diff(ref storage);
    }

    storage.dungeon.gold_in_purse -= 1;

    if has_won_round {
        if storage.dungeon.boss_health > 1 {
            storage.dungeon.boss_health -= 1;
            storage.dungeon.gained_experience += 1;
        } else {
            storage.dungeon.boss_health = 0;
            storage.dungeon.gained_experience += 5;
            storage.dungeon.gold_in_purse += 10;
        }
    }

    if storage.dungeon.boss_health == 0 {
        let diffs = DungeonTrait::diffs(ref storage.dungeon);

        assert(storage.inventory.gold < diffs.lost, 'Not enough gold.');

        storage.inventory.gold -= diffs.lost;
        storage.inventory.gold += diffs.earned;
    }

    get_diff(ref storage)
}

fn get_diff(ref storage: Storage) -> Span<Diff> {
    array![Diff { key: storage.inventory.player.into(), value: storage.inventory.gold.into() }].span()
}

#[cfg(test)]
mod tests {
    use core::traits::TryInto;
    use core::byte_array::ByteArrayTrait;
    use core::option::OptionTrait;
    use core::traits::Into;
    use core::serde::Serde;

    use super::{main, Call};
    use starknet::{
        ContractAddress, contract_address_const
    };

    #[test]
    fn flow() {
        let args = array![
            4,
            // register_player
            2443422441049319572448953606800759426118662504379197814235900330513790862105,
            617075754465154585683856897856256838130216341506379215893724690153393808813,
            7,
            1,
            563518697563542123606888854620392365504900406918881341246086066801626937907,
            1259008560618804745770255768445176861078101720763151456759359170279920395577,
            3,
            0,
            469786453359,
            5,
            // enter_dungeons
            2443422441049319572448953606800759426118662504379197814235900330513790862105,
            617075754465154585683856897856256838130216341506379215893724690153393808813,
            4,
            1,
            2290816654334217112471713870648682811963761252797719459477475292900316779618,
            1620375350641424823692909544079593651472683473485402590040799191658387808581,
            0,
            // fate_strike
            2443422441049319572448953606800759426118662504379197814235900330513790862105,
            617075754465154585683856897856256838130216341506379215893724690153393808813,
            4,
            1,
            2290816654334217112471713870648682811963761252797719459477475292900316779618,
            138085521528844465635707021766388533460333160809770824619362347246155055131,
            0,
            // fate_strike
            2443422441049319572448953606800759426118662504379197814235900330513790862105,
            617075754465154585683856897856256838130216341506379215893724690153393808813,
            4,
            1,
            2290816654334217112471713870648682811963761252797719459477475292900316779618,
            138085521528844465635707021766388533460333160809770824619362347246155055131,
            0
        ];

        assert_eq!(main(args).len(), 9);
    }
}

