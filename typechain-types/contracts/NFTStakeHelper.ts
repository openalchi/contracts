/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumberish,
  BytesLike,
  FunctionFragment,
  Result,
  Interface,
  AddressLike,
  ContractRunner,
  ContractMethod,
  Listener,
} from "ethers";
import type {
  TypedContractEvent,
  TypedDeferredTopicFilter,
  TypedEventLog,
  TypedListener,
  TypedContractMethod,
} from "../common";

export declare namespace NFTStake {
  export type StakeStruct = {
    id: BigNumberish;
    amount: BigNumberish;
    stakedAt: BigNumberish;
    lastClaimed: BigNumberish;
  };

  export type StakeStructOutput = [
    id: bigint,
    amount: bigint,
    stakedAt: bigint,
    lastClaimed: bigint
  ] & { id: bigint; amount: bigint; stakedAt: bigint; lastClaimed: bigint };
}

export interface NFTStakeHelperInterface extends Interface {
  getFunction(
    nameOrSignature:
      | "getRewardRate"
      | "getStakingStats"
      | "getTotalRewards"
      | "getUserStakes"
      | "stakeContract"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "getRewardRate",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "getStakingStats",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "getTotalRewards",
    values: [AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "getUserStakes",
    values: [AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "stakeContract",
    values?: undefined
  ): string;

  decodeFunctionResult(
    functionFragment: "getRewardRate",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getStakingStats",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getTotalRewards",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getUserStakes",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "stakeContract",
    data: BytesLike
  ): Result;
}

export interface NFTStakeHelper extends BaseContract {
  connect(runner?: ContractRunner | null): NFTStakeHelper;
  waitForDeployment(): Promise<this>;

  interface: NFTStakeHelperInterface;

  queryFilter<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;
  queryFilter<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;

  on<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  on<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  once<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  once<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  listeners<TCEvent extends TypedContractEvent>(
    event: TCEvent
  ): Promise<Array<TypedListener<TCEvent>>>;
  listeners(eventName?: string): Promise<Array<Listener>>;
  removeAllListeners<TCEvent extends TypedContractEvent>(
    event?: TCEvent
  ): Promise<this>;

  getRewardRate: TypedContractMethod<[_id: BigNumberish], [bigint], "view">;

  getStakingStats: TypedContractMethod<
    [],
    [[bigint, bigint] & { totalStaked: bigint; totalRewardsAvailable: bigint }],
    "view"
  >;

  getTotalRewards: TypedContractMethod<[_user: AddressLike], [bigint], "view">;

  getUserStakes: TypedContractMethod<
    [_user: AddressLike],
    [NFTStake.StakeStructOutput[]],
    "view"
  >;

  stakeContract: TypedContractMethod<[], [string], "view">;

  getFunction<T extends ContractMethod = ContractMethod>(
    key: string | FunctionFragment
  ): T;

  getFunction(
    nameOrSignature: "getRewardRate"
  ): TypedContractMethod<[_id: BigNumberish], [bigint], "view">;
  getFunction(
    nameOrSignature: "getStakingStats"
  ): TypedContractMethod<
    [],
    [[bigint, bigint] & { totalStaked: bigint; totalRewardsAvailable: bigint }],
    "view"
  >;
  getFunction(
    nameOrSignature: "getTotalRewards"
  ): TypedContractMethod<[_user: AddressLike], [bigint], "view">;
  getFunction(
    nameOrSignature: "getUserStakes"
  ): TypedContractMethod<
    [_user: AddressLike],
    [NFTStake.StakeStructOutput[]],
    "view"
  >;
  getFunction(
    nameOrSignature: "stakeContract"
  ): TypedContractMethod<[], [string], "view">;

  filters: {};
}
