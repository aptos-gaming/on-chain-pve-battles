module owner_addr::mint_coins {
  use aptos_framework::managed_coin;

  struct Wood {}
  struct Stone {}

  fun init_module(owner: &signer) {
    managed_coin::initialize<Wood>(
      owner,
      b"Wood Coin",
      b"Wood",
      8,
      true,
    );

    managed_coin::initialize<Stone>(
      owner,
      b"Stone Coin",
      b"Stone",
      8,
      true,
    );

    managed_coin::register<Wood>(owner);
    managed_coin::register<Stone>(owner);
  }
}