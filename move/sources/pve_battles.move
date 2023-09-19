module owner_addr::pve_battles {
  use std::signer;
  use std::bcs;
  use std::vector;
  use std::string::{ Self, String };

  use aptos_std::math64;
  use aptos_std::type_info::{ Self, TypeInfo };
  use aptos_std::simple_map::{ Self, SimpleMap };

  use aptos_framework::account;
  use aptos_framework::resource_account;
  use aptos_framework::timestamp;
  use aptos_framework::managed_coin;
  use aptos_framework::coin::{ Self };
  use aptos_framework::event::{ Self, EventHandle };

  use owner_addr::deploy_coin::deploy_coin;
  use owner_addr::mint_coins::{ Wood, Stone };

  struct UnitCoin<phantom X> has store {}

  struct AdminData has key {
    signer_cap: account::SignerCapability,
  }

  struct Unit has copy, store, key {
    name: String,
    description: String,
    image_url: String,
    attack: u64,
    health: u64,
    // linked coin to this unit
    linked_coin_type: String,
  }

  struct UnitContract has drop, copy, store, key {
    unit_id: u64,
    unit_type: String,
    coin_address: address,
    resource_type_info: TypeInfo,
    fixed_price: u64,
  }

  struct EnemyLevel has drop, copy, store, key {
    name: String,
    attack: u64,
    health: u64,
    reward_coin_types: vector<String>,
    reward_coin_amounts: vector<u64>,
  }

  struct UnitContracts has key {
    // contract_id - u64
    map: SimpleMap<u64, UnitContract>
  }

  struct Units has key {
    // unit_id - u64
    map: SimpleMap<u64, Unit>
  }

  struct EnemyLevels has key {
    // level_id - u64
    map: SimpleMap<u64, EnemyLevel>
  }

  struct UnitsPurchasedEvent has drop, store {
    unit_id: u64,
    number_of_units: u64,
    total_cost: u64,
    resource_type: TypeInfo,
  }

  struct EnemyAttackedEvent has drop, store {
    enemy_level_id: u64,
    total_units_attack: u64,
    total_units_health: u64,
    result: String,
  }

  struct Events has key {
    units_purchased_event: EventHandle<UnitsPurchasedEvent>,
    enemy_attacked_event: EventHandle<EnemyAttackedEvent>,
  }

  const E_NO_UNITS_EXISTS: u64 = 1;
  const E_NO_UNIT_IN_UNITS: u64 = 2;
  const E_NO_UNIT_CONTRACTS_EXISTS: u64 = 3;
  const E_NO_CONTRACT_IN_CONTRACTS: u64 = 4;
  const E_INVALID_COIN_TYPE: u64 = 5;
  const E_INSUFFICIENT_COIN_BALANCE: u64 = 6;
  const E_INVALID_COIN_AMOUNT: u64 = 7;
  const E_NO_ADMIN_DATA: u64 = 8;
  const E_NO_ENEMY_LEVELS_EXISTS: u64 = 9;
  const E_NO_ENEMY_LEVEL: u64 = 10;
  const E_INVALID_ADDRESS_FOR_MINT: u64 = 11;
  const E_INVALID_ACCESS_RIGHTS: u64 = 12;

  // save signer_cap to AdminData
  fun init_module(resource_signer: &signer) {
    let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @source_addr);

    move_to(resource_signer, AdminData {
      signer_cap: resource_signer_cap,
    });
  }

  fun init_events(account: &signer) {
    let account_addr = signer::address_of(account);

    if (!exists<Events>(account_addr)) {
      move_to(account, Events {
        units_purchased_event: account::new_event_handle<UnitsPurchasedEvent>(account),
        enemy_attacked_event: account::new_event_handle<EnemyAttackedEvent>(account)
      });
    }
  }

  fun create_and_add_unit(
    account: &signer, name: String, description: String, image_url: String, attack: u64, health: u64, linked_coin_type: String,
  ) acquires Units {
    let account_addr = signer::address_of(account);
    if (!exists<Units>(account_addr)) {
      move_to(account, Units { map: simple_map::create() })
    };
    let units_data = borrow_global_mut<Units>(account_addr);
    let number_of_units = simple_map::length(&units_data.map);
    let unit_id = number_of_units + 1;
    
    simple_map::add(&mut units_data.map, unit_id, Unit {
      name,
      description,
      image_url,
      attack,
      health,
      linked_coin_type,
    });
  }

  fun create_and_add_unit_contracts(
    account: &signer, unit_id: u64, unit_type: String, coin_address: address, resource_type_info: TypeInfo, fixed_price: u64
  ) acquires UnitContracts {
    let account_addr = signer::address_of(account);
    if (!exists<UnitContracts>(account_addr)) {
      move_to(account, UnitContracts { map: simple_map::create() })
    };
    let unit_contracts_data = borrow_global_mut<UnitContracts>(account_addr);
    
    // dont allow to create 2 different contracts for same unit_id
    simple_map::add(&mut unit_contracts_data.map, unit_id, UnitContract {
      unit_id,
      unit_type,
      coin_address,
      resource_type_info,
      fixed_price
    });
  }

  fun get_resource_signer():signer acquires AdminData {
    let admin_data = borrow_global<AdminData>(@owner_addr);
    account::create_signer_with_capability(&admin_data.signer_cap)
  } 

  // return address of CoinType coin
  fun coin_address<CoinType>(): address {
    let type_info = type_info::type_of<CoinType>();
    type_info::account_address(&type_info)
  }

  public entry fun create_unit_type(coin_seed: String) acquires AdminData {
    // deploy new module with "struct T has key {}" on new package name
    let resource_signer = get_resource_signer();
    deploy_coin(&resource_signer, coin_seed);
  }

  // create new unit (coin) and push to Units map
  public entry fun create_unit<CoinType>(
    creator: &signer, name: String, description: String, image_url: String, attack: u64, health: u64,
  ) acquires Units, AdminData {
    let unit_name_in_bytes = bcs::to_bytes(&name);
    vector::remove(&mut unit_name_in_bytes, 0);

    let resource_signer = get_resource_signer();

    managed_coin::initialize<UnitCoin<CoinType>>(
      &resource_signer,
      unit_name_in_bytes,
      unit_name_in_bytes,
      8,
      true,
    );
    managed_coin::register<UnitCoin<CoinType>>(creator);
    managed_coin::register<UnitCoin<CoinType>>(&resource_signer);

    create_and_add_unit(creator, name, description, image_url, attack, health, type_info::type_name<UnitCoin<CoinType>>());
  }

  public entry fun create_unit_contract<CoinType, UnitType>(creator: &signer, unit_id: u64, fixed_price: u64) acquires UnitContracts, Units {
    let creator_addr = signer::address_of(creator);

    // check if creator has Units
    assert!(exists<Units>(creator_addr), E_NO_UNITS_EXISTS);
    let units_data = borrow_global<Units>(creator_addr);

    // check if unit contains in Units
    assert!(simple_map::contains_key(&units_data.map, &unit_id), E_NO_UNIT_IN_UNITS);

    create_and_add_unit_contracts(
      creator,
      unit_id,
      type_info::type_name<UnitType>(),
      coin_address<CoinType>(),
      type_info::type_of<CoinType>(),
      fixed_price,
    );
  }

  public entry fun remove_unit_contract(creator: &signer, contract_id: u64) acquires UnitContracts {
    let creator_addr = signer::address_of(creator);

    // check if creator has UnitContracts
    assert!(exists<UnitContracts>(creator_addr), E_NO_UNIT_CONTRACTS_EXISTS);
    let unit_contracts_data = borrow_global_mut<UnitContracts>(creator_addr);

    // check if contract contains in UnitContracts
    assert!(simple_map::contains_key(&unit_contracts_data.map, &contract_id), E_NO_CONTRACT_IN_CONTRACTS);

    simple_map::remove(&mut unit_contracts_data.map, &contract_id);
  }

  public entry fun buy_units<CoinType, UnitType>(
    user: &signer, contract_id: u64, coins_amount: u64, number_of_units: u64,
  ) acquires UnitContracts, AdminData, Events {
    let user_addr = signer::address_of(user);

    assert!(exists<UnitContracts>(@source_addr), E_NO_UNIT_CONTRACTS_EXISTS);
    let unit_contracts_data = borrow_global<UnitContracts>(@source_addr);

    // check if such contracts exists
    assert!(simple_map::contains_key(&unit_contracts_data.map, &contract_id), E_NO_CONTRACT_IN_CONTRACTS);
    let contract_data = simple_map::borrow(&unit_contracts_data.map, &contract_id);

    // check if passed CoinType equal to saved CoinType
    assert!(coin_address<CoinType>() == type_info::account_address(&contract_data.resource_type_info), E_INVALID_COIN_TYPE); 

    // based on fixed price in contract - calculate number of unit need to be mint
    let unit_coin_decimals = coin::decimals<UnitType>();
    let number_of_units_with_decimals = number_of_units * math64::pow(10, (unit_coin_decimals as u64 ));

    let total_cost = number_of_units_with_decimals * contract_data.fixed_price;

    // check if user has enough coins
    assert!(coin::balance<CoinType>(user_addr) >= total_cost, E_INSUFFICIENT_COIN_BALANCE);
    assert!(total_cost == coins_amount, E_INVALID_COIN_AMOUNT);

    // send coins from user to module owner
    coin::transfer<CoinType>(user, @owner_addr, total_cost);

    // mint new coins based on type and send to user address
    if (!coin::is_account_registered<UnitType>(user_addr)) {
      coin::register<UnitType>(user);
    };

    let resource_signer = get_resource_signer();

    managed_coin::mint<UnitType>(&resource_signer, user_addr, number_of_units_with_decimals);

    init_events(user);

    let events = borrow_global_mut<Events>(user_addr);

    // trigger units purchased event
    event::emit_event(
      &mut events.units_purchased_event,
      UnitsPurchasedEvent {
        unit_id: contract_data.unit_id,
        number_of_units: number_of_units_with_decimals,
        total_cost,
        resource_type: contract_data.resource_type_info,
      },
    );
  }


  // add new enemy level
  public entry fun create_enemy_level<CoinType>(
    creator: &signer, name: String, attack: u64, health: u64, reward_coin_amount: u64,
  ) acquires EnemyLevels {
    let creator_addr = signer::address_of(creator);

    if (!exists<EnemyLevels>(creator_addr)) {
      move_to(creator, EnemyLevels { map: simple_map::create() })
    };
    let enemy_levels_data = borrow_global_mut<EnemyLevels>(creator_addr);
    let new_enemy_level_id = timestamp::now_seconds();
    let reward_coin_type = type_info::type_name<CoinType>();

    let reward_coin_types = vector::empty();
    vector::push_back<String>(&mut reward_coin_types, reward_coin_type);

    let reward_coin_amounts = vector::empty();
    vector::push_back<u64>(&mut reward_coin_amounts, reward_coin_amount);

    simple_map::add(&mut enemy_levels_data.map, new_enemy_level_id, EnemyLevel {
      name,
      attack,
      health,
      reward_coin_types,
      reward_coin_amounts,
    });
  }

  public entry fun create_enemy_level_with_two_reward_coins<CoinType1, CoinType2>(
    creator: &signer, name: String, attack: u64, health: u64, reward_coin_1_amount: u64, reward_coin_2_amount: u64,
  ) acquires EnemyLevels {
    let creator_addr = signer::address_of(creator);

    if (!exists<EnemyLevels>(creator_addr)) {
      move_to(creator, EnemyLevels { map: simple_map::create() })
    };
    let enemy_levels_data = borrow_global_mut<EnemyLevels>(creator_addr);
    let new_enemy_level_id = timestamp::now_seconds();
    let reward_coin_1_type = type_info::type_name<CoinType1>();
    let reward_coin_2_type = type_info::type_name<CoinType2>();

    let reward_coin_types = vector::empty();
    vector::push_back<String>(&mut reward_coin_types, reward_coin_1_type);
    vector::push_back<String>(&mut reward_coin_types, reward_coin_2_type);


    let reward_coin_amounts = vector::empty();
    vector::push_back<u64>(&mut reward_coin_amounts, reward_coin_1_amount);
    vector::push_back<u64>(&mut reward_coin_amounts, reward_coin_2_amount);

    simple_map::add(&mut enemy_levels_data.map, new_enemy_level_id, EnemyLevel {
      name,
      attack,
      health,
      reward_coin_types,
      reward_coin_amounts,
    });
  }

  public entry fun remove_enemy_level(creator: &signer, enemy_level_id: u64) acquires EnemyLevels {
    let creator_addr = signer::address_of(creator);
    assert!(creator_addr == @source_addr, E_INVALID_ACCESS_RIGHTS);

    // check if creator has EnemyLevels
    assert!(exists<EnemyLevels>(@source_addr), E_NO_ENEMY_LEVELS_EXISTS);
    let enemy_levels_data = borrow_global_mut<EnemyLevels>(@source_addr);

    // check if contract contains in EnemyLevels
    assert!(simple_map::contains_key(&enemy_levels_data.map, &enemy_level_id), E_NO_ENEMY_LEVEL);

    simple_map::remove(&mut enemy_levels_data.map, &enemy_level_id);
  }

  // Battle Logic:
  // if attacker win a battle -> mint/transafer to his address amount of reward coin based on reward type
  // if attacker loose - remove/burn some amount of his units and return the rest
  // 
  // for basic version we can caclulate total attack and total health
  // to WIN:
  // 1. total user units health value should be bigger than enemy attack value 
  // 2. total user units attack value should be bigger than enemy health value 
  public entry fun attack_enemy_with_one_unit_one_reward<RewardCoinType, UnitType>(
    user: &signer, enemy_level_id: u64, number_of_units: u64, unit_id: u64,
  ) acquires EnemyLevels, Units, AdminData, Events {
    let user_addr = signer::address_of(user);
    // read enemy_level data 
    assert!(exists<EnemyLevels>(@source_addr), E_NO_ENEMY_LEVELS_EXISTS);
    let enemy_levels_data = borrow_global<EnemyLevels>(@source_addr);

    assert!(simple_map::contains_key(&enemy_levels_data.map, &enemy_level_id), E_NO_ENEMY_LEVEL);
    let enemy_level_data = *simple_map::borrow<u64, EnemyLevel>(&enemy_levels_data.map, &enemy_level_id);
    
    // read units data 
    let units_data = borrow_global<Units>(@source_addr);

    assert!(simple_map::contains_key(&units_data.map, &unit_id), E_NO_UNIT_IN_UNITS);
    let unit_data = simple_map::borrow(&units_data.map, &unit_id);
    // @todo: double check if passed UnitType is equal to saved UnitType in unit_data
    // so user cannot send some shit coins and try to win

    let unit_coin_decimals = coin::decimals<UnitType>();
    let number_of_units_without_decimals = number_of_units / math64::pow(10, (unit_coin_decimals as u64 ));

    // calculate total health and total attack value for units 
    let total_units_attack = number_of_units_without_decimals * unit_data.attack;
    let total_units_health = number_of_units_without_decimals * unit_data.health;

    let resource_signer = get_resource_signer();

    let result;

    if (total_units_attack >= enemy_level_data.health && total_units_health >= enemy_level_data.attack) {
      // win
      // burn half of units
      coin::transfer<UnitType>(user, @owner_addr, number_of_units / 2);
      managed_coin::burn<UnitType>(&resource_signer, number_of_units / 2);

      let reward_coin_decimals = coin::decimals<RewardCoinType>();
      let reward_coin_amount = vector::borrow(&enemy_level_data.reward_coin_amounts, 0);
      let reward_amount_with_decimals = *reward_coin_amount * math64::pow(10, (reward_coin_decimals as u64 ));

      managed_coin::mint<RewardCoinType>(&resource_signer, user_addr, reward_amount_with_decimals); 
      result = string::utf8(b"Win");
    } else {
      // loose battle
      // burn all units
      coin::transfer<UnitType>(user, @owner_addr, number_of_units / 2);
      managed_coin::burn<UnitType>(&resource_signer, number_of_units);
      result = string::utf8(b"Loose");
    };

    let events = borrow_global_mut<Events>(user_addr);  

    // trigger units purchased event
    event::emit_event(
      &mut events.enemy_attacked_event,
      EnemyAttackedEvent {
        enemy_level_id,
        total_units_attack,
        total_units_health,
        result,
      },
    );
  }

  public entry fun attack_enemy_with_one_unit_two_reward<RewardCoin1Type, RewardCoin2Type, UnitType>(
    user: &signer, enemy_level_id: u64, number_of_units: u64, unit_id: u64,
  ) acquires EnemyLevels, Units, AdminData, Events {
    let user_addr = signer::address_of(user);
    // read enemy_level data 
    assert!(exists<EnemyLevels>(@source_addr), E_NO_ENEMY_LEVELS_EXISTS);
    let enemy_levels_data = borrow_global<EnemyLevels>(@source_addr);

    assert!(simple_map::contains_key(&enemy_levels_data.map, &enemy_level_id), E_NO_ENEMY_LEVEL);
    let enemy_level_data = *simple_map::borrow<u64, EnemyLevel>(&enemy_levels_data.map, &enemy_level_id);
    
    // read units data 
    let units_data = borrow_global<Units>(@source_addr);

    assert!(simple_map::contains_key(&units_data.map, &unit_id), E_NO_UNIT_IN_UNITS);
    let unit_data = simple_map::borrow(&units_data.map, &unit_id);
    // @todo: double check if passed UnitType is equal to saved UnitType in unit_data
    // so user cannot send some shit coins and try to win

    let unit_coin_decimals = coin::decimals<UnitType>();
    let number_of_units_without_decimals = number_of_units / math64::pow(10, (unit_coin_decimals as u64 ));

    // calculate total health and total attack value for units 
    let total_units_attack = number_of_units_without_decimals * unit_data.attack;
    let total_units_health = number_of_units_without_decimals * unit_data.health;

    let resource_signer = get_resource_signer();

    let result;

    if (total_units_attack >= enemy_level_data.health && total_units_health >= enemy_level_data.attack) {
      // win
      // burn half of units
      coin::transfer<UnitType>(user, @owner_addr, number_of_units / 2);
      managed_coin::burn<UnitType>(&resource_signer, number_of_units / 2);

      let reward_coin_1_decimals = coin::decimals<RewardCoin1Type>();
      let reward_coin_2_decimals = coin::decimals<RewardCoin2Type>();
      
      let reward_coin_1_amount = vector::borrow(&enemy_level_data.reward_coin_amounts, 0);
      let reward_coin_2_amount = vector::borrow(&enemy_level_data.reward_coin_amounts, 1);

      let reward_amount_1_with_decimals = *reward_coin_1_amount * math64::pow(10, (reward_coin_1_decimals as u64 ));
      let reward_amount_2_with_decimals = *reward_coin_2_amount * math64::pow(10, (reward_coin_2_decimals as u64 ));

      // mint reward coins to user as he win
      managed_coin::mint<RewardCoin1Type>(&resource_signer, user_addr, reward_amount_1_with_decimals);
      managed_coin::mint<RewardCoin2Type>(&resource_signer, user_addr, reward_amount_2_with_decimals);
      result = string::utf8(b"Win");
    } else {
      // loose
      // burn all units
      coin::transfer<UnitType>(user, @owner_addr, number_of_units / 2);
      managed_coin::burn<UnitType>(&resource_signer, number_of_units);
      result = string::utf8(b"Loose");
    };

    let events = borrow_global_mut<Events>(user_addr);  

    // trigger enemy attacked event
    event::emit_event(
      &mut events.enemy_attacked_event,
      EnemyAttackedEvent {
        enemy_level_id,
        total_units_attack,
        total_units_health,
        result,
      },
    );
  }

  public entry fun attack_enemy_with_two_units_one_reward<RewardCoinType, UnitType1, UnitType2>(
    user: &signer, enemy_level_id: u64, number_of_units_1: u64, number_of_units_2: u64, unit_id_1: u64, unit_id_2: u64,
  ) acquires EnemyLevels, Units, AdminData, Events {
    let user_addr = signer::address_of(user);
    // read enemy_level data 
    assert!(exists<EnemyLevels>(@source_addr), E_NO_ENEMY_LEVELS_EXISTS);
    let enemy_levels_data = borrow_global<EnemyLevels>(@source_addr);

    assert!(simple_map::contains_key(&enemy_levels_data.map, &enemy_level_id), E_NO_ENEMY_LEVEL);
    let enemy_level_data = *simple_map::borrow<u64, EnemyLevel>(&enemy_levels_data.map, &enemy_level_id);
    
    // read units data 
    let units_data = borrow_global<Units>(@source_addr);

    assert!(simple_map::contains_key(&units_data.map, &unit_id_1), E_NO_UNIT_IN_UNITS);
    assert!(simple_map::contains_key(&units_data.map, &unit_id_2), E_NO_UNIT_IN_UNITS);
    
    let unit_1_data = simple_map::borrow(&units_data.map, &unit_id_1);
    let unit_2_data = simple_map::borrow(&units_data.map, &unit_id_2);
    // @todo: double check if passed UnitType1 is equal to saved UnitType1 in unit_data and check UnitType2
    // so user cannot send some shit coins and try to win

    let unit_1_coin_decimals = coin::decimals<UnitType1>();
    let number_of_units_1_without_decimals = number_of_units_1 / math64::pow(10, (unit_1_coin_decimals as u64 ));
    let unit_2_coin_decimals = coin::decimals<UnitType2>();
    let number_of_units_2_without_decimals = number_of_units_2 / math64::pow(10, (unit_2_coin_decimals as u64 ));


    // calculate total health and total attack value for units 
    let total_units_1_attack = number_of_units_1_without_decimals * unit_1_data.attack;
    let total_units_1_health = number_of_units_1_without_decimals * unit_1_data.health;
    let total_units_2_attack = number_of_units_2_without_decimals * unit_2_data.attack;
    let total_units_2_health = number_of_units_2_without_decimals * unit_2_data.health;
    
    let total_units_attack = total_units_1_attack + total_units_2_attack;
    let total_units_health = total_units_1_health + total_units_2_health;

    let resource_signer = get_resource_signer();

    let result;

    if (total_units_attack >= enemy_level_data.health && total_units_health >= enemy_level_data.attack) {
      // win
      // burn half of units
      coin::transfer<UnitType1>(user, @owner_addr, number_of_units_1 / 2);
      managed_coin::burn<UnitType1>(&resource_signer, number_of_units_1 / 2);

      coin::transfer<UnitType2>(user, @owner_addr, number_of_units_2 / 2);
      managed_coin::burn<UnitType2>(&resource_signer, number_of_units_2 / 2);

      let reward_coin_decimals = coin::decimals<RewardCoinType>();
      let reward_coin_amount = vector::borrow(&enemy_level_data.reward_coin_amounts, 0);
      let reward_amount_with_decimals = *reward_coin_amount * math64::pow(10, (reward_coin_decimals as u64 ));
      // mint reward coins
      managed_coin::mint<RewardCoinType>(&resource_signer, user_addr, reward_amount_with_decimals);
      result = string::utf8(b"Win");
    } else {
      // loose battle
      // burn all units
      coin::transfer<UnitType1>(user, @owner_addr, number_of_units_1);
      managed_coin::burn<UnitType1>(&resource_signer, number_of_units_1);

      coin::transfer<UnitType2>(user, @owner_addr, number_of_units_2);
      managed_coin::burn<UnitType2>(&resource_signer, number_of_units_2);
      result = string::utf8(b"Loose");
    };

    let events = borrow_global_mut<Events>(user_addr);  

    // trigger enemy attacked event
    event::emit_event(
      &mut events.enemy_attacked_event,
      EnemyAttackedEvent {
        enemy_level_id,
        total_units_attack,
        total_units_health,
        result,
      },
    );
  }

   public entry fun attack_enemy_with_two_units_two_reward<RewardCoin1Type, RewardCoin2Type, UnitType1, UnitType2>(
    user: &signer, enemy_level_id: u64, number_of_units_1: u64, number_of_units_2: u64, unit_id_1: u64, unit_id_2: u64,
  ) acquires EnemyLevels, Units, AdminData, Events {
    let user_addr = signer::address_of(user);
    // read enemy_level data 
    assert!(exists<EnemyLevels>(@source_addr), E_NO_ENEMY_LEVELS_EXISTS);
    let enemy_levels_data = borrow_global<EnemyLevels>(@source_addr);

    assert!(simple_map::contains_key(&enemy_levels_data.map, &enemy_level_id), E_NO_ENEMY_LEVEL);
    let enemy_level_data = *simple_map::borrow<u64, EnemyLevel>(&enemy_levels_data.map, &enemy_level_id);
    
    // read units data 
    let units_data = borrow_global<Units>(@source_addr);

    assert!(simple_map::contains_key(&units_data.map, &unit_id_1), E_NO_UNIT_IN_UNITS);
    assert!(simple_map::contains_key(&units_data.map, &unit_id_2), E_NO_UNIT_IN_UNITS);
    
    let unit_1_data = simple_map::borrow(&units_data.map, &unit_id_1);
    let unit_2_data = simple_map::borrow(&units_data.map, &unit_id_2);
    // @todo: double check if passed UnitType1 is equal to saved UnitType1 in unit_data and check UnitType2
    // so user cannot send some shit coins and try to win

    let unit_1_coin_decimals = coin::decimals<UnitType1>();
    let number_of_units_1_without_decimals = number_of_units_1 / math64::pow(10, (unit_1_coin_decimals as u64 ));
    let unit_2_coin_decimals = coin::decimals<UnitType2>();
    let number_of_units_2_without_decimals = number_of_units_2 / math64::pow(10, (unit_2_coin_decimals as u64 ));


    // calculate total health and total attack value for units 
    let total_units_1_attack = number_of_units_1_without_decimals * unit_1_data.attack;
    let total_units_1_health = number_of_units_1_without_decimals * unit_1_data.health;
    let total_units_2_attack = number_of_units_2_without_decimals * unit_2_data.attack;
    let total_units_2_health = number_of_units_2_without_decimals * unit_2_data.health;
    
    let total_units_attack = total_units_1_attack + total_units_2_attack;
    let total_units_health = total_units_1_health + total_units_2_health;

    let resource_signer = get_resource_signer();

    let result;

    if (total_units_attack >= enemy_level_data.health && total_units_health >= enemy_level_data.attack) {
      // win
      // burn half of units 
      coin::transfer<UnitType1>(user, @owner_addr, number_of_units_1 / 2);
      managed_coin::burn<UnitType1>(&resource_signer, number_of_units_1 / 2);

      coin::transfer<UnitType2>(user, @owner_addr, number_of_units_2 / 2);
      managed_coin::burn<UnitType2>(&resource_signer, number_of_units_2 / 2);

      let reward_coin_1_decimals = coin::decimals<RewardCoin1Type>();
      let reward_coin_2_decimals = coin::decimals<RewardCoin2Type>();
      
      let reward_coin_1_amount = vector::borrow(&enemy_level_data.reward_coin_amounts, 0);
      let reward_coin_2_amount = vector::borrow(&enemy_level_data.reward_coin_amounts, 1);

      let reward_amount_1_with_decimals = *reward_coin_1_amount * math64::pow(10, (reward_coin_1_decimals as u64 ));
      let reward_amount_2_with_decimals = *reward_coin_2_amount * math64::pow(10, (reward_coin_2_decimals as u64 ));

      // mint reward coins to user as he win
      managed_coin::mint<RewardCoin1Type>(&resource_signer, user_addr, reward_amount_1_with_decimals);
      managed_coin::mint<RewardCoin2Type>(&resource_signer, user_addr, reward_amount_2_with_decimals);
      result = string::utf8(b"Win");
    } else {
      // loose
      // burn all units
      coin::transfer<UnitType1>(user, @owner_addr, number_of_units_1);
      managed_coin::burn<UnitType1>(&resource_signer, number_of_units_1);

      coin::transfer<UnitType2>(user, @owner_addr, number_of_units_2);
      managed_coin::burn<UnitType2>(&resource_signer, number_of_units_2);
      result = string::utf8(b"Loose");
    };
    
    let events = borrow_global_mut<Events>(user_addr);  

    // trigger enemy attacked event
    event::emit_event(
      &mut events.enemy_attacked_event,
      EnemyAttackedEvent {
        enemy_level_id,
        total_units_attack,
        total_units_health,
        result,
      },
    );
  }

  // used for testing
  public entry fun mint_coins(user: &signer) acquires AdminData {
    let user_addr = signer::address_of(user);

    assert!(user_addr == @source_addr, E_INVALID_ADDRESS_FOR_MINT);

    managed_coin::register<Wood>(user);
    managed_coin::register<Stone>(user);

    let resource_signer = get_resource_signer();
    
    managed_coin::mint<Wood>(&resource_signer, user_addr, 10000000000000);
    managed_coin::mint<Stone>(&resource_signer, user_addr, 10000000000000);
  }

  // return all units created by address
  #[view]
  public fun get_all_units(creator_addr: address): SimpleMap<u64, Unit> acquires Units {
    assert!(exists<Units>(creator_addr), E_NO_UNITS_EXISTS);

    let units_data = borrow_global<Units>(creator_addr);
    units_data.map
  }

  // return all units_contracts created by address
  #[view]
  public fun get_all_unit_contracts(creator_addr: address): SimpleMap<u64, UnitContract> acquires UnitContracts {
    assert!(exists<UnitContracts>(creator_addr), E_NO_UNIT_CONTRACTS_EXISTS);

    let unit_contracts_data = borrow_global<UnitContracts>(creator_addr);
    unit_contracts_data.map
  }

  // return all enemy_levels created by address
  #[view]
  public fun get_all_enemy_levels(creator_addr: address): SimpleMap<u64, EnemyLevel> acquires EnemyLevels {
    assert!(exists<EnemyLevels>(creator_addr), E_NO_ENEMY_LEVELS_EXISTS);

    let enemy_levels_data = borrow_global<EnemyLevels>(creator_addr);
    enemy_levels_data.map
  }
}