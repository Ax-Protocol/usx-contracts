# USX

USX is a cross chain native stablecoin. This repository contains the USX implementation.

USX Uses an EIP-1967 Proxy contract to access a UUPS upgradable ERC-1967 compliant 
modern ERC20 token with EIP-2612 Permit support.

USX initially supports mind and burn by depositing and redeeming allowlisted assets.

USD initially supports cross chain bridging via LayerZero.