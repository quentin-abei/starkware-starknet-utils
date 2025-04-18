use core::fmt::Debug;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::byte_array::try_deserialize_bytearray_error;
use snforge_std::cheatcodes::events::Event;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address,
    start_cheat_block_number_global,
};
use starknet::ContractAddress;
use starkware_utils::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use starkware_utils::interfaces::identity::{IdentityDispatcher, IdentityDispatcherTrait};
use starkware_utils_testing::constants as testing_constants;

pub fn set_account_as_security_admin(
    contract: ContractAddress, account: ContractAddress, governance_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: governance_admin);
    roles_dispatcher.register_security_admin(:account);
}

pub fn set_account_as_security_agent(
    contract: ContractAddress, account: ContractAddress, security_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: security_admin);
    roles_dispatcher.register_security_agent(:account);
}

pub fn set_account_as_app_role_admin(
    contract: ContractAddress, account: ContractAddress, governance_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: governance_admin);
    roles_dispatcher.register_app_role_admin(:account);
}

pub fn set_account_as_operator(
    contract: ContractAddress, account: ContractAddress, app_role_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: app_role_admin);
    roles_dispatcher.register_operator(:account);
}

pub fn set_account_as_app_governor(
    contract: ContractAddress, account: ContractAddress, app_role_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: app_role_admin);
    roles_dispatcher.register_app_governor(:account);
}

pub fn set_account_as_upgrade_governor(
    contract: ContractAddress, account: ContractAddress, governance_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: governance_admin);
    roles_dispatcher.register_upgrade_governor(:account);
}

pub fn set_account_as_token_admin(
    contract: ContractAddress, account: ContractAddress, app_role_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: app_role_admin);
    roles_dispatcher.register_token_admin(:account);
}

pub fn set_default_roles(contract: ContractAddress, governance_admin: ContractAddress) {
    set_account_as_app_role_admin(
        :contract, account: testing_constants::APP_ROLE_ADMIN, :governance_admin,
    );
    set_account_as_upgrade_governor(
        :contract, account: testing_constants::UPGRADE_GOVERNOR, :governance_admin,
    );
    set_account_as_app_governor(
        :contract,
        account: testing_constants::APP_GOVERNOR,
        app_role_admin: testing_constants::APP_ROLE_ADMIN,
    );
    set_account_as_operator(
        :contract,
        account: testing_constants::OPERATOR,
        app_role_admin: testing_constants::APP_ROLE_ADMIN,
    );
    set_account_as_token_admin(
        :contract,
        account: testing_constants::TOKEN_ADMIN,
        app_role_admin: testing_constants::APP_ROLE_ADMIN,
    );
    set_account_as_security_admin(
        :contract, account: testing_constants::SECURITY_ADMIN, :governance_admin,
    );
    set_account_as_security_agent(
        :contract,
        account: testing_constants::SECURITY_AGENT,
        security_admin: testing_constants::SECURITY_ADMIN,
    );
}

pub fn cheat_caller_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress,
) {
    cheat_caller_address(:contract_address, :caller_address, span: CheatSpan::TargetCalls(1));
}

pub fn advance_block_number_global(blocks: u64) {
    start_cheat_block_number_global(block_number: starknet::get_block_number() + blocks)
}

pub fn check_identity(
    target: ContractAddress, expected_identity: felt252, expected_version: felt252,
) {
    let identitier = IdentityDispatcher { contract_address: target };
    let identity = identitier.identify();
    let version = identitier.version();
    assert!(expected_identity == identity);
    assert!(expected_version == version);
}

pub fn assert_panic_with_error<T, +Drop<T>>(
    result: Result<T, Array<felt252>>, expected_error: ByteArray,
) {
    match result {
        Result::Ok(_) => panic!("Expected to fail with: {}", expected_error),
        Result::Err(error_data) => assert_expected_error(
            error_data: error_data.span(), :expected_error,
        ),
    };
}

