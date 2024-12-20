use core::traits::Into;
use core::Zeroable;
use starknet::testing::{set_contract_address, set_block_timestamp};

use zkube::models::chest::{Chest, ChestTrait, ChestAssert, ZeroableChest};
use zkube::models::participation::{
    Participation, ParticipationTrait, ParticipationAssert, ZeroableParticipation
};
use zkube::store::{Store, StoreTrait};
use zkube::systems::play::IPlayDispatcherTrait;
use zkube::models::settings::{Settings, SettingsTrait};
use zkube::systems::settings::{ISettingsDispatcherTrait, ISettingsDispatcher};
use zkube::types::mode::Mode;
use zkube::constants::{PRECISION_FACTOR, DAILY_MODE_DURATION, CHEST_PERCENTAGE};
use zkube::tests::mocks::erc721::{IERC721MintableDispatcher, IERC721MintableDispatcherTrait};

use zkube::tests::setup::{
    setup,
    setup::{
        Systems, PLAYER1, PLAYER2, PLAYER3, PLAYER4, IERC20DispatcherTrait, IChestDispatcherTrait,
        user_mint_token, admin_mint_token, impersonate
    }
};

fn abs_difference(a: u256, b: u256) -> u256 {
    if a >= b {
        a - b
    } else {
        b - a
    }
}

#[test]
fn test_chest_creation_and_completion() {
    // [Setup]
    let (mut world, systems, context) = setup::create_accounts();
    let erc721_addr = context.erc721.contract_address;
    let erc20_addr = context.erc20.contract_address;
    let store = StoreTrait::new(world);

    let time = DAILY_MODE_DURATION + 1;
    set_block_timestamp(time.into());

    store.chest(1).assert_exists(); // Chest 1 should exist
    store.chest(2).assert_exists(); // Chest 2 should exist
    store.chest(3).assert_exists(); // Chest 3 should not exist
    store.chest(4).assert_exists(); // Chest 4 should not exist
    store.chest(5).assert_exists(); // Chest 5 should not exist
    store.chest(6).assert_exists(); // Chest 6 should not exist
    store.chest(7).assert_exists(); // Chest 7 should not exist
    store.chest(8).assert_exists(); // Chest 8 should not exist
    store.chest(9).assert_exists(); // Chest 9 should not exist
    store.chest(10).assert_exists(); // Chest 10 should not exist

    let mut chest = store.chest(1);
    chest.points = 9_995;
    store.set_chest(chest);

    impersonate(PLAYER1());
    // 1st game
    let player3_balance = context.erc20.balance_of(PLAYER1());
    let token_id = admin_mint_token(erc721_addr, erc20_addr, PLAYER1().into());
    impersonate(PLAYER1());
    let game_id = systems
        .play
        .create(token_id, Mode::Daily, context.proof.clone(), context.seed, context.beta);

    systems.play.move(1, 6, 7);
    systems.play.move(1, 5, 6);
    let game = store.game(game_id);

    assert(game.score == 4, 'Score post move 3');

    systems.play.surrender();

    let chest = store.chest(1);
    println!("Chest points: {}", chest.points);
    assert(chest.points == 9_999, 'Chest1 points should be 9_999');
    assert(!chest.is_complete(), 'Chest1 should not be completed');
    assert(chest.remaining_points() == 1, 'Chest1 remain pts should be 1');

    // 2nd game
    let token_id = admin_mint_token(erc721_addr, erc20_addr, PLAYER1().into());
    impersonate(PLAYER1());
    let game_id = systems
        .play
        .create(token_id, Mode::Daily, context.proof.clone(), context.seed, context.beta);

    systems.play.move(1, 6, 7);
    systems.play.move(1, 5, 6);
    let game = store.game(game_id);

    assert(game.score == 4, 'Score post move 3');
    systems.play.surrender();

    let chest = store.chest(1);
    assert(chest.points == 10_000, 'Chest1 points should be 1_000');
    assert(chest.is_complete(), 'Chest1 should be completed');
    assert(chest.remaining_points() == 0, 'Chest1 remain pts should 0');

    let chest2 = store.chest(2);
    assert(chest2.points == 3, 'Chest2 points should be 3');
    assert(!chest2.is_complete(), 'Chest2 should not be completed');
    assert(chest2.remaining_points() == 24_997, 'Chest2 remain pts be 24997');
}

