## notes
forge install foundry-rs/forge-std --no-commit 
forge install openzeppelin/openzeppelin-contracts --no-commit
forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
forge install OpenZeppelin/openzeppelin-foundry-upgrades --no-commit
forge install PaulRBerg/prb-math --no-commit


forge clean && forge build && forge test --ffi