pub fn assert_panic_with_felt_error<T, +Drop<T>>(
    result: Result<T, Array<felt252>>, expected_error: felt252,
) {
    match result {
        Result::Ok(_) => panic!("Expected to fail with: {}", expected_error),
        Result::Err(error_data) => assert!(*error_data[0] == expected_error),
    };
}

pub fn assert_expected_error(error_data: Span<felt252>, expected_error: ByteArray) {
    match try_deserialize_bytearray_error(error_data) {
        Result::Ok(error) => assert!(
            error == expected_error, "Expected error: {}\nActual error: {}", expected_error, error,
        ),
        Result::Err(_) => panic!(
            "Failed to deserialize error data: {:?}.\nExpect to panic with {}.",
            error_data,
            expected_error,
        ),
    }
}

pub fn assert_expected_event_emitted<T, +starknet::Event<T>, +Drop<T>, +Debug<T>, +PartialEq<T>>(
    spied_event: @(ContractAddress, Event),
    expected_event: T,
    expected_event_selector: @felt252,
    expected_event_name: ByteArray,
) {
    let (_, raw_event) = spied_event;
    let mut data = raw_event.data.span();
    let mut keys = raw_event.keys.span();

    // Remove the first key from the spied event's keys. This key corresponds to the
    // `sn_keccak` hash of the event name, which is currently not included in the
    // expected event's keys.
    if keys.pop_front() != Option::Some(expected_event_selector) {
        panic!(
            "The expected event type '{expected_event_name}' does not match the actual event type",
        );
    }

    let actual_event = starknet::Event::<T>::deserialize(ref :keys, ref :data).unwrap();
    assert!(expected_event == actual_event);
}

/// The `TokenConfig` struct is used to configure the initial settings for a token contract.
/// It includes the initial supply of tokens and the owner's address.
#[derive(Drop)]
pub struct TokenConfig {
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub initial_supply: u256,
    pub owner: ContractAddress,
}

/// The `TokenState` struct represents the state of a token contract.
/// It includes the contract address and the owner's address.
#[derive(Drop, Copy)]
pub struct TokenState {
    pub address: ContractAddress,
    pub owner: ContractAddress,
}

pub trait Deployable<T, V> {
    fn deploy(self: @T) -> V;
}

pub impl TokenDeployImpl of Deployable<TokenConfig, TokenState> {
    fn deploy(self: @TokenConfig) -> TokenState {
        let mut calldata = ArrayTrait::new();
        self.name.serialize(ref calldata);
        self.symbol.serialize(ref calldata);
        self.initial_supply.serialize(ref calldata);
        self.owner.serialize(ref calldata);
        let token_contract = snforge_std::declare("DualCaseERC20Mock").unwrap().contract_class();
        let (address, _) = token_contract.deploy(@calldata).unwrap();
        TokenState { address, owner: *self.owner }
    }
}

pub trait TokenTrait<TTokenState> {
    fn fund(self: TTokenState, recipient: ContractAddress, amount: u128);
    fn approve(self: TTokenState, owner: ContractAddress, spender: ContractAddress, amount: u128);
    fn balance_of(self: TTokenState, account: ContractAddress) -> u128;
}

pub impl TokenImpl of TokenTrait<TokenState> {
    fn fund(self: TokenState, recipient: ContractAddress, amount: u128) {
        let erc20_dispatcher = IERC20Dispatcher { contract_address: self.address };
        cheat_caller_address_once(contract_address: self.address, caller_address: self.owner);
        erc20_dispatcher.transfer(recipient: recipient, amount: amount.into());
    }

    fn approve(self: TokenState, owner: ContractAddress, spender: ContractAddress, amount: u128) {
        let erc20_dispatcher = IERC20Dispatcher { contract_address: self.address };
        cheat_caller_address_once(contract_address: self.address, caller_address: owner);
        erc20_dispatcher.approve(spender: spender, amount: amount.into());
    }

    fn balance_of(self: TokenState, account: ContractAddress) -> u128 {
        let erc20_dispatcher = IERC20Dispatcher { contract_address: self.address };
        erc20_dispatcher.balance_of(account: account).try_into().unwrap()
    }
}
