/// The hazard hall is a place where players can strike the boss, and based
/// on some execution info, the players can win or lose.
///
/// NOTE:
/// Currently, this contract is being deployed by Sozo during `sozo migrate apply`.
/// We may skip this contract deployment and let the shard doing so. We only need it
/// to be declared.
use option::{Option, OptionTrait};
use result::Result;

#[dojo::interface]
trait IHazardHall {
    /// Enters the dungeon, locks the player's gold and initiates the boss.
    fn enter_dungeon(ref world: IWorldDispatcher) -> Result<(), ()>;
    /// Strikes the hall boss.
    fn fate_strike(ref world: IWorldDispatcher) -> Result<(), ()>;
}

#[dojo::contract]
mod hazard_hall {
    use super::IHazardHall;

    use starknet::ContractAddress;

    use shard_dungeon::models::inventory::Inventory;
    use shard_dungeon::models::stats::Stats;
    use shard_dungeon::models::dungeon::{Dungeon, DungeonTrait};
    use shard_dungeon::common::utils;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EndOfDungeon: EndOfDungeon,
    }

    // TODO: we may not need data inside this event, as it may only notify
    // the shard operator that the dungeon is over.
    #[derive(Drop, Serde, starknet::Event)]
    struct EndOfDungeon {
        player: ContractAddress,
        has_won: bool,
    }

    #[abi(embed_v0)]
    impl HazardHallImpl of IHazardHall<ContractState> {
        fn enter_dungeon(ref world: IWorldDispatcher) -> Result<(), ()> {
            let player = utils::get_player_address();
            let (inventory, stats, dungeon) = get!(world, player, (Inventory, Stats, Dungeon));

            if dungeon.moves > 0 {
                // The player is already in a dungeon.
                // We can treat this as a player that goes directly to the next dungeon.
                // Without visiting the safehouse and saving progress.
                // But it has potencial to be overwriten by the downstream shard.

                return Result::Err(());
            }

            let dungeon = DungeonTrait::enter(@inventory, @stats);
            set!(world, (dungeon,));

            Result::Ok(())
        }

        fn fate_strike(ref world: IWorldDispatcher) -> Result<(), ()> {
            let player = utils::get_player_address();
            let block_timestamp = starknet::get_block_info().unbox().block_timestamp;

            let has_won_round = block_timestamp % 2 == 0;

            let mut dungeon = get!(world, player, Dungeon);

            if dungeon.moves == 0 {
                // Player is not in the dungeon yet.
                return Result::Err(());
            }

            dungeon.moves += 1;

            if dungeon.gold_in_purse == 0 {
                emit!(world, (Event::EndOfDungeon(EndOfDungeon { player, has_won: false })));
                return Result::Ok(());
            }

            dungeon.gold_in_purse -= 1;

            // Player striked the boss.
            if has_won_round {
                if dungeon.boss_health > 1 {
                    // Player didn't kill the boss yet.
                    dungeon.boss_health -= 1;
                    dungeon.gained_experience += 1;
                } else { // Player killed the boss.
                    dungeon.boss_health = 0;
                    dungeon.gained_experience += 5;
                    dungeon.gold_in_purse += 10;
                    emit!(world, (Event::EndOfDungeon(EndOfDungeon { player, has_won: true })));
                }
            }

            if dungeon.boss_health == 0 {
                let (mut inventory, mut stats) = get!(world, player, (Inventory, Stats));
                let diffs = DungeonTrait::diffs(ref dungeon);

                if inventory.gold < diffs.lost {
                    return Result::Err(());
                }

                inventory.gold -= diffs.lost;
                inventory.gold += diffs.earned;
                stats.experience += diffs.experience;
                set!(world, (inventory, stats, dungeon));
            } else {
                set!(world, (dungeon,));
            }

            Result::Ok(())
        }
    }
}
