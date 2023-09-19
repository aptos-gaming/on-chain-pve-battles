module owner_addr::mint_coins {
  use aptos_framework::managed_coin;

  struct Minerals {}
  struct EnergyCrystals {}

  fun init_module(owner: &signer) {
    managed_coin::initialize<Minerals>(
      owner,
      b"Minerals",
      b"MNS",
      8,
      true,
    );

    managed_coin::initialize<EnergyCrystals>(
      owner,
      b"Energy Crystals",
      b"ECRY",
      8,
      true,
    );

    managed_coin::register<Minerals>(owner);
    managed_coin::register<EnergyCrystals>(owner);
  }
}