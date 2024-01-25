# Arkeo Network Node Tutorial

## Install with Script
curl -o arkeo.sh https://raw.githubusercontent.com/cyrellejohn/crypto-node/main/Arkeo/arkeo.sh  
chmod +x arkeo.sh  
./arkeo.sh  
  
## Check node synchronization, if results false – node is fully synchronized
curl -s localhost:26657/status | jq .result.sync_info.catching_up  
  
## Create Wallet
WALLET=cyan  
arkeod keys add $WALLET  
  
## Save Wallet and Validator Address
WALLET_ADDRESS=$(arkeod keys show $WALLET -a)  
VALOPER_ADDRESS=$(arkeod keys show $WALLET --bech val -a)  
  
## Get Funds
Join [Discord](https://discord.gg/BfEHpm6uFc) and request tokens in [#faucet](https://discord.com/channels/1050100146626642052/1166849422211162243) with $request WALLET_ADDRESS  
  
## Check Balance to Proceed
arkeod query bank balances $WALLET_ADDRESS  
  
## Create Validator
ARKEO_NODENAME="kakitani"  
KEYBASE_ID="32183AAFD2A71A2C"  
DETAILS="Solo Runner"  
WEBSITE="https://twitter.com/kakitanikita"  
  
arkeod tx staking create-validator \  
--amount=1000000uarkeo \  
--pubkey=$(arkeod tendermint show-validator) \  
--moniker=$ARKEO_NODENAME \  
--identity=$KEYBASE_ID \  
--details=$DETAILS \  
—website=$WEBSITE \  
--chain-id=arkeo \  
--commission-rate=0.05 \  
--commission-max-rate=0.2 \  
--commission-max-change-rate=0.1 \  
--min-self-delegation=1 \  
--from=$WALLET \  
--gas-prices=0.1uarkeo \  
--gas-adjustment=1.5 \  
--gas=auto \  
-y  
  
## Check Validator Details
arkeod q staking validator $(arkeod keys show $WALLET --bech val -a)  
  
## Delegate to Own Validator
arkeod tx staking delegate $VALOPER_ADDRESS 995000000uarkeo \  
--from $WALLET \  
--gas auto \  
--fees 200uarkeo  
-y
