const { run } = require("hardhat");

const verify = async (contractAddress, args) => {
  console.log("verifying...");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
    console.log("already verified!");
  } catch (e) {
    if (e.message.toLowerCase().includes("already verified")) {
      console.log("already verified!");
    } else {
      console.log(e);
    }
  }
};

module.exports = { verify };
