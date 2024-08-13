use core::option::OptionTrait;
use core::traits::Into;
use starknet::ContractAddress;

use shard_dungeon::models::inventory::Inventory;
use shard_dungeon::models::stats::Stats;

#[derive(Drop, Serde)]
#[dojo::model]
pub struct Dungeon {
    #[key]
    pub player: ContractAddress,
    pub moves: u16,
    pub boss_health: u8,
    pub gained_experience: u64,
    pub gold_in_purse: u64,
    pub starting_gold: u64,
    pub minimum_gold: u64,
}

#[derive(Drop)]
pub struct Diffs {
    pub earned: u64,
    pub lost: u64,
    pub experience: u64,
}


pub trait DungeonTrait {
    fn enter(inventory: @Inventory, stats: @Stats) -> Dungeon;
    fn diffs(ref dungeon: Dungeon) -> Diffs;
}

pub impl DungeonImpl of DungeonTrait {
    fn enter(inventory: @Inventory, stats: @Stats) -> Dungeon {
        Dungeon {
            player: *inventory.player,
            moves: 1,
            boss_health: 2,
            gained_experience: 0,
            gold_in_purse: *inventory.gold,
            starting_gold: *inventory.gold,
            minimum_gold: *inventory.gold,
        }
    }

    fn diffs(ref dungeon: Dungeon) -> Diffs {
        if dungeon.gold_in_purse < dungeon.minimum_gold {
            dungeon.minimum_gold = dungeon.gold_in_purse;
        }

        let required_gold = dungeon.starting_gold - dungeon.minimum_gold;

        let (earned, lost) = if dungeon.gold_in_purse > dungeon.starting_gold {
            let earned = dungeon.gold_in_purse - dungeon.starting_gold;
            (earned + required_gold, required_gold)
        } else {
            let lost = dungeon.starting_gold - dungeon.gold_in_purse;
            (required_gold - lost, required_gold)
        };

        let diffs = Diffs { earned, lost, experience: dungeon.gained_experience };

        dungeon.gold_in_purse = 0;
        dungeon.gained_experience = 0;
        dungeon.moves = 0;

        diffs
    }
}

#[test]
fn test_diff() {
    let mut dungeon = Dungeon {
        player: 0x0.try_into().unwrap(),
        moves: 0,
        boss_health: 0,
        gained_experience: 5,
        gold_in_purse: 2,
        starting_gold: 3,
        minimum_gold: 1,
    };

    let diffs = DungeonImpl::diffs(ref dungeon);

    assert_eq!(dungeon.gold_in_purse, 0);
    assert_eq!(dungeon.gained_experience, 0);
    assert_eq!(dungeon.moves, 0);

    assert_eq!(diffs.earned, 1);
    assert_eq!(diffs.lost, 2);
    assert_eq!(diffs.experience, 5);
}
