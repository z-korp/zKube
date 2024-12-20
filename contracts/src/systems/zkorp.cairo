// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::WorldStorage;

// External imports
use stark_vrf::ecvrf::{Proof, Point, ECVRFTrait};

// Internal imports
use zkube::types::bonus::Bonus;
use zkube::types::mode::Mode;
use zkube::models::settings::{Settings, SettingsTrait};
use zkube::store::{Store, StoreTrait};

#[starknet::interface]
trait IZKorp<T> {
    fn claim(ref self: T);
    fn sponsor(ref self: T, amount: u128);
    fn sponsor_from(ref self: T, amount: u128, caller: ContractAddress);
}

#[dojo::contract]
mod zkorp {
    // Starknet imports
    use starknet::{ContractAddress, ClassHash};
    use starknet::info::{
        get_block_timestamp, get_block_number, get_caller_address, get_contract_address
    };

    // Component imports
    use zkube::components::payable::PayableComponent;

    // Local imports
    use super::{IZKorp, Settings, SettingsTrait, Store, StoreTrait, WorldStorage};
    use zkube::interfaces::ierc20::{ierc20, IERC20Dispatcher, IERC20DispatcherTrait};

    // Components
    component!(path: PayableComponent, storage: payable, event: PayableEvent);
    impl PayableInternalImpl = PayableComponent::InternalImpl<ContractState>;

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        payable: PayableComponent::Storage,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        PayableEvent: PayableComponent::Event,
    }

    // Constructor
    fn dojo_init(ref self: ContractState, token_address: ContractAddress,) {
        // [Effect] Initialize components
        self.payable._initialize(token_address);
    }

    // Implementations
    #[abi(embed_v0)]
    impl ZKorpImpl of IZKorp<ContractState> {
        fn claim(ref self: ContractState) {
            let mut world = self.world_default();
            let store = StoreTrait::new(world);
            let settings = store.settings();

            // [Check] Player exists
            let caller = get_caller_address();
            assert!(caller.into() == settings.zkorp_address, "Caller is not ZKorp");

            let token_address = self.payable.token_address.read();
            let token_dispatcher = ierc20(token_address);
            let claimable = token_dispatcher.balance_of(caller);

            // [Effect] Pay reward
            self.payable._refund(caller, claimable.into());
        }

        fn sponsor_from(ref self: ContractState, amount: u128, caller: ContractAddress) {
            // [Effect] Pay reward
            self.payable._pay(caller, amount.into());
        }

        fn sponsor(ref self: ContractState, amount: u128) {
            // [Effect] Pay reward
            self.sponsor_from(amount, get_caller_address());
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// This function is handy since the ByteArray can't be const.
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(crate::default_namespace())
        }
    }
}