#[test]
fn test_chest_claim() {
    // [Setup]
    let (mut world, systems, context) = setup::create_accounts();
    let erc721_addr = context.erc721.contract_address;
    let erc20_addr = context.erc20.contract_address;
    let store = StoreTrait::new(world);

    let erc721_mintable = IERC721MintableDispatcher {
        contract_address: context.erc721.contract_address
    };
    let price = erc721_mintable.get_mint_price();

    let time = DAILY_MODE_DURATION + 1;
    set_block_timestamp(time.into());

    // [Create admin]
    impersonate(PLAYER1());
    let settings = store.settings();
    // Now let's finish a chest with 4 players

    impersonate(context.owner);
    let mut chest = store.chest(1);
    chest.points = 9_982;
    store.set_chest(chest);

    // Sponsor the chest
    impersonate(PLAYER1());
    let sponso: u256 = 1000_000_000_000_000_000_000; // 1000 LORDS
    context.erc20.approve(context.chest_address, sponso);
    systems.chest.sponsor_chest(1, sponso.try_into().unwrap());
    let chest_balance = context.erc20.balance_of(context.chest_address);
    println!("Chest balance: {}", chest_balance);
    assert(chest_balance == sponso, 'Wrong chest balance');
    assert(store.chest(1).prize == sponso.try_into().unwrap(), 'Wrong chest prize');

    // Player 1
    let player1_balance = context.erc20.balance_of(PLAYER1());
    let token_id = user_mint_token(context.play_address, erc721_addr, erc20_addr, PLAYER1().into());
    let game_id = systems
        .play
        .create(token_id, Mode::Daily, context.proof.clone(), context.seed, context.beta);
    systems.play.move(1, 6, 7);
    systems.play.surrender(); // 3 points
    let game = store.game(game_id);
    assert(game.score == 3, 'Score should be 3');
    let player1_new_balance = context.erc20.balance_of(PLAYER1());

    // Player 2
    impersonate(PLAYER2());
    let player2_balance = context.erc20.balance_of(PLAYER2());
    let token_id = user_mint_token(context.play_address, erc721_addr, erc20_addr, PLAYER2().into());
    let game_id = systems
        .play
        .create(token_id, Mode::Daily, context.proof.clone(), context.seed, context.beta);
    systems.play.move(1, 6, 7);
    systems.play.move(1, 5, 6);
    systems.play.surrender(); // 4 points
    let game = store.game(game_id);
    assert(game.score == 4, 'Score should be 4');
    let player2_new_balance = context.erc20.balance_of(PLAYER2());

    // Player 3
    impersonate(PLAYER3());
    let player3_balance = context.erc20.balance_of(PLAYER3());
    let token_id = user_mint_token(context.play_address, erc721_addr, erc20_addr, PLAYER3().into());
    let game_id = systems
        .play
        .create(token_id, Mode::Daily, context.proof.clone(), context.seed, context.beta);
    systems.play.move(1, 6, 7);
    systems.play.move(1, 5, 6);
    systems.play.move(2, 2, 1);
    systems.play.surrender(); // 7 points
    let game = store.game(game_id);
    assert(game.score == 7, 'Score should be 7 (1)');
    let player3_new_balance = context.erc20.balance_of(PLAYER3());

    // Player 4
    impersonate(PLAYER4());
    let player4_balance = context.erc20.balance_of(PLAYER4());
    let token_id = user_mint_token(context.play_address, erc721_addr, erc20_addr, PLAYER4().into());
    let game_id = systems
        .play
        .create(token_id, Mode::Daily, context.proof.clone(), context.seed, context.beta);
    systems.play.move(1, 6, 7);
    systems.play.move(1, 5, 6);
    systems.play.move(2, 2, 1);
    systems.play.surrender(); // 7 points
    let game = store.game(game_id);
    assert(game.score == 7, 'Score should be 7 (2)');
    let player4_new_balance = context.erc20.balance_of(PLAYER4());

    // [Assert] Player balances before claiming prizes
    assert(player1_new_balance == player1_balance - price, 'Player1 balance wrong');
    assert(player2_new_balance == player2_balance - price, 'Player2 balance wrong');
    assert(player3_new_balance == player3_balance - price, 'Player3 balance wrong');
    assert(player4_new_balance == player4_balance - price, 'Player4 balance wrong');

    // [Assert] Chest
    let chest = store.chest(1);
    assert(chest.points == 10_000, 'Chest points should be 10_000');
    assert(chest.is_complete(), 'Chest should be completed');
    assert(chest.remaining_points() == 0, 'Chest remain pts should be 0');

    // Calculate the chest prizes
    let prize_per_game = price * CHEST_PERCENTAGE.into() / 100_u256;
    let chest1_game_prize = prize_per_game
        * (3_u256 * 1_000_000_000_000_000_000_000_u256
            + (4_u256 * 1_000_000_000_000_000_000_000_u256) / 7_u256)
        / 1_000_000_000_000_000_000_000_u256;
    let chest2_game_prize = prize_per_game
        * (3_u256 * 1_000_000_000_000_000_000_000_u256)
        / 7_u256
        / 1_000_000_000_000_000_000_000_u256;

    let chest_prize = chest1_game_prize + sponso;
    let chest2 = store.chest(2);
    let chest2_prize = chest2.prize.into();

    // Compute total points in Chest 1 and Chest 2
    let total_points_chest1 = 10_000_u256;
    let total_points_chest2 = 3_u256; // Remaining 3 points from Player 4

    // Compute expected prizes for each player
    // Player 1
    let player1_expected_prize_chest1 = chest_prize * 3_u256 / total_points_chest1;

    // Player 2
    let player2_expected_prize_chest1 = chest_prize * 4_u256 / total_points_chest1;

    // Player 3
    let player3_expected_prize_chest1 = chest_prize * 7_u256 / total_points_chest1;

    // Player 4
    let player4_expected_prize_chest1 = chest_prize * 4_u256 / total_points_chest1;
    let player4_expected_prize_chest2 = chest2_prize * 3_u256 / total_points_chest2;
    let player4_expected_total_prize = player4_expected_prize_chest1
        + player4_expected_prize_chest2;

    // [Assert] Chest balance before all claims
    let chest_balance_before_claims = context.erc20.balance_of(context.chest_address);
    println!("Chest balance before claims: {}", chest_balance_before_claims);

    let total_prize_added_in_chest_1: u256 = sponso
        + 3_u256 * prize_per_game
        + (4_u256 * prize_per_game) / 7_u256;
    println!("Total prize added in chest 1: {}", total_prize_added_in_chest_1);
    println!("player4_expected_prize_chest2: {}", player4_expected_prize_chest2);
    println!(
        "total_prize_added_in_chest_1 + player4_expected_prize_chest2: {}",
        total_prize_added_in_chest_1 + player4_expected_prize_chest2
    );
    println!("sponso: {}", sponso);
    println!("prize_per_game: {}", prize_per_game);
    assert(
        abs_difference(
            chest_balance_before_claims,
            total_prize_added_in_chest_1 + player4_expected_prize_chest2
        ) < 5_000_000_000_000,
        'Wrong chest balance',
    );

    // [Assert] Player balances after claiming prizes
    // Player 1
    impersonate(PLAYER1());
    systems.chest.claim(1);
    let player1_balance_after_claim = context.erc20.balance_of(PLAYER1());
    assert(
        abs_difference(
            player1_balance_after_claim, player1_balance + player1_expected_prize_chest1 - price
        ) < 5_000_000_000_000,
        'P1 balance wrong after claim',
    );

    // Player 2
    impersonate(PLAYER2());
    systems.chest.claim(1);
    let player2_balance_after_claim = context.erc20.balance_of(PLAYER2());
    assert(
        abs_difference(
            player2_balance_after_claim, player2_balance + player2_expected_prize_chest1 - price
        ) < 5_000_000_000_000,
        'P2 balance wrong after claim',
    );

    // Player 3
    impersonate(PLAYER3());
    systems.chest.claim(1);
    let player3_balance_after_claim = context.erc20.balance_of(PLAYER3());
    assert(
        abs_difference(
            player3_balance_after_claim, player3_balance + player3_expected_prize_chest1 - price
        ) < 5_000_000_000_000,
        'P3 balance wrong after claim',
    );

    // Player 4
    impersonate(PLAYER4());
    systems.chest.claim(1);
    let player4_balance_after_claim = context.erc20.balance_of(PLAYER4());
    assert(
        abs_difference(
            player4_balance_after_claim, player4_balance + player4_expected_prize_chest1 - price
        ) < 5_000_000_000_000,
        'P4 balance wrong after claim',
    );

    // [Assert] Chest balance after all claims
    let chest_balance_after_claims = context.erc20.balance_of(context.chest_address);
    println!("Chest balance after claims: {}", chest_balance_after_claims);
    let init_point_part_prize = total_prize_added_in_chest_1
        * 9_982
        / 10_000; // we compute the part corresponding to the points
    // that we added at the beginning, that have not been claimed yet
    assert(
        abs_difference(
            chest_balance_after_claims, init_point_part_prize + player4_expected_prize_chest2
        ) < 5_000_000_000_000,
        'Wrong chest balance',
    );
}

