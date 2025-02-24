#[starknet::interface]
trait IContractMe<TContractState> {
	fn action_cost(self: @TContractState) -> u256;
	fn prize_pool(self: @TContractState) -> u256;
	fn buyin(ref self: TContractState);
	fn fundme(ref self: TContractState, amount: u256);
	fn payout(ref self: TContractState, recepient: core::starknet::ContractAddress, amount: u256);
	fn reset_cost(ref self: TContractState) -> u256;
	fn drain(ref self: TContractState);
}

#[starknet::contract]
mod ContractMe {
	use starknet::{ContractAddress, get_caller_address, get_contract_address, ClassHash};
	use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
	use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
	use openzeppelin::access::ownable::OwnableComponent;
	use openzeppelin::upgrades::UpgradeableComponent;
	use openzeppelin::upgrades::interface::IUpgradeable;

	component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
	component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

	#[abi(embed_v0)]
	impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

	impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
	impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

	const STRK_ADDR: felt252 = 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;

	const START_COST: u256 = 4_000_000_000_000_000_000; // 4 STRK
	const INCREMENT:  u256 =   250_000_000_000_000_000;

	#[storage]
	struct Storage {
		action_cost: u256,
		prize_pool: u256,
		#[substorage(v0)]
		ownable: OwnableComponent::Storage,
		#[substorage(v0)]
		upgradeable: UpgradeableComponent::Storage,
	}

	#[event]
	#[derive(Drop, starknet::Event)]
	enum Event {
		BuyIn: BuyIn,
		#[flat]
		OwnableEvent: OwnableComponent::Event,
		#[flat]
		UpgradeableEvent: UpgradeableComponent::Event,
	}

	#[derive(Drop, starknet::Event)]
	struct BuyIn {
		caller: ContractAddress,
		amount: u256,
		new_prize_pool: u256,
	}

	#[constructor]
	fn constructor(ref self: ContractState, owner: ContractAddress) {
		self.action_cost.write(START_COST);
		self.prize_pool.write(0_u256);
		self.ownable.initializer(owner);
	}

	#[abi(embed_v0)]
	impl ContractMeImpl of super::IContractMe<ContractState> {
		fn action_cost(self: @ContractState) -> u256 {
			self.action_cost.read()
		}

		fn prize_pool(self: @ContractState) -> u256 {
			self.prize_pool.read()
		}

		fn buyin(ref self: ContractState) {
			let caller: ContractAddress = get_caller_address();
			let contract: ContractAddress = get_contract_address();
			let strk_token = IERC20Dispatcher { contract_address: STRK_ADDR.try_into().unwrap() };

			let pool: u256 = self.prize_pool.read();
			let cost: u256 = self.action_cost.read();
			let new_pool: u256 = pool + cost;
			let new_cost: u256 = cost + INCREMENT;

			assert(new_pool > pool, 'Prize pool overflow');
			assert(new_cost > cost, 'Action cost increase overflow');

			let caller_balance = strk_token.balance_of(caller);
			assert(caller_balance >= cost, 'Insufficient balance');
			assert(strk_token.allowance(contract) >= cost, 'Insufficient allowance');
			assert(strk_token.transfer_from(caller, contract, cost), 'Fee transfer failed');
			self.prize_pool.write(new_pool);
			self.emit(Event::BuyIn(BuyIn {
				caller,
				amount: cost,
				new_prize_pool: new_pool
			}));
			self.action_cost.write(new_cost);
		}

		fn fundme(ref self: ContractState, amount: u256) {
			assert(amount > 0, 'Amount must be more than zero');

			let caller: ContractAddress = get_caller_address();
			let contract: ContractAddress = get_contract_address();
			let strk_token = IERC20Dispatcher { contract_address: STRK_ADDR.try_into().unwrap() };

			let new_pool: u256 = self.prize_pool.read() + amount;
			assert(new_pool > self.prize_pool.read(), 'Funding would overflow');

			let caller_balance = strk_token.balance_of(caller);
			assert(caller_balance >= amount, 'Insufficient balance');
			assert(strk_token.allowance() >= amount, 'Insufficient allowance');
			assert(strk_token.transfer_from(caller, contract, amount), 'Funding transfer failed');
			self.prize_pool.write(new_pool);
		}

		fn payout(ref self: ContractState, recepient: ContractAddress, amount: u256) {
			self.ownable.assert_only_owner();
			assert(amount > 0, 'Amount must be more than zero');

			let strk_token = IERC20Dispatcher { contract_address: STRK_ADDR.try_into().unwrap() };

			assert(self.prize_pool.read() >= amount, 'Insufficient funds');
			assert(strk_token.transfer(recepient, amount), 'Payout transfer failed');
			self.prize_pool.write(self.prize_pool.read() - amount);
		}

		fn reset_cost(ref self: ContractState) -> u256 {
			self.ownable.assert_only_owner();
			self.action_cost.write(START_COST);
			self.action_cost.read()
		}

		fn drain(ref self: ContractState) {
			self.ownable.assert_only_owner();

			let strk_token = IERC20Dispatcher { contract_address: STRK_ADDR.try_into().unwrap() };
			let owner = self.ownable.owner();
			let funds = strk_token.balance_of(get_contract_address());
			assert(strk_token.transfer(owner, funds), 'Drain transfer failed');
			self.prize_pool.write(0_u256);
			self.reset_cost();
		}
	}

	#[abi(embed_v0)]
	impl UpgradeableImpl of IUpgradeable<ContractState> {
		fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
			self.ownable.assert_only_owner();
			self.upgradeable.upgrade(new_class_hash);
		}
	}
}
