import { RISK_PROFILE_DATA, OPTY_STAKING_VAULT } from "../type";

export const RISK_PROFILES: RISK_PROFILE_DATA = [
  {
    code: 0,
    name: "RP0",
    symbol: "RP0",
    canBorrow: false,
    poolRating: [0, 5],
  },
  {
    code: 1,
    name: "Basic",
    symbol: "bas",
    canBorrow: false,
    poolRating: [0, 10],
  },
  {
    code: 2,
    name: "Intermediate",
    symbol: "int",
    canBorrow: true,
    poolRating: [0, 20],
  },
  {
    code: 3,
    name: "Advanced",
    symbol: "adv",
    canBorrow: true,
    poolRating: [0, 30],
  },
];
