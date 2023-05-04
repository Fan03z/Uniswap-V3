# Uniswap V3

Uniswap V3(后面简称 Uniswap)中的合约分为 **核心合约(core contracts)** 和 **外部合约(periphery contracts)**

核心合约包含:

1. 池子合约(Pool contracts), 实现去中心化交易逻辑
2. 工厂合约(Factory contracts),作为池子合约的注册入口,简化池子合约的部署

## hardhat

### Foundry (test)

合约和部署虽然整体用的 hardhat 框架,但在测试上使用的是基于 hardhat 上的 Foundry 测试框架

具体混合 hardhat 和 Foundry 的框架可以参考: <https://hardhat.org/hardhat-runner/docs/advanced/hardhat-and-foundry> 和 <https://learnblockchain.cn/docs/foundry/i18n/zh/config/hardhat.html>

**过程步骤**:

1. 首先安装 @nomicfoundation/hardhat-foundry 包 `yarn add --dev hardhat @nomicfoundation/hardhat-foundry`
2. 在 hardhat.config.js 中导入: `require("@nomicfoundation/hardhat-foundry");`
3. 新建 Foundry 的配置文件 foundry.toml,并更改默认配置为:

```toml
[profile.default]
src = 'contracts'
out = 'out'
libs = ['node_modules', 'lib']
test = 'test/foundry'
cache_path  = 'forge-cache'
```

更多 foundry 的配置相关参考: <https://book.getfoundry.sh/reference/config.html>

4. 新建 remapping.txt 文件,可以通过 `forge remappings > remappings.txt` 来获取 foundry 默认到的重定向路径
5. 接下来就在 test/foundry (对应 foundry.toml 上的 test 路径) 目录下写测试就可以了,测试命令 `forge test -vvvv` (vvvv 可以输出更为详细的日志)

## NextJS --Frontend

## Sanity --Backend (CMS)

操作步骤文档: <https://www.sanity.io/docs/getting-started-with-sanity?utm_source=readme>

参考文档: <https://www.sanity.io/docs/reference?utm_source=readme>

1. 先安装 sanity 库`yarn add @sanity/cli`;

2. 初始化 sanity 项目 --V3 版:`yarn create sanity`或者,--V2 版:`sanity init --coupon cleverprogrammer`,接着根据提示走就好了(@sanity V2 和 V3 创建初始化项目时会有点区别,但按着提示走就好了)

> **注意**: 如果是第一次全局安装 sanity 的话,可能要先加入全局环境变量 `export PATH="$(yarn global bin):$PATH"`;
>
> 如果是仅是项目本地安装 sanity 的话,可能也要加入本地项目环境变量`export PATH="./node_modules/.bin:$PATH"`

3. cd 到 sanity 项目目录,启动 sanity 项目:`yarn run dev`,然后就可以访问 <http://localhost:3333/>
