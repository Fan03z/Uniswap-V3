const { ethers, network } = require("hardhat");
const fs = require("fs");
const {
  frontEndContractsFile,
  frontEndAbiLocation,
} = require("../helper-hardhat-config");
require("dotenv").condfig();

module.exports = async () => {
  if (process.env.UPDATE_FRONT_END) {
    console.log("Writing to front end...");
    await updateContractAddresses();
    await updateAbi();
    console.log("Front end written!");
  }
};

async function updateAbi() {}

async function updateContractAddresses() {}
