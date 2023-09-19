// This module is for dynamically deploying a module for CoinType on-chain,
// as opposed to submitting a tx from off-chain to publish a module containing the CoinType.
//
// Each time you gonna deploy the the following module on deployer account
//
// module deployer::coin1 {
//      struct T has key {}
// }
//
// where deployer is a fixed address, but package and module name can be changed to "coin2, coin3, coin4..." 
// with passing unique coin_seed

module owner_addr::deploy_coin {
  use std::signer;
  use std::vector;
  use std::bcs;
  use std::code::{ publish_package_txn };

  use aptos_std::string::{ String };

  public entry fun deploy_coin(deployer: &signer, coin_seed: String) {
    let addr = signer::address_of(deployer);
    let addr_bytes = bcs::to_bytes(&addr);
    let seed_in_bytes = bcs::to_bytes(&coin_seed);
    vector::remove(&mut seed_in_bytes, 0); 

    // build module code
    let code = x"a11ceb0b0600000005010002020204070614081a200a3a0500000001080005636f696e";

    vector::append(&mut code, seed_in_bytes);
    vector::append(&mut code, x"01540b64756d6d795f6669656c64");
    vector::append(&mut code, addr_bytes);
    vector::append(&mut code, x"000201020100");
    
    // build metadata
    let metadata_serialized: vector<u8> = x"05636f696e";
    vector::append(&mut metadata_serialized, seed_in_bytes);
    vector::append(&mut metadata_serialized, x"01000000000000000040423944464245393334383832323239443743383633373839393439303746414231463338323838333939444442393746463842413446344533444344423331418e011f8b08000000000002ff1d8d3b0ec32010057b4ee18ece626d3e7291932014c1ee92585120827cae1fec629a794f1aff8af888370ea2c4274f974962dd0b48f1e5d6f75a0e03b39a9514f1f3bed7d687f141081f891af7ce3d88fa2bdcae8738ef8419c95ad2b022b221b42e4262e534e60ccb6ab4494b02b07a60d4a6b531037463db7094fefafb589a950000000105636f696e");
    vector::append(&mut metadata_serialized, seed_in_bytes);
    vector::append(&mut metadata_serialized, x"491f8b08000000000002ff013200cdff6d6f64756c65206f776e65725f616464723a3a636f696e");
    
    vector::append(&mut metadata_serialized, seed_in_bytes);
    vector::append(&mut metadata_serialized, x"207b0a2020737472756374205420686173206b6579207b7d0a7d69dc98d53200000000000000");

    let code_array = vector::empty<vector<u8>>();
    vector::push_back(&mut code_array, code);
    publish_package_txn(deployer, metadata_serialized, code_array);
  }
}