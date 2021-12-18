import abi from "ethereumjs-abi";

// function to get the equivalent hash (as generated by the solidity) of data passed in args
export function getSoliditySHA3Hash(argTypes: string[], args: any[]): string {
  const soliditySHA3Hash = "0x" + abi.soliditySHA3(argTypes, args).toString("hex");
  return soliditySHA3Hash;
}

export function removeDuplicateFromStringArray(list: string[]): string[] {
  return list.filter((x, i, a) => a.indexOf(x) == i);
}
