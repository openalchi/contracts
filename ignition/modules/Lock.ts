// import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
// import { parseEther } from "viem";

// const JAN_1ST_2030 = 1893456000;
// const ONE_GWEI: bigint = parseEther("0.001");

// const LockModule = buildModule("LockModule", (m) => {
//   const unlockTime = m.getParameter("unlockTime", JAN_1ST_2030);
//   const lockedAmount = m.getParameter("lockedAmount", ONE_GWEI);

//   const lock = m.contract("Lock", [unlockTime], {
//     value: lockedAmount,
//   });

//   return { lock };
// });

// export default LockModule;

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

const DeploymentModule = buildModule("DeploymentModule", (m) => {
  // Deploy ALCHI token
  const token = m.contract("ALCHI");

  // Deploy AlchemyGame
  const alchemyGame = m.contract("AlchemyGame", ['https://openalchi.xyz/metadata/']);

  // Deploy AlchemyGameHelper
  const alchemyGameHelper = m.contract("AlchemyGameHelper", [alchemyGame]);

  // Deploy NFTStake
  const nftStake = m.contract("NFTStake", [
    alchemyGame,
    token,
    parseEther("1")  // "1000000000000000000" in wei
  ]);

  // Deploy NFTStakeHelper
  const nftStakeHelper = m.contract("NFTStakeHelper", [nftStake]);

  // Log addresses (this will be executed after deployment)
 

  return { token, alchemyGame, alchemyGameHelper, nftStake, nftStakeHelper };
});

export default DeploymentModule;
