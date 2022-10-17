# USX

USX is a cross chain native stablecoin. This repository contains the USX implementation.

USX Uses an EIP-1967 Proxy contract to access a UUPS upgradable ERC-1967 upgradable, ERC-1822 proxiable 
modern ERC20 token with EIP-2612 Permit support.

USX initially supports mint and burn by depositing and redeeming allowlisted assets.

USD initially supports cross chain bridging via LayerZero.

The token is upgradable to support the addition of various bridging methods and 
mint/burn mechanics over time.

## TODOs

- [ ] Make the lz app and non blocking lz app upgradable.