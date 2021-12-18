import { default as DefiPools } from "./defiPools.json";
import { default as Strategies } from "./strategies.json";
import { default as Tokens } from "./plain_tokens.json";
import { DEFI_POOLS_DATA, STRATEGY, DATA_OBJECT } from "../type";

export const TypedDefiPools = DefiPools as DEFI_POOLS_DATA;
export const TypedStrategies = Strategies as STRATEGY[];
export const TypedTokens = Tokens as DATA_OBJECT;
